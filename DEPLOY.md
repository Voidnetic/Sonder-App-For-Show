# Putting Sonder online

Three services, about **$5–10 a month** in total:

| Service | What it does | Cost |
|---|---|---|
| **Railway** | Runs the API (`backend/`) and the PostgreSQL database | Hobby plan, $5/month including $5 of usage |
| **Cloudflare R2** | Stores the photos, privately | Free up to 10 GB (a card is needed to turn R2 on) |
| **Firebase Cloud Messaging** | Push notifications | Free |

Do them in this order. Each step says exactly which value goes where. Keep every key and password out of
the repo: they only go into Railway's **Variables** or GitHub's **Secrets**.

---

## 1. Railway: the API and database ✅ (done)

Project **Sonder** on Railway has two services:

- **sonder-api**: built from `backend/Dockerfile` on branch `claude/wonderful-johnson-i2ajge`, Root Directory
  `/backend`, health check `/health`. Live at **https://sonder-api-production.up.railway.app**.
- **Postgres**: Railway's PostgreSQL template with a volume. The API created its tables on first start.

Variables already set on **sonder-api**: `DATABASE_URL` (`${{Postgres.DATABASE_URL}}`), `JWT_SECRET` (random,
64 characters), `PORT=8080`, `DEVELOPER_NAME`.

Still worth adding yourself (sonder-api → **Variables**): `ADMIN_EMAILS` (the email you use in Sonder, so you
can review reports) and `SUPPORT_EMAIL` (shown on the privacy policy).

The app always uses this address; there is no server setting in the app. To test the app against a backend on
your laptop, build it with `flutter run --dart-define=SONDER_API_URL=http://<laptop IP>:8000`.

> Until step 2 is done, photos are saved on Railway's disk, which is **wiped on every deploy**. Fine for a
> quick test, but do step 2 before real people use it.

## 2. Cloudflare R2: the photos

1. Sign up at <https://dash.cloudflare.com>, open **R2 Object Storage** and turn it on (adds a card; the
   first 10 GB a month are free).
2. **Create bucket**, name it `sonder-photos`. Leave it **private**: don't turn on public access or a
   custom domain. The API gives the app a link that works for one hour, and only once a moment has
   unlocked.
3. On the R2 overview page, copy your **Account ID**.
4. **Manage API tokens → Create API token**: permission **Object Read & Write**, limited to the
   `sonder-photos` bucket. Copy the **Access Key ID** and **Secret Access Key** (the secret is shown once).
5. In Railway → API service → **Variables**, add:

   | Name | Value |
   |---|---|
   | `R2_ACCOUNT_ID` | Account ID from step 3 |
   | `R2_ACCESS_KEY_ID` | Access Key ID |
   | `R2_SECRET_ACCESS_KEY` | Secret Access Key |
   | `R2_BUCKET` | `sonder-photos` |

Railway redeploys by itself after you change variables.

## 3. Firebase: push notifications (app side ✅ done)

The app sends notifications for: a friend request, a request being accepted, being added to a moment,
new chat messages, and **"your moment is unlocked"**.

1. Go to <https://console.firebase.google.com> → **Add project**. If you already made the *Sonder* project in
   Google Cloud for Google sign-in, pick that one so everything stays together.
2. **Add app → Android.** Package name: `com.mhcorps.sonder` (it must match exactly). App nickname: `Sonder`.
   Skip downloading `google-services.json` and skip the "add SDK" steps; that's already done in code.
3. The app's Firebase values (project `sonder-bb41b`) are built into `lib/data/push_service.dart`. They are not
   secret. If you ever make a new Firebase project, update them there.
4. **Project settings → Service accounts → Generate new private key.** A `.json` file downloads. It **is**
   secret. Open it in Notepad, copy everything, and in Railway → sonder-api → **Variables** add
   `FIREBASE_SERVICE_ACCOUNT` with the whole file as the value. Click **Deploy**, then delete the downloaded file.

## 3b. Email codes: verification and "Forgot password?"

