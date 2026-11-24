"""End-to-end check of invites, Ready to Open, leave/delete, photo controls and photo replies."""
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

unlock = (datetime.now(timezone.utc) + timedelta(seconds=6)).isoformat()
s, m = call("POST", "/moments", hassan, {"title": "E2E Test", "participant_ids": [ali_id, ahmed_id], "unlock_at": unlock})
check("create moment", s == 201, (s, m))
mid = m["id"]
check("only the creator has joined", [p["id"] for p in m["participants"]] == [hassan_id] and m["pending_count"] == 2)

s, inv = call("GET", "/moments/invitations", ali)
check("ali sees the invitation", any(x["id"] == mid and x["invited_by"]["id"] == hassan_id for x in inv))
s, _ = call("GET", f"/moments/{mid}/memories", ali)
check("invited-only can't see photos", s == 403)
s, act = call("GET", "/moments/active", ali)
check("invitation isn't on Home yet", all(x["id"] != mid for x in act))
s, m2 = call("POST", f"/moments/{mid}/accept", ali)
check("ali accepts", s == 200 and m2["my_status"] == "joined" and len(m2["participants"]) == 2)
s, _ = call("POST", f"/moments/{mid}/decline", ahmed)
check("ahmed declines", s == 204)
s, _ = call("GET", f"/moments/{mid}", ahmed)
check("ahmed is out", s == 403)
s, _ = call("POST", f"/moments/{mid}/accept", ahmed)
check("can't accept after declining", s == 404)

s, mem = call("POST", f"/moments/{mid}/memories", hassan, files=PNG)
check("hassan adds a photo", s == 201)
s, lst = call("GET", f"/moments/{mid}/memories", hassan)
check("own photo visible while locked", lst[0]["mine"] and lst[0]["image_url"] and lst[0]["locked"])
s, lst = call("GET", f"/moments/{mid}/memories", ali)
check("others' photo hidden while locked", lst[0]["image_url"] is None and not lst[0]["mine"])
s, _ = call("DELETE", f"/moments/{mid}/memories/{mem['id']}", ali)
check("can't delete someone else's photo", s == 403)
s, swapped = call("PUT", f"/moments/{mid}/memories/{mem['id']}", hassan, files=PNG)
check("swap own photo while locked", s == 200 and swapped["image_url"] != mem["image_url"])
s, mem2 = call("POST", f"/moments/{mid}/memories", hassan, files=PNG)
s, _ = call("DELETE", f"/moments/{mid}/memories/{mem2['id']}", hassan)
check("delete own photo while locked", s == 204)
s, _ = call("POST", f"/moments/{mid}/messages", hassan, {"text": "hi", "memory_id": mem["id"]})
check("can't reply to a photo before unlock", s == 400)

time.sleep(7)
s, act = call("GET", "/moments/active", hassan)
here = [x for x in act if x["id"] == mid]
check("unlocked + unopened stays on Home as Ready", here and here[0]["is_ready"], act)
check("ready ones come first", act[0]["is_ready"])
s, arc = call("GET", "/moments/archive", hassan)
check("not in the vault yet", all(x["id"] != mid for x in arc))
s, _ = call("DELETE", f"/moments/{mid}/memories/{mem['id']}", hassan)
check("photos permanent after unlock", s == 403)
s, r = call("POST", f"/moments/{mid}/reveal", hassan)
check("open it", s == 200 and r["opened_at"] and not r["is_ready"])
s, act = call("GET", "/moments/active", hassan)
check("gone from Home after opening", all(x["id"] != mid for x in act))
s, arc = call("GET", "/moments/archive", hassan)
check("now in the Past Vault", any(x["id"] == mid for x in arc))
s, act = call("GET", "/moments/active", ali)
check("still Ready for ali (per person)", any(x["id"] == mid and x["is_ready"] for x in act))

s, _ = call("POST", f"/moments/{mid}/memories/{mem['id']}/hide", ali)
s, lst = call("GET", f"/moments/{mid}/memories", ali)
check("hidden from ali's view", s == 200 and lst == [])
s, lst = call("GET", f"/moments/{mid}/memories?include_hidden=true", ali)
check("listed with include_hidden", lst[0]["hidden"])
s, lst = call("GET", f"/moments/{mid}/memories", hassan)
check("still visible to hassan", len(lst) == 1)
s, _ = call("DELETE", f"/moments/{mid}/memories/{mem['id']}/hide", ali)
s, lst = call("GET", f"/moments/{mid}/memories", ali)
check("unhide", len(lst) == 1)

s, msg = call("POST", f"/moments/{mid}/messages", ali, {"text": "😍", "memory_id": mem["id"]})
check("photo reply", s == 201 and msg["memory_id"] == mem["id"] and msg["memory_image_url"])
s, msgs = call("GET", f"/moments/{mid}/messages", hassan)
check("reply in chat history with thumbnail", msgs[-1]["memory_image_url"])

s, _ = call("DELETE", f"/moments/{mid}", ali)
check("only the creator can delete for everyone", s == 403)
s, _ = call("POST", f"/moments/{mid}/leave", hassan)
check("creator leaves", s == 204)
s, m3 = call("GET", f"/moments/{mid}", ali)
check("ali took it over, hassan's photo kept", s == 200 and m3["creator"]["id"] == ali_id and m3["memory_count"] == 1)
s, _ = call("DELETE", f"/moments/{mid}", ali)
check("new creator deletes it for everyone", s == 204)
s, _ = call("GET", f"/moments/{mid}", ali)
check("deleted", s == 404)

# Last person leaving deletes it.
s, m = call("POST", "/moments", hassan, {"title": "E2E Solo", "participant_ids": [], "unlock_at": unlock})
s, _ = call("POST", f"/moments/{m['id']}/leave", hassan)
s, _ = call("GET", f"/moments/{m['id']}", hassan)
check("last one out deletes the moment", s == 404)
print("ALL PASSED")
