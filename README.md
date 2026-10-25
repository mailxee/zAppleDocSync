# zAppleDocSync

A native iPhone/iPad app (Swift + SwiftUI, iOS 17+) that syncs chosen folders and photo albums
between your devices through **Google Drive** — no iCloud.

Everything the app stores lives in a `zAppleDocSync` folder in your Drive. The app uses the
`drive.file` permission, so it can only see files it created, not the rest of your Drive.

## Status

| Phase | What | State |
|---|---|---|
| 1 | App skeleton, cloud build, Google sign-in, Drive folder | ✅ |
| 2 | Folder sync pairs + upload | ⏳ |
| 3 | Download/restore on other devices | ⏳ |
| 4 | Photo albums | ⏳ |
| 5 | Conflicts, deletions, background sync | ⏳ |

## How it's built (no Mac needed)

The repo has no Xcode project checked in. GitHub Actions (`.github/workflows/ios.yml`) runs on a
macOS machine, generates the project from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen),
runs the unit tests in an iPhone simulator, and builds an **unsigned `.ipa`** you can download from
the run's *Artifacts* section.

## One-time setup: Google sign-in

1. Go to <https://console.cloud.google.com/> and create a project.
2. **APIs & Services → Library**: enable **Google Drive API**.
3. **APIs & Services → OAuth consent screen** (Google Auth Platform): choose *External*, fill in the
   app name and your email, and add the scope `.../auth/drive.file`.
   Then set the publishing status to **In production**. (In *Testing* mode Google signs you out
   every 7 days. `drive.file` does not need Google's verification review.)
4. **Credentials → Create credentials → OAuth client ID**, type **iOS**, bundle ID
   `com.zapple.docsync` (if your sideloading tool changes the bundle ID, create another iOS client
   for the new ID).
5. Copy the client ID. It looks like `1234567890-abc123.apps.googleusercontent.com`.
   Take the part **before** `.apps.googleusercontent.com`.
6. In GitHub: **Settings → Secrets and variables → Actions → Variables → New repository variable**,
   name `GOOGLE_CLIENT_ID_PREFIX`, value = the part from step 5.
7. Re-run the *iOS build* workflow.

A build made without the variable still runs, but shows a "no Google client ID" message.

## Installing from Windows (free Apple ID)

1. Install **iTunes** and **iCloud for Windows** from apple.com (not the Microsoft Store versions).
2. Install **AltStore** (AltServer) or **Sideloadly**.
3. Download `zAppleDocSync-unsigned-ipa` from the latest successful GitHub Actions run and unzip it.
4. Connect the iPhone/iPad by USB and sideload the `.ipa` with your Apple ID.
5. On the device: **Settings → Privacy & Security → Developer Mode → On** (restart when asked), and
   trust your Apple ID under **Settings → General → VPN & Device Management**.

With a free Apple ID the app expires after 7 days. AltStore refreshes it automatically when your PC
is on the same Wi-Fi; with Sideloadly, reinstall it.

## Project layout

```
project.yml              XcodeGen project definition
Sources/App              App entry point and build configuration
Sources/Auth             Google sign-in
Sources/Drive            Google Drive REST client
Sources/Views            SwiftUI screens
Tests                    Unit tests (run in CI)
```
