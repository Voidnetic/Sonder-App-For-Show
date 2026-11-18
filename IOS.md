# Sonder on iPhone (Sideloadly)

GitHub builds `sonder.ipa` on its Mac servers every time the app changes (workflow "Build iPhone IPA").
It isn't signed, so you install it with **Sideloadly**, which signs it with your own Apple ID.

## Download the app

Open the **Sonder iPhone (latest build)** release on the repo's Releases page
(`https://github.com/Voidnetic/Sonder-App-For-Show/releases/tag/ipa-latest`) on your computer and download
`sonder.ipa`.

## Install it (Windows)

1. Install **iTunes** and **iCloud** from Apple's website (the versions from apple.com, *not* the Microsoft
   Store ones). Sideloadly needs them to talk to the iPhone.
2. Install **Sideloadly** from `sideloadly.io`.
3. Plug the iPhone into the PC with a cable. On the iPhone tap **Trust** and enter your passcode.
4. Open Sideloadly:
   - drag `sonder.ipa` onto it,
   - pick your iPhone in **iDevice**,
   - type your **Apple ID** email,
   - click **Start** and enter your Apple ID password when asked (it goes to Apple only).
5. On the iPhone: **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
6. On iOS 16 or newer, also turn on **Settings → Privacy & Security → Developer Mode** (the phone restarts).
7. Open Sonder.

## Every 7 days

Apple only lets apps signed with a free Apple ID run for 7 days. When Sonder stops opening, plug the phone in
and press **Start** in Sideloadly again (your login and data stay). Sideloadly can also refresh it over Wi-Fi
automatically: tick **Automatic refresh** in its advanced options.

A free Apple ID can have up to 3 sideloaded apps at once.

## What works

Everything except:

- **Push notifications**: need a paid Apple Developer account ($99 a year).
- **Continue with Google**: needs an iOS sign-in client (free, below). Until then, log in with your email or
  username and password.

## Turning on Google sign-in for iPhone (optional, free)

1. Google Cloud console (project `sonder-bb41b`) → **APIs & Services → Credentials → Create credentials →
   OAuth client ID**.
2. Application type **iOS**, name `Sonder iOS`, bundle ID `com.mhcorps.sonder`. Create.
3. Copy the **Client ID** (ends in `.apps.googleusercontent.com`; it isn't a secret).
4. GitHub repo → **Settings → Secrets and variables → Actions → Variables → New repository variable**:
   name `GOOGLE_IOS_CLIENT_ID`, value the client ID.
5. Re-run the "Build iPhone IPA" workflow (Actions tab → Run workflow) and reinstall the new `.ipa`.

If Sideloadly is set to change the bundle ID, Google sign-in won't match it; leave the bundle ID as is.
