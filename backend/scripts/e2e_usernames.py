"""End-to-end check of usernames, username login, and changing name/username/email."""
import uuid

import pathlib
src = (pathlib.Path(__file__).parent / "e2e_groups.py").read_text()
exec(src[: src.index("hassan, hassan_id = login")])

tag = uuid.uuid4().hex[:6]
email = f"zara{tag}@test.dev"

s, j = call("GET", "/auth/username-available?username=Hassan")
check("taken username reported", s == 200 and not j["available"] and j["reason"] == "That username is taken")
s, j = call("GET", "/auth/username-available?username=ab")
check("too short", not j["available"] and "3 to 20" in j["reason"])
s, j = call("GET", "/auth/username-available?username=bad%20name%21")
check("bad characters", not j["available"])
s, j = call("GET", "/auth/username-available?username=.zara")
check("leading dot", not j["available"])
s, j = call("GET", "/auth/username-available?username=admin")
check("reserved", not j["available"])
s, j = call("GET", f"/auth/username-available?username=@Zara.{tag}")
check("free one, normalized", j["available"] and j["username"] == f"zara.{tag}")

s, j = call("POST", "/auth/register", body={"name": "Zara", "email": email, "password": "sonderpass123", "username": "hassan"})
check("can't register a taken username", s == 409, (s, j))
s, j = call("POST", "/auth/register", body={"name": "Zara", "email": email, "password": "sonderpass123", "username": f"Zara.{tag}"})
check("register with username", s == 201 and j["user"]["username"] == f"zara.{tag}", (s, j))
tok = j["access_token"]
s, j = call("POST", "/auth/register", body={"name": "Old App", "email": f"old{tag}@test.dev", "password": "sonderpass123"})
check("older app without username gets one", s == 201 and j["user"]["username"].startswith("oldapp"), j)

s, j = call("POST", "/auth/login", body={"email": f"@ZARA.{tag}", "password": "sonderpass123"})
check("log in with username (any case, with @)", s == 200, (s, j))
s, j = call("POST", "/auth/login", body={"email": email, "password": "sonderpass123"})
check("log in with email still works", s == 200)
s, j = call("POST", "/auth/login", body={"email": f"zara.{tag}", "password": "nope"})
check("wrong password message", s == 401 and j["detail"] == "Wrong email, username or password")

s, j = call("PATCH", "/users/me", tok, {"username": "ali"})
check("can't take someone's username", s == 409)
s, j = call("PATCH", "/users/me", tok, {"username": "x"})
check("bad username rejected", s == 400)
s, j = call("PATCH", "/users/me", tok, {"username": f"zara_{tag}", "name": "Zara K"})
check("change username and name", s == 200 and j["username"] == f"zara_{tag}" and j["name"] == "Zara K", j)
s, j = call("PATCH", "/users/me", tok, {"username": f"ZARA_{tag}"})
check("keeping your own username is fine", s == 200)
s, j = call("POST", "/auth/login", body={"email": f"zara_{tag}", "password": "sonderpass123"})
check("log in with the new username", s == 200)

hassan, _ = login("hassan@sonder.app")
s, j = call("GET", f"/users/search?q=@zara_{tag[:3]}", hassan)
check("find people by username", any(u["username"] == f"zara_{tag}" for u in j), j)

new_email = f"zara.new{tag}@test.dev"
s, j = call("POST", "/auth/change-email", tok, {"new_email": new_email, "password": "wrong"})
check("email change needs the password", s == 400)
s, j = call("POST", "/auth/change-email", tok, {"new_email": "ali@sonder.app", "password": "sonderpass123"})
check("can't use another account's email", s == 409)
s, j = call("POST", "/auth/change-email", tok, {"new_email": new_email, "password": "sonderpass123"})
check("email changed (no email sender here)", s == 200 and j["status"] == "changed" and j["user"]["email"] == new_email, j)
s, j = call("POST", "/auth/login", body={"email": new_email, "password": "sonderpass123"})
check("log in with the new email", s == 200)
s, j = call("GET", "/users/me", tok)
check("profile shows username", j["username"] == f"zara_{tag}" and not j["email_verified"])
print("ALL PASSED")
