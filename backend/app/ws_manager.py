import uuid

from fastapi import WebSocket


class HangoutConnectionManager:
    """Tracks live WebSocket connections per moment 'room' for the Hangout chat tab."""

    def __init__(self) -> None:
        self._rooms: dict[uuid.UUID, set[WebSocket]] = {}

    async def connect(self, moment_id: uuid.UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        self._rooms.setdefault(moment_id, set()).add(websocket)

    def disconnect(self, moment_id: uuid.UUID, websocket: WebSocket) -> None:
        room = self._rooms.get(moment_id)
        if room and websocket in room:
            room.remove(websocket)
        if room is not None and not room:
            self._rooms.pop(moment_id, None)

    async def broadcast(self, moment_id: uuid.UUID, payload: dict) -> None:
        room = self._rooms.get(moment_id)
        if not room:
            return
        dead: list[WebSocket] = []
        for connection in room:
            try:
                await connection.send_json(payload)
            except Exception:
                dead.append(connection)
        for connection in dead:
            self.disconnect(moment_id, connection)


manager = HangoutConnectionManager()
