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

## 1. Railway: the API and database

1. Sign up at <https://railway.com> with your GitHub account and choose the **Hobby** plan.
2. **New Project → Deploy from GitHub repo →** `Voidnetic/Sonder-App-For-Show`.
   If it asks, let Railway's GitHub app access this repository.
3. Click the new service, then **Settings**:
   - **Source → Root Directory:** `/backend`
   - **Source → Branch:** the branch with the latest code (`claude/wonderful-johnson-i2ajge` for now, or
     `main` once it's merged)
   - **Config-as-code → Railway Config File:** `/backend/railway.json`
4. In the project, **+ Create → Database → Add PostgreSQL**.
5. Click the API service → **Variables → New Variable** and add:

   | Name | Value |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (type it exactly like this; Railway fills in the real address) |
   | `JWT_SECRET` | A long random string; see the command below |
   | `ADMIN_EMAILS` | The email you'll use in the app, so you can review reports |
   | `SUPPORT_EMAIL` | An email you check (shown on the privacy policy) |
   | `DEVELOPER_NAME` | Your name |

   To make the `JWT_SECRET` value, run this in PowerShell and paste the 64 characters it prints:

   ```powershell
   $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [BitConverter]::ToString($b) -replace '-'
   ```

6. **Settings → Networking → Generate Domain.** You get an address like
   `https://sonder-api-production.up.railway.app`. Open it: you should see `{"status":"ok"}`.
   The tables are created automatically the first time it starts.
7. Check `https://<your address>/privacy` and `/docs` work too.

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

## 3. Firebase: push notifications

The app sends notifications for: a friend request, a request being accepted, being added to a moment,
new chat messages, and **"your moment is unlocked"**.

1. Go to <https://console.firebase.google.com> → **Add project**. If you already made the *Sonder* project in
   Google Cloud for Google sign-in, pick that one so everything stays together.
2. **Add app → Android.** Package name: the app ID (currently `com.example.sonder_app`; it changes when we
   set the real one, and then you add the new one here). You can skip downloading `google-services.json`
   and skip the "add SDK" steps; that's already done in code.
3. **Project settings (⚙️) → General → Your apps**, and the **Cloud Messaging** tab: copy the four values
   into GitHub (repo → **Settings → Secrets and variables → Actions → Variables → New repository variable**):

   | GitHub variable | Where it is in Firebase |
   |---|---|
   | `FIREBASE_API_KEY` | General → *Web API Key* |
   | `FIREBASE_APP_ID` | General → Your apps → *App ID* (starts with `1:` and contains `:android:`) |
   | `FIREBASE_MESSAGING_SENDER_ID` | Cloud Messaging → *Sender ID* |
   | `FIREBASE_PROJECT_ID` | General → *Project ID* |

   These identify the app and aren't secret, which is why they're *variables*, not secrets.
4. **Project settings → Service accounts → Generate new private key.** A `.json` file downloads. It **is**
   secret. Turn it into one line in PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\<the file>.json")) | Set-Clipboard
   ```

   In Railway → API service → **Variables**, add `FIREBASE_SERVICE_ACCOUNT` and paste. Then delete the
   downloaded file.

## 4. Point the app at the server

GitHub repo → **Settings → Secrets and variables → Actions → Variables**:

| Variable | Value |
|---|---|
| `SONDER_API_URL` | Your Railway address from step 1.6, e.g. `https://sonder-api-production.up.railway.app` |

The next APK build uses it as the default server, so people never have to type an address. (The
*Server* button on the login screen still lets you switch to your laptop for testing.)

To rebuild straight away: repo → **Actions → Build Android APK → Run workflow**.

## Checking it works

- `https://<your address>/` shows `{"status":"ok"}`.
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
