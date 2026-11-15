"""
Public web pages that Google Play needs links to:
  /privacy         privacy policy (Play Console > App content > Privacy policy)
  /terms           terms of use, including the rules for photos and chat
  /delete-account  delete an account without the app
  /                home page (Google sign-in's consent screen needs one) (Play Console > Data safety > Account deletion URL)
"""

from html import escape

from fastapi import APIRouter, Depends, Form
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.accounts import delete_user_account
from app.config import settings
from app.database import get_db
from app.models.safety import DeletionRequest
from app.models.user import User
from app.security import verify_password

router = APIRouter(include_in_schema=False)

EFFECTIVE_DATE = "14 November 2026"

STYLE = """
:root { --ink:#1C1C1C; --muted:#6B6B6B; --cream:#FAF9F6; --lav:#E6E6FA; --mint:#E0F8E6; --sun:#FFD84D; }
* { box-sizing: border-box; }
body { margin:0; background:var(--cream); color:var(--ink);
       font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
.brand { font-weight: 900; letter-spacing: 3px; font-size: 14px; }
h1 { font-size: 36px; line-height: 1.1; margin: 24px 0 8px; }
h2 { font-size: 20px; margin: 32px 0 8px; }
.muted { color: var(--muted); }
.card { background: #fff; border: 2px solid var(--ink); border-radius: 20px; padding: 20px;
        box-shadow: 4px 4px 0 var(--ink); margin: 20px 0; }
.card.lav { background: var(--lav); } .card.mint { background: var(--mint); }
label { display:block; font-weight: 800; font-size: 13px; letter-spacing: 1px; margin: 14px 0 6px; }
input, textarea { width: 100%; font: inherit; padding: 12px 14px; border: 2px solid var(--ink);
                  border-radius: 14px; background: #fff; }
button { margin-top: 18px; font: inherit; font-weight: 900; letter-spacing: 1px; padding: 14px 22px;
         border: 2px solid var(--ink); border-radius: 16px; background: var(--ink); color: #fff;
         box-shadow: 4px 4px 0 var(--sun); cursor: pointer; }
button.danger { background: #B00020; }
a { color: var(--ink); font-weight: 700; }
ul { padding-left: 22px; }
"""


def _contact() -> str:
    if settings.support_email:
        email = escape(settings.support_email)
        return f'<a href="mailto:{email}">{email}</a>'
    return "<strong>[set SUPPORT_EMAIL on the server]</strong>"


def _page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(title)} · Sonder</title><style>{STYLE}</style></head>
<body><main><div class="brand">SONDER</div>{body}
<p class="muted" style="margin-top:48px">
<a href="/">Home</a> · <a href="/privacy">Privacy policy</a> · <a href="/terms">Terms</a> · <a href="/delete-account">Delete account</a>
</p></main></body></html>"""
    )


@router.get("/", response_class=HTMLResponse)
def home() -> HTMLResponse:
    return _page(
        "Capture moments together",
        """
<h1>Sonder</h1>
<p style="font-size:20px;font-weight:700">Capture moments together. Reveal them later.</p>
<div class="card lav">
<p style="margin-top:0">Start a <strong>moment</strong> with your friends: a trip, a party, a night out. Everyone takes
photos, but nobody can see them, not even their own, until the moment unlocks at the time you chose.
Then you reveal them all together.</p>
<ul>
<li>Photos stay locked and hidden until the reveal</li>
<li>Chat with everyone in the moment while it's happening</li>
<li>Only friends you add can join your moments</li>
</ul>
</div>
<div class="card mint"><strong>Get the app:</strong> Sonder for Android is coming to Google Play.</div>
""",
    )


@router.get("/privacy", response_class=HTMLResponse)
def privacy_policy() -> HTMLResponse:
    developer = escape(settings.developer_name)
    return _page(
        "Privacy policy",
        f"""
