"""End-to-end check of editing a capsule before it opens: rename, new reveal time, invite more friends."""
import io
import json
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

BASE = "http://localhost:8000/api"
PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)


def call(method, path, token=None, body=None, files=None):
    headers = {}
    data = None
    if files:
        boundary = uuid.uuid4().hex
        buf = io.BytesIO()
        buf.write(f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.png\"\r\n"
                  f"Content-Type: image/png\r\n\r\n".encode())
        buf.write(files)
        buf.write(f"\r\n--{boundary}--\r\n".encode())
        data = buf.getvalue()
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, json.loads(raw) if raw else None


def login(email):
    s, j = call("POST", "/auth/login", body={"email": email, "password": "sonderpass123"})
    assert s == 200, (s, j)
    return j["access_token"], j["user"]["id"]


def check(label, cond, extra=""):
    print(("PASS " if cond else "FAIL ") + label, extra if not cond else "")
    if not cond:
        raise SystemExit(1)


hassan, hassan_id = login("hassan@sonder.app")
ali, ali_id = login("ali@sonder.app")
ahmed, ahmed_id = login("ahmed@sonder.app")
later = lambda **kw: (datetime.now(timezone.utc) + timedelta(**kw)).isoformat()

s, m = call("POST", "/moments", hassan, {"title": "Edit Test", "participant_ids": [ali_id], "unlock_at": later(hours=2)})
check("create moment", s == 201, (s, m))
mid = m["id"]
check("invited list shows ali", [u["id"] for u in m["invited"]] == [ali_id])
s, _ = call("POST", f"/moments/{mid}/accept", ali)
check("ali accepts", s == 200)

s, r = call("PATCH", f"/moments/{mid}", ali, {"title": "Hacked"})
check("only the creator can edit", s == 403, (s, r))

new_time = later(hours=5)
s, m = call("PATCH", f"/moments/{mid}", hassan, {"title": "Murree Trip", "unlock_at": new_time, "add_participant_ids": [ahmed_id]})
check("creator edits", s == 200, (s, m))
check("renamed", m["title"] == "Murree Trip")
check("new reveal time", abs(datetime.fromisoformat(m["unlock_at"]) - datetime.fromisoformat(new_time)).total_seconds() < 1)
check("ahmed invited", [u["id"] for u in m["invited"]] == [ahmed_id] and m["pending_count"] == 1)
s, inv = call("GET", "/moments/invitations", ahmed)
check("ahmed sees the invite", any(x["id"] == mid and x["title"] == "Murree Trip" for x in inv))

s, msgs = call("GET", f"/moments/{mid}/messages", ali)
texts = [x["text"] for x in msgs if x["type"] == "system"]
check("chat shows what changed", any("renamed" in t and "Murree Trip" in t for t in texts)
      and any("reveal time" in t for t in texts) and any("invited" in t for t in texts), texts)

s, m = call("PATCH", f"/moments/{mid}", hassan, {"add_participant_ids": [ahmed_id]})
s2, msgs2 = call("GET", f"/moments/{mid}/messages", ali)
check("inviting again changes nothing", s == 200 and len(msgs2) == len(msgs))
s, r = call("PATCH", f"/moments/{mid}", hassan, {"add_participant_ids": [str(uuid.uuid4())]})
check("can't invite strangers", s == 400, (s, r))
s, r = call("PATCH", f"/moments/{mid}", hassan, {"unlock_at": later(hours=-1)})
check("reveal time must be in the future", s == 400, (s, r))
s, r = call("PATCH", f"/moments/{mid}", hassan, {"title": ""})
check("empty name refused", s == 422, (s, r))

s, m = call("PATCH", f"/moments/{mid}", hassan, {"unlock_at": later(seconds=3)})
check("bring the reveal forward", s == 200)
time.sleep(4)
s, r = call("PATCH", f"/moments/{mid}", hassan, {"title": "Too late"})
check("can't edit once unlocked", s == 400, (s, r))
s, r = call("POST", f"/moments/{mid}/participants", hassan, {"user_id": ahmed_id})
check("can't add people once unlocked", s == 400, (s, r))

s, _ = call("DELETE", f"/moments/{mid}", hassan)
check("clean up", s == 204)
print("ALL EDIT CHECKS PASSED")
