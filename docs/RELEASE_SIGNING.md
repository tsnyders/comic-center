# Release signing

Android identifies an app by its package name **and** its signing key. Once a
device has Yomi installed, it will only accept an update signed with the same
key. An APK signed with a different key fails to install, and the system
installer reports nothing more useful than **"App not installed"**.

Yomi ships from GitHub Actions, signed with a single release keystore held in
repository secrets. Every published APK on the
[Releases page](https://github.com/tsnyders/comic-center/releases) uses that
key, so each build installs cleanly over the last one.

## Install the published APK, not a local build

Download `yomi-beta.apk` from the Releases page. A locally built
`app-release.apk` is signed with your machine's Android debug key, which does
not match the published key, so Android refuses to install it over a release
build.

If you deliberately want a local build on a device that already has a released
build, uninstall the app first. Export a backup from **Settings → Backup**
beforehand: backups written by current builds are portable files that survive
the uninstall.

## Building a release APK locally

`flutter build apk --release` fails unless `android/key.properties` exists,
because a debug-signed release APK cannot update anyone's install and the
failure only shows up on the device. Create the file next to
`android/app/`:

```properties
storeFile=yomi-release.jks
storePassword=<store password>
keyAlias=<key alias>
keyPassword=<key password>
```

`storeFile` is resolved relative to `android/app/`. Both `key.properties` and
`*.jks` are gitignored and must never be committed.

To produce a throwaway APK without the keystore, opt in explicitly:

```bash
flutter build apk --release --android-project-arg=allowDebugSigning=true
```

That APK is debug-signed. It installs only on devices that have no
release-signed copy of Yomi, and it cannot be distributed.

## Creating a keystore

Only needed when starting fresh. Losing the keystore means every existing
install must be uninstalled before it can be updated again, so keep a backup
somewhere durable.

```bash
keytool -genkey -v -keystore yomi-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias yomi
```

## CI secrets

The Android workflow reconstructs the keystore from these repository secrets:

| Secret | Contents |
| --- | --- |
| `KEYSTORE_FILE` | The `.jks` file, base64 encoded |
| `KEYSTORE_STORE_PASSWORD` | Store password |
| `KEYSTORE_KEY_ALIAS` | Key alias |
| `KEYSTORE_KEY_PASSWORD` | Key password |
| `GOOGLE_SERVICES_JSON` | `google-services.json`, base64 encoded |

Encode the keystore with:

```bash
base64 -w0 yomi-release.jks > yomi-release.jks.base64
```

After building, the workflow runs `apksigner verify` and fails if the APK
carries the debug certificate, so a build with missing or wrong secrets stops
in CI instead of shipping an APK nobody can install.

## Checking what signed an APK

```bash
apksigner verify --print-certs app-release.apk
```

`CN=Android Debug` means the debug key. A published build shows the release
certificate instead.
