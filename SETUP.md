# Sonder: setup guide

This guide gets the Sonder app running on your computer and your Android phone: the PostgreSQL
database, the backend API, and the Flutter app.

## What's in this project

| Folder / file | What it is |
|---|---|
| `lib/`, `android/`, `pubspec.yaml` | The Flutter mobile app |
| `backend/` | The API server (Python, FastAPI) |
| `backend/db/01_schema.sql` | The PostgreSQL tables |
| `backend/db/02_seed.sql` | Demo data: 5 users, 3 moments, chat messages |
| `backend/scripts/setup_db.ps1`, `setup_db.sh` | Create the database for you |

---

## Step 1: Install the tools (one time)

| Tool | Why | Download |
|---|---|---|
| **Flutter SDK** | Builds and runs the app | https://docs.flutter.dev/get-started/install |
| **Android Studio** | Android SDK, emulator, and USB drivers that Flutter needs | https://developer.android.com/studio |
| **VS Code** (optional) with the **Flutter** extension | Easiest way to debug | https://code.visualstudio.com |
| **PostgreSQL 13+** | The database | https://www.postgresql.org/download/ |
| **Python 3.11+** | Runs the API. On Windows, tick **"Add python.exe to PATH"** | https://www.python.org/downloads/ |

When installing PostgreSQL, **write down the password you choose for the `postgres` user.**
You'll need it in step 2.

Check Flutter, then fix anything it marks with ✗:

```bash
flutter doctor
flutter doctor --android-licenses
```

---

## Step 2: Create the database (one time)

Open a terminal in the project folder (the folder that contains this file) and run:

Windows (PowerShell):
```powershell
powershell -ExecutionPolicy Bypass -File backend\scripts\setup_db.ps1
```

macOS / Linux:
```bash
bash backend/scripts/setup_db.sh
```

Enter the `postgres` password from step 1 when asked. The script creates a `sonder` database
and user, the tables, the demo data, and the `backend/.env` settings file. You should see
`Database ready`. The script is safe to run again.

### See the data (optional)

pgAdmin is installed together with PostgreSQL. To browse the tables, open pgAdmin, right-click
**Servers → Register → Server**, and enter:

| Field | Value |
|---|---|
| Name (General tab) | `Sonder` (any name works) |
| Host | `localhost` |
| Port | `5432` |
| Maintenance database | `sonder` |
| Username | `sonder` |
| Password | `sonder` |

Then open Sonder → Databases → sonder → Schemas → public → Tables. Right-click a table and
choose **View/Edit Data → All Rows**.

From a terminal, `psql -h localhost -U sonder -d sonder` does the same (password `sonder`).

---

## Step 3: Start the API

**The first time**, install the Python packages:

Windows:
```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

macOS / Linux:
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Every time**, start the API from the `backend` folder with the virtual environment active:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

If Windows asks whether to allow Python through the firewall, click **Allow** (private networks).
The phone needs that to reach the API.

Leave this terminal open and open **http://localhost:8000/docs** in a browser. If you see the
"Sonder API" page, the API and database are working.

### Try the API

All demo accounts use the password **`sonderpass123`**: `hassan@sonder.app`, `ali@sonder.app`,
`ahmed@sonder.app`, `hajra@sonder.app`, `manaal@sonder.app`.

1. On the docs page, open **POST /api/auth/login**, click **Try it out**, enter Hassan's email
   and password, and click **Execute**.
2. Copy the `access_token` from the response.
3. Click **Authorize** at the top, paste the token, and confirm.
4. Run **GET /api/moments/active**. You should see "Birthday Night" and "Murree Trip".

---

## Step 4: Run the app on your phone

Keep the API from step 3 running. The app gets all its data from it.

1. On the Android phone, turn on **Developer options**: go to Settings → About phone and tap
   **Build number** 7 times.
2. In Settings → Developer options, turn on **USB debugging**.
3. Connect the phone with a USB cable and accept the "Allow USB debugging?" prompt on the phone.
4. In a **new** terminal, in the project folder:

   ```bash
   flutter devices     # your phone should be listed
   flutter pub get
   flutter run
   ```

   The first build is slow: Gradle downloads about 2 GB of Android build tools, including
   the Android NDK, so allow 10–30 minutes depending on your internet. Later builds take
   under a minute. While the app runs, press `r` in the terminal to hot-reload changes, or
   `q` to quit.

**To debug** with breakpoints, open the project folder in VS Code (or Android Studio), pick
your phone in the device selector at the bottom right, and press **F5**.

No phone? Create an emulator in Android Studio (Device Manager → Create device), start it,
then run `flutter run`.

iPhones need a Mac with Xcode. See https://docs.flutter.dev/get-started/install/macos.

### Or: install the APK without a cable

Every push builds an APK on GitHub (workflow **Build Android APK**). On the phone, open the
repository's **Releases** page, open **Sonder APK (latest build)**, tap `sonder.apk`, and allow
the browser to install apps when Android asks. The API still has to run on your computer
(step 3), and the phone needs its address (next section).

### Point the app at your computer (first launch)

The app opens on a login screen. At the bottom is a yellow **Server** button. Tap it and enter
the address of the computer running the API:

| Where the app runs | Server address |
|---|---|
| Android emulator | `http://10.0.2.2:8000` (already the default) |
| Real phone, on the **same Wi-Fi** as the computer | `http://<computer's IP>:8000` |

