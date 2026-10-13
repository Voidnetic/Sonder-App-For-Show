from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.friendship import Friendship, FriendshipStatus
from app.models.memory import Memory
from app.models.moment import Moment, moment_participants
from app.models.user import User
from app.schemas.user import UpdateUserRequest, UserProfileResponse, UserResponse

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserProfileResponse, summary="Get the current user's profile with stats")
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> UserProfileResponse:
    memory_count = db.scalar(select(func.count(Memory.id)).where(Memory.author_id == current_user.id)) or 0

    active_moment_count = (
        db.scalar(
            select(func.count(Moment.id))
            .join(moment_participants, moment_participants.c.moment_id == Moment.id)
            .where(moment_participants.c.user_id == current_user.id, Moment.unlock_at > func.now())
        )
        or 0
    )

    friend_count = (
        db.scalar(
            select(func.count(Friendship.id)).where(
                Friendship.status == FriendshipStatus.ACCEPTED,
                or_(Friendship.requester_id == current_user.id, Friendship.recipient_id == current_user.id),
            )
        )
        or 0
    )

    return UserProfileResponse(
        **UserResponse.model_validate(current_user).model_dump(),
        memory_count=memory_count,
        active_moment_count=active_moment_count,
        friend_count=friend_count,
    )


@router.patch("/me", response_model=UserResponse, summary="Update the current user's profile")
def update_me(
    body: UpdateUserRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserResponse:
    if body.name is not None:
        current_user.name = body.name
    if body.avatar_color is not None:
        current_user.avatar_color = body.avatar_color
    db.commit()
    db.refresh(current_user)
    return UserResponse.model_validate(current_user)


@router.get("/search", response_model=list[UserResponse], summary="Search users by name or email to add as a friend")
def search_users(
    q: str = Query(min_length=1),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[UserResponse]:
    users = db.scalars(
        select(User)
        .where(
            User.id != current_user.id,
            or_(User.name.ilike(f"%{q}%"), User.email.ilike(f"%{q}%")),
        )
        .limit(20)
    ).all()
    return [UserResponse.model_validate(u) for u in users]
