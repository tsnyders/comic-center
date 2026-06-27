# Enabling Google Drive backup on iOS

Drive backup uses `google_sign_in` + the Drive REST API. On iOS that needs an
**iOS OAuth 2.0 client ID** and its **reversed-client-ID** URL scheme. The app
code is already wired — you only supply two values (the client ID and its
reversed form) and rebuild. Until then the app runs fine and shows a friendly
"Drive not set up" message; **local backup/restore keeps working.**

App bundle ID: `com.comiccenter.comicCenter`

---

## 1. Get an iOS OAuth client ID

Either path produces the same thing — pick one.

### Option A — Firebase (easiest; also gives the reversed ID)
1. https://console.firebase.google.com → open (or create) a project.
2. **Add app → iOS**, bundle ID `com.comiccenter.comicCenter`.
3. Download **GoogleService-Info.plist**. Inside it you'll find:
   - `CLIENT_ID`  → e.g. `1234567890-abcd.apps.googleusercontent.com`
   - `REVERSED_CLIENT_ID` → e.g. `com.googleusercontent.apps.1234567890-abcd`

### Option B — Google Cloud Console (no Firebase)
1. https://console.cloud.google.com/apis/credentials
2. **Create Credentials → OAuth client ID → iOS**, bundle ID
   `com.comiccenter.comicCenter`.
3. Copy the **Client ID**. The reversed ID is just the client ID with its two
   dot-separated halves swapped → `com.googleusercontent.apps.<the-number-part>`.

---

## 2. Configure the OAuth consent screen (one-time)
Drive's `drive.file` scope is "sensitive", so the consent screen must exist:
1. Cloud Console → **APIs & Services → OAuth consent screen**.
2. User type **External**, fill app name + support email, save.
3. **Enable the Google Drive API**: APIs & Services → Library → "Google Drive
   API" → Enable.
4. Leave publishing status on **Testing** and add your Google account
   (e.g. `zimasilevuyo@gmail.com`) under **Test users**. Test users can use the
   app without Google verification (you'll see an "unverified app" notice — tap
   through it).

---

## 3. Drop the two values into the app

**a) Client ID** — paste into `lib/core/config/google_drive_config.dart`
(`defaultValue:`), or pass it at build time:

```bash
flutter build ios --release \
  --dart-define=GOOGLE_IOS_CLIENT_ID=1234567890-abcd.apps.googleusercontent.com
```

**b) Reversed client ID** — replace the placeholder in
`ios/Runner/Info.plist` (the `CFBundleURLSchemes` string):

```xml
<string>com.googleusercontent.apps.1234567890-abcd</string>
```

---

## 4. Rebuild & test
```bash
flutter clean && flutter pub get
flutter run --release          # or build from Xcode
```
Settings → **Connect Google Drive** should now open the Google sign-in sheet,
and **Backup to Drive** will create a `Yomi Backups` folder in your Drive.

> Android: the same feature needs `android/app/google-services.json` from a
> Firebase Android app (package `com.comiccenter.comic_center`) — out of scope
> for the iOS setup above.
