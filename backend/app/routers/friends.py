import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models.friendship import Friendship, FriendshipStatus
from app.models.user import User
from app.schemas.friendship import AddFriendRequest, FriendRequestResponse, FriendResponse
from app.schemas.user import UserResponse

router = APIRouter(tags=["Friends"])


def _to_request_response(friendship: Friendship, db: Session) -> FriendRequestResponse:
    requester = db.get(User, friendship.requester_id)
    recipient = db.get(User, friendship.recipient_id)
    return FriendRequestResponse(
        id=friendship.id,
        requester=UserResponse.model_validate(requester),
        recipient=UserResponse.model_validate(recipient),
        status=friendship.status,
    )


@router.post(
    "/friends/requests",
    response_model=FriendRequestResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Send a friend request",
)
def send_request(
    body: AddFriendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FriendRequestResponse:
    if body.recipient_id == current_user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot send a friend request to yourself")

    recipient = db.get(User, body.recipient_id)
    if recipient is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

    existing = db.scalar(
        select(Friendship).where(
            or_(
                (Friendship.requester_id == current_user.id) & (Friendship.recipient_id == body.recipient_id),
                (Friendship.requester_id == body.recipient_id) & (Friendship.recipient_id == current_user.id),
            )
        )
    )
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, "A friend request already exists between these users")

    friendship = Friendship(requester_id=current_user.id, recipient_id=body.recipient_id)
    db.add(friendship)
    db.commit()
    db.refresh(friendship)
    return _to_request_response(friendship, db)


@router.get("/friends/requests", response_model=list[FriendRequestResponse], summary="List pending friend requests")
def list_requests(
    direction: str = Query(default="incoming", pattern="^(incoming|outgoing)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[FriendRequestResponse]:
    column = Friendship.recipient_id if direction == "incoming" else Friendship.requester_id
    requests = db.scalars(
        select(Friendship)
        .where(column == current_user.id, Friendship.status == FriendshipStatus.PENDING)
        .order_by(Friendship.created_at.desc())
    ).all()
    return [_to_request_response(r, db) for r in requests]


def _respond(
    request_id: uuid.UUID,
    accept: bool,
    current_user: User,
    db: Session,
) -> FriendRequestResponse:
    friendship = db.get(Friendship, request_id)
    if friendship is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Friend request not found")
    if friendship.recipient_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the recipient can respond to this request")
    if friendship.status != FriendshipStatus.PENDING:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This request has already been responded to")

    friendship.status = FriendshipStatus.ACCEPTED if accept else FriendshipStatus.DECLINED
    db.commit()
    db.refresh(friendship)
    return _to_request_response(friendship, db)


@router.patch("/friends/requests/{request_id}/accept", response_model=FriendRequestResponse, summary="Accept a friend request")
def accept_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FriendRequestResponse:
    return _respond(request_id, True, current_user, db)


@router.patch("/friends/requests/{request_id}/decline", response_model=FriendRequestResponse, summary="Decline a friend request")
def decline_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FriendRequestResponse:
    return _respond(request_id, False, current_user, db)


@router.get("/friends", response_model=list[FriendResponse], summary="List the current user's connected circle")
def list_friends(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[FriendResponse]:
    friendships = db.scalars(
        select(Friendship).where(
            Friendship.status == FriendshipStatus.ACCEPTED,
            or_(Friendship.requester_id == current_user.id, Friendship.recipient_id == current_user.id),
        )
    ).all()

    friend_ids = [
        f.recipient_id if f.requester_id == current_user.id else f.requester_id for f in friendships
    ]
    if not friend_ids:
        return []
    friends = db.scalars(select(User).where(User.id.in_(friend_ids))).all()
    return [FriendResponse(**UserResponse.model_validate(f).model_dump()) for f in friends]


@router.delete("/friends/{friend_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Remove a friend")
def remove_friend(
    friend_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    friendship = db.scalar(
        select(Friendship).where(
            Friendship.status == FriendshipStatus.ACCEPTED,
            or_(
                (Friendship.requester_id == current_user.id) & (Friendship.recipient_id == friend_id),
                (Friendship.requester_id == friend_id) & (Friendship.recipient_id == current_user.id),
            ),
        )
    )
    if friendship is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Friendship not found")
    db.delete(friendship)
    db.commit()
