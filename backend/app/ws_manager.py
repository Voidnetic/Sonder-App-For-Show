import uuid

from fastapi import WebSocket


class HangoutConnectionManager:
    """
    Tracks live WebSocket connections per moment 'room' for the Hangout.

    Besides chat messages, the room shares two light, never-stored signals:
      {"event": "presence", "user_ids": [...]}         who has this moment open right now ("Here now")
      {"event": "typing", "user_id": ..., "typing": b}  someone started or stopped typing
    Chat messages keep their original shape (no "event" key), so older app versions still work.
    """

    def __init__(self) -> None:
        self._rooms: dict[uuid.UUID, dict[WebSocket, uuid.UUID]] = {}

    async def connect(self, moment_id: uuid.UUID, websocket: WebSocket, user_id: uuid.UUID) -> None:
        await websocket.accept()
        self._rooms.setdefault(moment_id, {})[websocket] = user_id
        await self.broadcast_presence(moment_id)

    async def disconnect(self, moment_id: uuid.UUID, websocket: WebSocket) -> None:
        if self._drop(moment_id, websocket):
            await self.broadcast_presence(moment_id)

    def _drop(self, moment_id: uuid.UUID, websocket: WebSocket) -> bool:
        room = self._rooms.get(moment_id)
        if not room or websocket not in room:
            return False
        del room[websocket]
        if not room:
            self._rooms.pop(moment_id, None)
        return True

    def present_user_ids(self, moment_id: uuid.UUID) -> list[str]:
        # A person with the moment open on two phones counts once.
        return sorted({str(uid) for uid in self._rooms.get(moment_id, {}).values()})

    async def broadcast_presence(self, moment_id: uuid.UUID) -> None:
        await self.broadcast(moment_id, {"event": "presence", "user_ids": self.present_user_ids(moment_id)})

    async def broadcast(self, moment_id: uuid.UUID, payload: dict, exclude: WebSocket | None = None) -> None:
        room = self._rooms.get(moment_id)
        if not room:
            return
        dead: list[WebSocket] = []
        for connection in list(room):
            if connection is exclude:
                continue
            try:
                await connection.send_json(payload)
            except Exception:
                dead.append(connection)
        # Drop connections that have gone away and tell everyone else who's still here. This ends: each
        # round removes at least one connection.
        for connection in dead:
            self._drop(moment_id, connection)
        if dead:
            await self.broadcast_presence(moment_id)


manager = HangoutConnectionManager()
