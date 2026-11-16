from fastapi import APIRouter, Depends, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.accounts import delete_user_account
from app.config import settings
from app.database import get_db
from app.deps import get_current_user
from app.models.friendship import Friendship, FriendshipStatus
from app.models.memory import Memory
from app.models.moment import JOINED, Moment, moment_participants
from app.models.user import User
from app.relationships import blocked_ids, friend_ids
from app.schemas.user import UpdateUserRequest, UserProfileResponse, UserResponse, UserSearchResult
from app.verification import verification_required

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserProfileResponse, summary="Get the current user's profile with stats")
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> UserProfileResponse:
    memory_count = db.scalar(select(func.count(Memory.id)).where(Memory.author_id == current_user.id)) or 0

    active_moment_count = (
        db.scalar(
            select(func.count(Moment.id))
            .join(moment_participants, moment_participants.c.moment_id == Moment.id)
            .where(
                moment_participants.c.user_id == current_user.id,
                moment_participants.c.status == JOINED,
                Moment.unlock_at > func.now(),
            )
        )
        or 0
    )

    return UserProfileResponse(
        **UserResponse.model_validate(current_user).model_dump(),
        memory_count=memory_count,
        active_moment_count=active_moment_count,
        friend_count=len(friend_ids(current_user.id, db)),
        email_verified=current_user.email_verified,
        google_linked=current_user.google_linked,
        has_password=current_user.has_password,
        is_admin=current_user.email.lower() in settings.admin_email_list,
        verification_required=verification_required(current_user),
    )


@router.patch("/me", response_model=UserResponse, summary="Update the current user's profile")
def update_me(
    body: UpdateUserRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserResponse:
    if body.name is not None:
        current_user.name = body.name.strip()
    if body.avatar_color is not None:
        current_user.avatar_color = body.avatar_color
    db.commit()
    db.refresh(current_user)
    return UserResponse.model_validate(current_user)


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Permanently delete the current user's account and data",
    description=(
        "Deletes the account, every photo the user captured (including the files), their chat messages, "
        "friendships, blocks and reports. Shared moments they created are handed to another participant."
    ),
)
def delete_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> None:
    delete_user_account(current_user, db)


@router.get(
    "/search",
    response_model=list[UserSearchResult],
    summary="Find people to add as friends, by name or exact email",
)
def search_users(
    q: str = Query(min_length=2, max_length=80),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[UserSearchResult]:
    term = q.strip()
    hidden = blocked_ids(current_user.id, db) | {current_user.id}
    # Names match partially, emails only exactly, so nobody can fish for other people's addresses.
    users = db.scalars(
        select(User)
        .where(User.id.not_in(hidden), or_(User.name.ilike(f"%{term}%"), User.email == term.lower()))
        .order_by(User.name)
        .limit(20)
    ).all()
    if not users:
        return []

    found = [u.id for u in users]
    friendships = db.scalars(
        select(Friendship).where(
            or_(
                (Friendship.requester_id == current_user.id) & Friendship.recipient_id.in_(found),
                (Friendship.recipient_id == current_user.id) & Friendship.requester_id.in_(found),
            )
        )
    ).all()
    by_user = {f.recipient_id if f.requester_id == current_user.id else f.requester_id: f for f in friendships}

    results = []
    for user in users:
        friendship = by_user.get(user.id)
        relationship, request_id = "none", None
        if friendship is not None:
            if friendship.status == FriendshipStatus.ACCEPTED:
                relationship = "friend"
            elif friendship.status == FriendshipStatus.PENDING:
                relationship = "outgoing" if friendship.requester_id == current_user.id else "incoming"
                request_id = friendship.id
        results.append(
            UserSearchResult(
                **UserResponse.model_validate(user).model_dump(), relationship=relationship, request_id=request_id
            )
        )
    return results
