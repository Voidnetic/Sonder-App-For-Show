# Sonder: notes for Claude

Read this first. It sums up everything built so far and how the owner likes to work.

## The product
**Sonder** is a shared photo time capsule ("Capture now. Reveal later."). Friends join a capsule
(called a "moment" in code), add photos that stay hidden from everyone, chat while a countdown runs,
then reveal all the photos together. Team name: **mhcorps** (don't mention it in the presentation yet).
App ID: `com.mhcorps.sonder`.

## How the owner likes to work
- Not a developer: explain in plain words, give click-by-click steps, keep replies short.
- **Show previews/mockups before implementing visual changes**, and say what you'll do before big work.
- Wants things to look polished and "bubbly" (the app's sticker style), and real photos, not stock
  (stock photos looked fake to them).
- Never put their personal email addresses, keys or passwords in the repo or chat. Secrets go into
  Railway Variables or the environment's network secrets, typed by the owner.
- Push only to branch `claude/wonderful-johnson-i2ajge`. Don't open PRs unless asked.

## Code layout
- `lib/`: Flutter app (3.47.5). Widget tests in `test/widget_test.dart` (45 tests; run `flutter test`).
- `backend/`: FastAPI + SQLAlchemy + PostgreSQL. SQL migrations in `backend/db/0*.sql` run on every start
  (01 schema, 02 demo seed, 03 accounts/safety, 04 push, 05 email codes, 06 groups/photos, 07 usernames).
- `backend/scripts/e2e_groups.py`, `e2e_usernames.py`, `e2e_edit.py`: end-to-end checks against a local server on :8000
  (demo users like hassan@sonder.app / sonderpass123 from the seed).
- `backend/scripts/railway_api.py`: tiny Railway GraphQL helper (the token is injected by the environment's
  network secret, never stored here).
- Docs: `DEPLOY.md` (Railway, R2, Firebase, email), `PLAY_STORE.md`, `IOS.md` (Sideloadly), `SETUP.md`.
- `presentation/pitch/`: the interactive pitch deck (HTML). `presentation/theme-previews/`: transition demos.

## Where it runs
- **Server:** Railway, `https://sonder-api-production.up.railway.app` (health at `/health`). Deploys
  automatically from the branch when `backend/` changes. Railway Hobby plan blocks SMTP, so email goes
  through the **Gmail API** (`GMAIL_CLIENT_ID/SECRET/REFRESH_TOKEN` + `EMAIL_FROM` in Railway). If emails
  stop, the refresh token was revoked: redo the OAuth Playground step in DEPLOY.md §3b.
- **Photos:** Cloudflare R2 (private bucket, presigned links that expire after 1 hour).
- **Push:** Firebase Cloud Messaging (Android only so far).
- **Builds:** GitHub Actions on every push: `build-apk.yml` → release `apk-latest`;
  `build-ipa.yml` → unsigned `sonder.ipa` on release `ipa-latest` (installed with Sideloadly; the owner's
  own iPhone 16 Pro Max won't connect over USB, so they test on their brother's phone).

## Features built (all tested)
Accounts: email/password with confirm field and show-password eye, unique **usernames** (log in with email
or username), Google sign-in (Android), email verification codes, forgot password, Profile → **Account**
(change name, username, email, password), delete account.
Capsules: create with friends → friends get an **invite** to Accept/Decline; countdown; "here now" and
typing indicators; live chat; the creator can **edit** a capsule before it opens (rename, change the
reveal time, invite more friends; the chat shows what changed); own photos visible to the author while locked with **swap/delete**;
**offline upload queue** (photos saved privately on the phone, upload later, keep their taken time);
when the timer ends the capsule stays on Home as **Ready to Open** until that person opens it, then moves
to their **Past Vault** (per-person). Vault: leave a group (photos stay) or delete for everyone (creator
only); **story-style slideshow** with emoji/comment replies that post into the chat with a thumbnail;
hide photos from your own view; **save to gallery** (one photo or all, "Sonder" album). Photos upload at
about 2560×1920 with location data removed. Safety: report, block. Themes: Light (default), Pastel Glow,
Northern Lights, Aurora Blossom. App icon: "Stacked Polaroid, navy". Intro shutter animation.

Decisions the owner confirmed: leaving keeps your photos for the others; only the creator can delete a
capsule for everyone.

## Presentation (university project, 2 presenters)
Interactive pitch deck, "golden hour" look from the app icon: `presentation/pitch/index.html`
(published privately at https://claude.ai/artifact/DptyyPSgFWVAUXtZzKYnvR). 15 slides; Speaker 1 does
1–7 (story + live tappable demo), Speaker 2 does 8–15 (features, themes, tech, trust, business model,
proof, roadmap, countdown finale). Keys: → next, N notes, T timer, F full screen.
Still to do: fill `[Speaker 1]`, `[Speaker 2]`, `[Module]`, `[University]` and `[£__]` prices; swap the
stock photos in the gallery/slideshow screenshots for the owner's own photos (they're sending some).
The owner also asked about Canva; the deck can be recreated there if Canva is connected.

## Open items
- Google sign-in on iPhone needs an iOS OAuth client + `GOOGLE_IOS_CLIENT_ID` GitHub variable (IOS.md).
- Push on iPhone needs a paid Apple Developer account. Play Store: see PLAY_STORE.md.
- Before public launch: own domain for email (e.g. Resend) instead of a personal Gmail.
