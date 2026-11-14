# Getting Sonder ready for Google Play

The code for everything Google Play asks of a photo-sharing app is in place. This guide covers the parts
that need **your** accounts: Google sign-in, the signing key, and the Play Console forms.

| Requirement | Where it is in Sonder |
|---|---|
| Create an account | Login screen → *New here? Create an account*, or **Continue with Google** |
| Verified Google account | The server checks every Google sign-in with Google and only accepts verified emails |
| Delete account in the app | Profile → Privacy & Safety → **Delete account** (type DELETE to confirm) |
| Delete account on the web | `https://<your server>/delete-account` |
| Privacy policy | `https://<your server>/privacy` (also linked on the login screen and in Profile) |
| Terms / community rules | `https://<your server>/terms` |
| Report content | Long-press a chat message, or the **⋯** on a photo; **⋯** next to a friend |
| Block users | Same menus, plus Profile → **Blocked people** to unblock |
| Review reports | `https://<your server>/docs` → **Admin** section (only for `ADMIN_EMAILS`) |
| Friends | Home → 👥 button, Profile → **Manage**, or **Add friends** when creating a moment |

---

## 1. Make your signing key (one time, keep it forever)

Google Play and Google sign-in both recognise the app by this key. **If you lose it you can't update the
app**, so back up the file and the password somewhere safe (not in the repo).

In PowerShell (Java comes with Android Studio; if `keytool` isn't found, use
`& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"` instead):

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then show its fingerprints and copy the **SHA1** line:

```powershell
keytool -list -v -keystore upload-keystore.jks -alias upload
```

## 2. Give the key to GitHub (so the APK is signed with it)

Repo on GitHub → **Settings → Secrets and variables → Actions → Secrets → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Run `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) \| Set-Clipboard` and paste |
| `ANDROID_KEYSTORE_PASSWORD` | The password you chose |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | The same password (unless you set a different key password) |

Without these the build still works, but uses a throwaway key, so Google sign-in will say it's not set up.

## 3. Turn on Google sign-in (Google Cloud, free)

1. Go to <https://console.cloud.google.com>, create a project called **Sonder**.
2. Open **Google Auth Platform**. Fill in **Branding**: app name *Sonder*, your support email, and the
   privacy policy link `https://<your server>/privacy`. Under **Audience** choose **External**.
3. **Clients → Create client → Web application**, name it *Sonder server*. Copy the **Client ID**
   (looks like `1234-abc.apps.googleusercontent.com`). This is the one the app and server both use.
4. **Clients → Create client → Android**:
   - Package name: `com.example.sonder_app` (change this when we change the app ID)
   - SHA-1: the fingerprint from step 1
5. Back on GitHub → **Settings → Secrets and variables → Actions → Variables → New repository variable**:
   `GOOGLE_SERVER_CLIENT_ID` = the Web client ID from step 3.
6. On the server, add to `backend/.env` (or the host's environment variables):
   ```
   GOOGLE_CLIENT_IDS=<the Web client ID>
   ```

> When the app is on Google Play, Play re-signs it with its own key. Play Console → **Test and release →
> App integrity** shows the **App signing key** SHA-1. Add a second Android client in Google Cloud with
> that SHA-1, or Google sign-in will fail for people who install from the Play Store.

## 4. Server settings

Add these next to `DATABASE_URL` and `JWT_SECRET`:

```
GOOGLE_CLIENT_IDS=<Web client ID from step 3>
ADMIN_EMAILS=<the email you sign in to Sonder with>
SUPPORT_EMAIL=<an email you check, shown on the privacy policy>
DEVELOPER_NAME=<your name, shown on the privacy policy>
```

The database upgrades itself the next time the server starts (new tables for blocks, reports and
deletion requests).

### Reviewing reports

Google expects reports to be handled within about 24 hours. Open `https://<your server>/docs`, press
**Authorize** and paste your token (from `POST /api/auth/login`), then use the **Admin** section:

- `GET /api/admin/reports`: open reports, with a preview of the message or photo.
- `POST /api/admin/reports/{id}/resolve` with `dismiss`, `remove_content` or `delete_user`.
- `GET /api/admin/deletion-requests`: people who asked on the website. Email them to confirm, then
  `POST /api/admin/deletion-requests/{id}/complete`.

## 5. Play Console answers

**App content → Privacy policy:** `https://<your server>/privacy`

**App content → Data safety:**

| Question | Answer |
|---|---|
| Collects or shares user data? | Collects: **Yes**. Shares: **No** |
| Encrypted in transit? | **Yes** (once the server is on HTTPS) |
| Users can request deletion? | **Yes**, delete account URL: `https://<your server>/delete-account` |
| Personal info | **Name**, **Email address**, **User IDs**: collected, required, for *App functionality* and *Account management* |
| Photos and videos | **Photos**: collected, required, *App functionality* |
| Messages | **Other in-app messages**: collected, optional, *App functionality* |
| App activity | **Other user-generated content** (reports): collected, optional, *Fraud prevention, security* |
| Location, contacts, financial, health, device IDs | Not collected |

**App content → Target audience:** 13 and over (the terms say 13+).

**App content → Content rating:** answer that users can interact and share photos; that's expected
for this kind of app.

**User-generated content:** the questionnaire asks about the points in the table at the top of this
file: terms that ban objectionable content, in-app reporting, blocking, and moderation.
