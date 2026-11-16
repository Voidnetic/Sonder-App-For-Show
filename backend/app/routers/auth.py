import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.deps import get_current_user
from app.mailer import EmailError, code_email, send_email
from app.models.user import AVATAR_COLORS, User
from app.schemas.auth import (
    AuthResponse,
    ForgotPasswordRequest,
    GoogleLoginRequest,
    LoginRequest,
    RegisterRequest,
    ResetPasswordRequest,
    VerifyEmailRequest,
)
from app.schemas.user import UserResponse
from app.security import create_access_token, hash_password, verify_password
from app.verification import new_code, use_code, verification_required

log = logging.getLogger("sonder.auth")

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Reused between requests so Google's public signing keys are cached instead of fetched every time.
_google_request = google_requests.Request()


def _auth_response(user: User, created: bool = False) -> AuthResponse:
    return AuthResponse(
        user=UserResponse.model_validate(user),
        access_token=create_access_token(user.id),
        created=created,
        verification_required=verification_required(user),
    )


def _email_code(email: str, code: str, purpose: str) -> None:
    """Background task: failures are logged, the person can tap "Resend code"."""
    try:
        send_email(email, *code_email(code, purpose))
    except EmailError as exc:
        log.error("Could not send %s code: %s", purpose, exc)


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new Sonder account with email and password",
)
def register(body: RegisterRequest, background: BackgroundTasks, db: Session = Depends(get_db)) -> AuthResponse:
    existing = db.scalar(select(User).where(User.email == body.email.lower()))
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "An account with this email already exists")

    user = User(name=body.name.strip(), email=body.email.lower(), password_hash=hash_password(body.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    if verification_required(user):
        background.add_task(_email_code, user.email, new_code(user, "verify", db), "verify")
    return _auth_response(user, created=True)


@router.post("/login", response_model=AuthResponse, summary="Log in with email and password")
def login(body: LoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is not None and user.password_hash is None:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "This account was made with Google. Use \"Continue with Google\"."
        )
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password")
    return _auth_response(user)


@router.post(
    "/google",
    response_model=AuthResponse,
    summary="Sign in or create an account with a Google account",
    description=(
        "Send the ID token from Google Sign-In. The server checks Google's signature, that the token was "
        "issued for this app (GOOGLE_CLIENT_IDS) and that Google has verified the email address. "
        "A new account is created on first sign-in; an existing email/password account with the same "
        "email is linked to the Google account."
    ),
)
def google_login(body: GoogleLoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    client_ids = settings.google_client_id_list
    if not client_ids:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Google sign-in is not set up on this server yet")

    try:
        claims = google_id_token.verify_oauth2_token(body.id_token, _google_request, audience=client_ids)
    except ValueError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Google sign-in failed. Please try again.") from exc

    email = str(claims.get("email", "")).lower()
    if not email or not claims.get("email_verified"):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Your Google account's email address is not verified")
    google_sub = str(claims["sub"])

    user = db.scalar(select(User).where(User.google_sub == google_sub))
    created = False
    if user is None:
        user = db.scalar(select(User).where(User.email == email))
        if user is not None:
            # Same verified email: link the existing account rather than creating a second one.
            user.google_sub = google_sub
            user.email_verified = True
        else:
            name = (claims.get("given_name") or claims.get("name") or email.split("@")[0]).strip()[:80]
            user = User(
                name=name or "Sonder friend",
                email=email,
                password_hash=None,
                google_sub=google_sub,
                email_verified=True,
                avatar_color=AVATAR_COLORS[int(google_sub[-1], 36) % len(AVATAR_COLORS)],
            )
            db.add(user)
            created = True
    else:
        user.email_verified = True

    db.commit()
    db.refresh(user)
    return _auth_response(user, created=created)


# ---------------------------------------------------------------- email codes


@router.post(
    "/verify-email/send",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Email a new 6-digit verification code to the signed-in user",
)
def send_verification_code(
    background: BackgroundTasks, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    if not verification_required(current_user):
        return  # already verified, or this server doesn't send email
    background.add_task(_email_code, current_user.email, new_code(current_user, "verify", db), "verify")


@router.post("/verify-email", response_model=AuthResponse, summary="Confirm the email address with the emailed code")
def verify_email(
    body: VerifyEmailRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> AuthResponse:
    if not current_user.email_verified:
        use_code(current_user, "verify", body.code, db)
        current_user.email_verified = True
        db.commit()
        db.refresh(current_user)
    return _auth_response(current_user)


@router.post(
    "/forgot-password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Email a password-reset code (always succeeds, so it can't be used to find out who has an account)",
)
def forgot_password(body: ForgotPasswordRequest, background: BackgroundTasks, db: Session = Depends(get_db)) -> None:
    if not settings.email_enabled:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Password reset isn't available yet")
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is None:
        return
    try:
        code = new_code(user, "reset", db)
    except HTTPException:
        return  # rate limited: stay quiet, same as an unknown email
    background.add_task(_email_code, user.email, code, "reset")


@router.post(
    "/reset-password",
    response_model=AuthResponse,
    summary="Set a new password with the emailed code, and sign in",
)
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "That code has expired. Ask for a new one.")
    use_code(user, "reset", body.code, db)
    user.password_hash = hash_password(body.new_password)
    user.email_verified = True  # they just proved they can read this inbox
    db.commit()
    db.refresh(user)
    return _auth_response(user)