To find the computer's IP, run `ipconfig` on Windows (the "IPv4 Address" line, for example
`192.168.1.20`) or `ipconfig getifaddr en0` on macOS. The app remembers the address.

Then log in with a demo account, for example `hassan@sonder.app` / `sonderpass123`, or tap
**Create an account**.

To check the phone can reach the API, open `http://<computer's IP>:8000/docs` in the
**phone's** browser. If that doesn't load, the app can't connect either. See Troubleshooting.

### What to try

- **Home**: Hassan's moments with live countdowns. Pull down to refresh.
- **Create moment**: pick friends and a reveal time.
- **Open a moment**: capture photos (they stay hidden) and chat in the **Hangout** tab. Log in
  as `ali@sonder.app` on a second phone or emulator to see messages arrive live.
- **Reveal**: on the **Moments** tab, open **Summer Beach Trip** ("Ready to reveal"), tap
  **Reveal**, then **Explore memories** to see its photos. Or create a moment with **Custom** set a
  minute or two ahead, add a photo, wait for the countdown, then reveal it.

**Before a demo**, reset the database (see Troubleshooting: "Start the database over"). The demo
times are counted from when the database was created: Birthday Night unlocks about 2 hours later,
and Summer Beach Trip can only be revealed once per reset.
- **Moments** tab: unlocked moments. **Profile** tab: stats, friends, log out.

---

## Run the tests

From the project folder:

```bash
flutter analyze        # code checks
flutter test           # app tests, with a fake server (no backend needed)
```

With the API running, this also tests the app against the real backend:

```bash
# macOS / Linux
SONDER_API_URL=http://localhost:8000 flutter test test/api_live_test.dart
```
```powershell
# Windows PowerShell
$env:SONDER_API_URL="http://localhost:8000"; flutter test test/api_live_test.dart
```

The live test adds test moments to the database. Recreate the database (see Troubleshooting)
to clean up.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `psql.exe not found` / `psql not found` | Install PostgreSQL (step 1). On macOS/Linux, make sure `psql` is on your PATH. |
| `password authentication failed for user "postgres"` | Use the password chosen when PostgreSQL was installed, not `sonder`. |
| PowerShell says scripts are disabled | Use the exact `powershell -ExecutionPolicy Bypass -File ...` command from step 2. |
| `python` not recognized (Windows) | Reinstall Python with **"Add python.exe to PATH"** ticked, then open a new terminal. |
| API stops with `Cannot connect to PostgreSQL` | PostgreSQL isn't running, or `DATABASE_URL` in `backend/.env` has the wrong password or port. |
| API stops with `Sonder tables are missing` | Run step 2 again. |
| `flutter devices` doesn't show the phone | Check USB debugging is on, accept the prompt on the phone, try another cable, and set the USB mode to "File transfer". |
| App says `Can't reach the server at ...` | Check the Server address on the login screen. Use the same Wi-Fi as the computer, start the API with `--host 0.0.0.0`, and allow Python through the firewall. Test by opening `http://<computer's IP>:8000/docs` in the phone's browser. |
| Works at home but not on university / public Wi-Fi | Those networks often block devices from reaching each other. Turn on the phone's hotspot, connect the computer to it, and use the computer's new IP as the Server address. |
| App was logged in but now shows the login screen | The login expired (after 7 days) or the database was recreated. Log in again. |
| Camera button does nothing on an emulator | Use the gallery button next to the shutter, or turn on the emulator camera in Android Studio's Device Manager. |
| Start the database over with fresh demo data | In pgAdmin or `psql`, run `DROP DATABASE sonder;` as the `postgres` user, then run step 2 again. |
