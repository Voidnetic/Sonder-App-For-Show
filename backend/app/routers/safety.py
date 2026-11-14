import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.accounts import delete_memory, delete_user_account
from app.config import settings
from app.database import get_db
from app.deps import get_current_user
from app.models.memory import Memory
from app.models.message import Message
from app.models.moment import Moment
from app.models.safety import Block, DeletionRequest, Report
from app.models.user import User
from app.relationships import friendship_between
from app.schemas.safety import (
    AdminReportResponse,
    BlockRequest,
    CreateReportRequest,
    ReportResponse,
    ResolveReportRequest,
)
from app.schemas.user import UserResponse
from app.storage import photo_url

router = APIRouter(tags=["Safety"])


# ---------------------------------------------------------------- blocking


def _block(blocker: User, blocked_id: uuid.UUID, db: Session) -> None:
    if blocked_id == blocker.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot block yourself")
    if db.get(User, blocked_id) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
    if db.get(Block, (blocker.id, blocked_id)) is None:
        db.add(Block(blocker_id=blocker.id, blocked_id=blocked_id))
    # Blocking also ends the friendship and any pending request, in either direction.
    friendship = friendship_between(blocker.id, blocked_id, db)
    if friendship is not None:
        db.delete(friendship)


@router.get("/blocks", response_model=list[UserResponse], summary="List the people you have blocked")
def list_blocks(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[UserResponse]:
    users = db.scalars(
        select(User)
        .join(Block, Block.blocked_id == User.id)
        .where(Block.blocker_id == current_user.id)
        .order_by(Block.created_at.desc())
    ).all()
    return [UserResponse.model_validate(u) for u in users]


@router.post(
    "/blocks",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Block someone",
    description="They disappear from your search, friends, chats and photos, and can no longer find or add you.",
)
def block_user(
    body: BlockRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    _block(current_user, body.user_id, db)
    db.commit()


@router.delete("/blocks/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Unblock someone")
def unblock_user(
    user_id: uuid.UUID, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> None:
    db.execute(delete(Block).where(Block.blocker_id == current_user.id, Block.blocked_id == user_id))
    db.commit()


# ---------------------------------------------------------------- reporting


def _participant_ids(moment_id: uuid.UUID, db: Session) -> set[uuid.UUID]:
    moment = db.get(Moment, moment_id)
    return {p.id for p in moment.participants} if moment else set()


def _reported_user(body: CreateReportRequest, reporter: User, db: Session) -> uuid.UUID:
    """Checks the reporter can actually see what they are reporting, and returns who posted it."""
    if body.target_type == "user":
        if db.get(User, body.target_id) is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")
        return body.target_id

    item = db.get(Memory if body.target_type == "memory" else Message, body.target_id)
    if item is None or reporter.id not in _participant_ids(item.moment_id, db):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Not found")
    if item.author_id is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Automatic messages can't be reported")
    return item.author_id


@router.post(
    "/reports",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Report a user, photo or chat message",
)
def create_report(
    body: CreateReportRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
) -> ReportResponse:
    reported_user_id = _reported_user(body, current_user, db)
    if reported_user_id == current_user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You can't report yourself")

    report = Report(
        reporter_id=current_user.id,
        target_type=body.target_type,
        target_id=body.target_id,
        reported_user_id=reported_user_id,
        reason=body.reason,
        details=(body.details or "").strip() or None,
    )
    db.add(report)
    if body.block:
        _block(current_user, reported_user_id, db)
    db.commit()
    db.refresh(report)
    return ReportResponse.model_validate(report)


# ---------------------------------------------------------------- admin review


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.email.lower() not in settings.admin_email_list:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admins only")
    return current_user


def _user_or_none(user_id: uuid.UUID | None, db: Session) -> UserResponse | None:
    user = db.get(User, user_id) if user_id else None
    return UserResponse.model_validate(user) if user else None


def _preview(report: Report, db: Session) -> str | None:
    if report.target_type == "memory":
        memory = db.get(Memory, report.target_id)
        return photo_url(memory.image_url) if memory else "(already removed)"
    if report.target_type == "message":
        message = db.get(Message, report.target_id)
        return message.text if message else "(already removed)"
    return None


@router.get(
    "/admin/reports",
    response_model=list[AdminReportResponse],
    summary="Admin: list reports to review",
    tags=["Admin"],
)
def admin_list_reports(
    report_status: str = Query(default="open", alias="status", pattern="^(open|resolved|dismissed)$"),
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[AdminReportResponse]:
    reports = db.scalars(
        select(Report).where(Report.status == report_status).order_by(Report.created_at.asc()).limit(200)
    ).all()
    return [
        AdminReportResponse(
            **ReportResponse.model_validate(r).model_dump(),
            details=r.details,
            reporter=_user_or_none(r.reporter_id, db),
            reported_user=_user_or_none(r.reported_user_id, db),
            preview=_preview(r, db),
        )
        for r in reports
    ]


@router.post(
    "/admin/reports/{report_id}/resolve",
    response_model=ReportResponse,
    summary="Admin: dismiss a report, remove the reported content, or delete the reported account",
    tags=["Admin"],
)
def admin_resolve_report(
    report_id: uuid.UUID,
    body: ResolveReportRequest,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ReportResponse:
    report = db.get(Report, report_id)
    if report is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Report not found")

    if body.action == "remove_content":
        if report.target_type == "memory" and (memory := db.get(Memory, report.target_id)):
            delete_memory(memory, db)
        elif report.target_type == "message" and (message := db.get(Message, report.target_id)):
            db.delete(message)
        elif report.target_type == "user":
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Use delete_user for reports about a user")
    elif body.action == "delete_user" and report.reported_user_id:
        target = db.get(User, report.reported_user_id)
        if target is not None:
            report.status = "resolved"
            report.resolved_at = datetime.now(timezone.utc)
            db.flush()
            delete_user_account(target, db)  # commits
            db.refresh(report)
            return ReportResponse.model_validate(report)

    report.status = "dismissed" if body.action == "dismiss" else "resolved"
    report.resolved_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(report)
    return ReportResponse.model_validate(report)



@router.get("/admin/deletion-requests", summary="Admin: account deletion requests sent from the website", tags=["Admin"])
def admin_list_deletion_requests(_: User = Depends(require_admin), db: Session = Depends(get_db)) -> list[dict]:
    requests = db.scalars(
        select(DeletionRequest).where(DeletionRequest.status == "open").order_by(DeletionRequest.created_at.asc())
    ).all()
    return [
        {
            "id": str(r.id),
            "email": r.email,
            "note": r.note,
            "created_at": r.created_at.isoformat(),
            "account_exists": db.scalar(select(User.id).where(User.email == r.email)) is not None,
        }
        for r in requests
    ]


@router.post(
    "/admin/deletion-requests/{request_id}/complete",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Admin: delete the account for a deletion request (after confirming by email that it's theirs)",
    tags=["Admin"],
)
def admin_complete_deletion_request(
    request_id: uuid.UUID, _: User = Depends(require_admin), db: Session = Depends(get_db)
) -> None:
    request = db.get(DeletionRequest, request_id)
    if request is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Request not found")
    request.status = "done"
    db.commit()
    user = db.scalar(select(User).where(User.email == request.email))
    if user is not None:
        delete_user_account(user, db)