<h1>Privacy policy</h1>
<p class="muted">Effective {EFFECTIVE_DATE}</p>
<p>Sonder lets small groups of friends capture photos together into a shared "moment" that stays
locked until a time they choose. This policy explains what we collect, why, and the choices you have.
Sonder is run by {developer}.</p>

<h2>What we collect</h2>
<ul>
<li><strong>Account details:</strong> your name, email address and either a password (stored only as a
salted bcrypt hash, never in plain text) or, if you use Google sign-in, your Google account ID and the
fact that Google has verified your email. We do not receive your Google password.</li>
<li><strong>Content you create:</strong> photos you capture, their captions, chat messages in a moment's
Hangout, the moments you create and their unlock times.</li>
<li><strong>Your connections:</strong> friend requests, friends, and people you have blocked.</li>
<li><strong>Reports:</strong> if you report someone or something, we store the report and what it was about.</li>
<li><strong>Technical data:</strong> our server keeps standard logs (such as IP address, time and the
address requested) for security and to fix problems. These are kept for up to 30 days.</li>
</ul>
<p>We do <strong>not</strong> collect your location, contacts, or advertising ID, we do not show ads,
and we do not use your photos or messages to train any model.</p>

<h2>Camera and photos</h2>
<p>The app asks for camera access so you can capture photos, and photo library access only when you
choose to pick an existing photo. Photos are uploaded only when you press the shutter or pick one.</p>

<h2>How we use it</h2>
<ul>
<li>To run the app: sign you in, show your moments, and reveal photos to the people in a moment once it unlocks.</li>
<li>To keep people safe: review reports, remove content that breaks our <a href="/terms">rules</a>, and
stop abuse.</li>
</ul>

<h2>Who can see your content</h2>
<p>Photos are hidden from <em>everyone</em>, including you, until the moment unlocks. After that they can be seen
by the people in that moment. Chat messages are visible to people in the moment. Other users can find you by
your name, or by your exact email address, to send a friend request. Blocking someone hides you from each other.</p>

<h2>Sharing</h2>
<p>We don't sell or rent your data. We share it only with the service providers that run Sonder for us
(cloud hosting, database and photo storage, and Google for sign-in), who may process it only on our
instructions, or when the law requires it.</p>

<h2>Security</h2>
<p>Data is sent over encrypted HTTPS connections. Passwords are hashed with bcrypt. Access to the server is
limited to the people who run Sonder.</p>

<h2>Keeping and deleting your data</h2>
<p>We keep your data while your account exists. You can delete your account at any time in the app
(<em>Profile → Delete account</em>) or on our <a href="/delete-account">account deletion page</a>.
This permanently deletes your account, your photos, your messages, your friendships and blocks straight away.
Moments you created that friends are still in are kept for them, without your photos or messages.
Copies in server backups are removed within 30 days.</p>

<h2>Children</h2>
<p>Sonder is not meant for children under 13, and we do not knowingly collect their data. If you believe a
child has made an account, contact us and we will delete it.</p>

<h2>Your rights</h2>
<p>You can see and change your name in the app, and delete your account at any time. To ask for a copy of
your data or anything else about your privacy, contact us at {_contact()}.</p>

<h2>Changes</h2>
<p>If we change this policy we will update the date above and, for important changes, tell you in the app.</p>
""",
    )


@router.get("/terms", response_class=HTMLResponse)
def terms() -> HTMLResponse:
    return _page(
        "Terms of use",
        f"""
