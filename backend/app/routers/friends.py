import uuid

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user, get_verified_user
from app.models.friendship import Friendship, FriendshipStatus
from app.models.user import User
from app.push import notify_users
from app.relationships import blocked_ids, friendship_between, is_blocked_between
from app.schemas.friendship import AddFriendRequest, FriendRequestResponse, FriendResponse
from app.schemas.user import UserResponse

router = APIRouter(tags=["Friends"])


def _notify_request(recipient_id: uuid.UUID, sender_name: str) -> None:
    notify_users(
        [recipient_id], "New friend request 👋", f"{sender_name} wants to be friends on Sonder", {"type": "friend_request"}
    )


def _notify_accepted(requester_id: uuid.UUID, accepter_name: str) -> None:
    notify_users(
        [requester_id], "Friend request accepted 🎉", f"You and {accepter_name} are now friends", {"type": "friend_accepted"}
    )


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
    background: BackgroundTasks,
    current_user: User = Depends(get_verified_user),
    db: Session = Depends(get_db),
) -> FriendRequestResponse:
    if body.recipient_id == current_user.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "You cannot send a friend request to yourself")

    recipient = db.get(User, body.recipient_id)
    if recipient is None or is_blocked_between(current_user.id, recipient.id, db):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "User not found")

    existing = friendship_between(current_user.id, recipient.id, db)
    if existing is not None:
        if existing.status == FriendshipStatus.ACCEPTED:
            raise HTTPException(status.HTTP_409_CONFLICT, "You are already friends")
        if existing.status == FriendshipStatus.PENDING and existing.requester_id == current_user.id:
            raise HTTPException(status.HTTP_409_CONFLICT, "You already sent this person a request")
        if existing.status == FriendshipStatus.PENDING:
            # They already asked us: sending one back simply accepts theirs.
            existing.status = FriendshipStatus.ACCEPTED
            background.add_task(_notify_accepted, existing.requester_id, current_user.name)
        else:
            # A declined request can be sent again later.
            existing.requester_id = current_user.id
            existing.recipient_id = recipient.id
            existing.status = FriendshipStatus.PENDING
            background.add_task(_notify_request, recipient.id, current_user.name)
        db.commit()
        db.refresh(existing)
        return _to_request_response(existing, db)

    friendship = Friendship(requester_id=current_user.id, recipient_id=body.recipient_id)
    db.add(friendship)
    background.add_task(_notify_request, recipient.id, current_user.name)
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
    hidden = blocked_ids(current_user.id, db)
    return [
        _to_request_response(r, db) for r in requests if not ({r.requester_id, r.recipient_id} & hidden)
    ]


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


@router.delete(
    "/friends/requests/{request_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Cancel a friend request you sent",
)
def cancel_request(
    request_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    friendship = db.get(Friendship, request_id)
    if friendship is None or friendship.status != FriendshipStatus.PENDING:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Friend request not found")
    if friendship.requester_id != current_user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Only the sender can cancel this request")
    db.delete(friendship)
    db.commit()


@router.patch("/friends/requests/{request_id}/accept", response_model=FriendRequestResponse, summary="Accept a friend request")
def accept_request(
    request_id: uuid.UUID,
    background: BackgroundTasks,
    current_user: User = Depends(get_verified_user),
    db: Session = Depends(get_db),
) -> FriendRequestResponse:
    response = _respond(request_id, True, current_user, db)
    background.add_task(_notify_accepted, response.requester.id, current_user.name)
    return response


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
    friends = db.scalars(select(User).where(User.id.in_(friend_ids)).order_by(User.name)).all()
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
