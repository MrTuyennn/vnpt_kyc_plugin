# SDK 2.0 example (device QA)

Credentials are **compile-time**, not typed in the app.

## 1. One-time setup

```bash
cp env.local.json.example env.local.json
# Edit env.local.json — paste staging keys (file is gitignored)
flutter pub get
```

## 2. Run / build on device

```bash
flutter run --dart-define-from-file=env.local.json -d <device_id>

# Release-style
flutter build apk --dart-define-from-file=env.local.json
flutter build ios --dart-define-from-file=env.local.json
```

Without `env.local.json` + dart-define, the app starts **without** API creds (engine-only tests still work).

Device test steps and log tags: **[TESTING.md](./TESTING.md)**.

## 3. In-app

- **T0** only shows the baked-in config (read-only when built with `--dart-define-from-file`).
- **T1** full flow after creds are in `env.local.json`.