Until this is set up, nothing changes: email/password accounts work without a code and "Forgot password?"
says it isn't available yet. Once it's set up, new email sign-ups confirm their address with a 6-digit code
(Google sign-ins are already verified), and unverified accounts can't add friends or create moments.

Pick **one** sender and add its variables to Railway → sonder-api → **Variables**, then **Deploy**. The deploy
log then says `Email codes: on`.

**Option A: Gmail through the Gmail API (free; works on Railway Hobby).** Railway's Hobby plan blocks
outgoing SMTP (it's Pro-only), so on Hobby Gmail has to be used through its HTTPS API:
1. Google Cloud console, project `sonder-bb41b` → **APIs & Services → Library** → search **Gmail API** →
   **Enable**.
2. **APIs & Services → Credentials → Create credentials → OAuth client ID** → type **Web application**, name
   `Sonder mail`, **Authorized redirect URIs** → add `https://developers.google.com/oauthplayground` → Create.
   Copy the **Client ID** and **Client secret**.
3. Open <https://developers.google.com/oauthplayground> → gear icon (top right) → tick **Use your own OAuth
   credentials** → paste the Client ID and secret → close.
4. On the left, in **Input your own scopes**, type `https://www.googleapis.com/auth/gmail.send` →
   **Authorize APIs** → sign in with the Gmail the codes should come from. On "Google hasn't verified this
   app": **Advanced → Go to … (unsafe)** → **Continue** (it's your own app).
5. **Exchange authorization code for tokens** → copy the **Refresh token**.
6. Railway variables (and delete any `SMTP_*` ones, they can't connect on Hobby):

   | Name | Value |
   |---|---|
   | `GMAIL_CLIENT_ID` | the Client ID |
   | `GMAIL_CLIENT_SECRET` | the Client secret |
   | `GMAIL_REFRESH_TOKEN` | the refresh token |
   | `EMAIL_FROM` | the Gmail address you signed in with in step 4 |

   Gmail allows about 500 emails a day. The log says `Email codes: on (Gmail API)`.

   (On Railway **Pro**, plain SMTP with a Gmail app password also works: `SMTP_HOST=smtp.gmail.com`,
   `SMTP_PORT=587`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `EMAIL_FROM`.)

**Option B: Resend (best delivery, needs your own domain).**
1. Sign up at <https://resend.com>, **Domains → Add domain** (e.g. `sonderapp.com`) and add the DNS records it
   shows (easy if the domain is on Cloudflare).
2. **API Keys → Create API key** (sending access).
3. Railway variables: `RESEND_API_KEY` = the key, `EMAIL_FROM` = e.g. `hello@sonderapp.com`.

   Free for 3,000 emails a month.

## 4. Point the app at the server ✅ (done)

The app's default server is `https://sonder-api-production.up.railway.app`. To use a different one for a build,
set the GitHub repository variable `SONDER_API_URL`.

## Checking it works

- `https://<your address>/health` shows `{"status":"ok"}`.
- Sign up in the app, add a friend (second phone or account), create a moment, take a photo.
  In Cloudflare → R2 → `sonder-photos` a new file appears under `memories/`.
- On the friend's phone a notification arrives for the friend request and the new moment. Android 13+
  asks "Allow notifications?" the first time you log in.
- Railway → API service → **Deployments → View logs** shows any errors.

## Settings reference

| Railway variable | Required | Purpose |
|---|---|---|
| `DATABASE_URL` | Yes | `${{Postgres.DATABASE_URL}}` |
| `JWT_SECRET` | Yes | Signs logins. At least 32 random characters; the API won't start on Railway without it |
| `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` | For real use | Photo storage |
| `FIREBASE_SERVICE_ACCOUNT` | For notifications | Base64 of the service account JSON |
| `GOOGLE_CLIENT_IDS` | For Google sign-in | Web client ID (see `PLAY_STORE.md`) |
| `ADMIN_EMAILS` | Recommended | Who can review reports |
| `SUPPORT_EMAIL`, `DEVELOPER_NAME` | Recommended | Shown on the privacy policy |
| `SEED_DEMO_DATA` | No | `true` adds the demo users. **Don't** use it for the real app: their password is public |