<h1>Terms of use</h1>
<p class="muted">Effective {EFFECTIVE_DATE}</p>
<p>By using Sonder you agree to these terms. You must be at least 13 years old.</p>
<h2>Community rules</h2>
<p>Sonder has zero tolerance for objectionable content or abusive users. Do not post or send:</p>
<ul>
<li>nudity or sexual content, or anything that sexualises minors;</li>
<li>harassment, bullying, threats, or hate based on who someone is;</li>
<li>violence, self-harm encouragement, or illegal activity;</li>
<li>spam, scams, or content pretending to be someone else;</li>
<li>photos of people who have not agreed to be photographed, or anything you don't have the right to share.</li>
</ul>
<h2>Reporting and blocking</h2>
<p>You can report any user, photo or message from inside the app, and block anyone so they can no longer see
or contact you. We review reports within 24 hours and remove content and accounts that break these rules.</p>
<h2>Your content</h2>
<p>You own the photos and messages you post. You allow us to store them and show them to the people in your
moments, only to run the app. You can delete them by deleting your account.</p>
<h2>Contact</h2>
<p>{_contact()}</p>
""",
    )


DELETE_INTRO = """
<h1>Delete your account</h1>
<p>Deleting your Sonder account permanently removes:</p>
<ul>
<li>your account (name, email, password or Google link);</li>
<li>every photo you captured, and its caption;</li>
<li>your chat messages, friendships, friend requests and blocks.</li>
</ul>
<p class="muted">Moments you created that friends are still in are handed to one of them, without your photos or
messages. Server backups are cleared within 30 days. This can't be undone.</p>
<div class="card lav"><strong>Easiest:</strong> open the Sonder app → <em>Profile</em> → <em>Delete account</em>.</div>
"""


def _delete_form(message: str = "") -> str:
    return f"""
{message}
<div class="card">
<h2 style="margin-top:0">Delete with your email and password</h2>
<form method="post" action="/delete-account">
<label for="email">EMAIL</label><input id="email" name="email" type="email" required autocomplete="email">
<label for="password">PASSWORD</label>
<input id="password" name="password" type="password" required autocomplete="current-password">
<button class="danger" type="submit">DELETE MY ACCOUNT</button>
</form>
</div>
<div class="card">
<h2 style="margin-top:0">Signed up with Google, or forgot your password?</h2>
<p>Send us a request. We'll email you at that address to confirm it's you, then delete the account within
7 days.</p>
<form method="post" action="/delete-account/request">
<label for="r-email">EMAIL ON THE ACCOUNT</label>
<input id="r-email" name="email" type="email" required autocomplete="email">
<label for="note">ANYTHING ELSE? (OPTIONAL)</label><textarea id="note" name="note" rows="3" maxlength="1000"></textarea>
<button type="submit">SEND REQUEST</button>
</form>
<p class="muted">Or email {_contact()}.</p>
</div>
"""


@router.get("/delete-account", response_class=HTMLResponse)
def delete_account_page() -> HTMLResponse:
    return _page("Delete account", DELETE_INTRO + _delete_form())


@router.post("/delete-account", response_class=HTMLResponse)
def delete_account_submit(
    email: str = Form(max_length=255), password: str = Form(max_length=128), db: Session = Depends(get_db)
) -> HTMLResponse:
    user = db.scalar(select(User).where(User.email == email.strip().lower()))
    if user is None or user.password_hash is None or not verify_password(password, user.password_hash):
        error = '<div class="card" style="background:#FFE0E0"><strong>That email and password don\'t match an ' \
                "account.</strong> If you signed up with Google, use the request form below.</div>"
        return _page("Delete account", DELETE_INTRO + _delete_form(error))
    delete_user_account(user, db)
    return _page(
        "Account deleted",
        '<h1>Account deleted</h1><div class="card mint">Your Sonder account and everything in it has been '
        "permanently deleted. Sorry to see you go.</div>",
    )


@router.post("/delete-account/request", response_class=HTMLResponse)
def delete_account_request(
    email: str = Form(max_length=255), note: str = Form(default="", max_length=1000), db: Session = Depends(get_db)
) -> HTMLResponse:
    db.add(DeletionRequest(email=email.strip().lower(), note=note.strip() or None))
    db.commit()
    return _page(
        "Request received",
        '<h1>Request received</h1><div class="card mint">Thanks. If there\'s an account with that email, we\'ll '
        "email you to confirm it's yours and then delete it within 7 days.</div>",
    )
