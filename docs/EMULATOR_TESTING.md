# Local Firebase Emulator Testing

The app uses production Firebase configuration by default. Emulator mode is enabled only with both explicit Dart defines:

```powershell
firebase emulators:start --config firebase.emulator.json --project learn-sign-ph
flutter run -d <device> `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=<development-machine-ip>
```

For a physical Android device, use the development machine's LAN address, not `127.0.0.1` or `10.0.2.2`. The emulator configuration binds Auth to port 9099 and Firestore to port 8080. The separate `firestore.emulator.rules` file is local-only and is never used by production deployment commands.

The sample lesson is intentionally labeled `Demo Lab (non-FSL sample)`. It is suitable for validating identification, matching, ordering, conversation, mixed activity parsing, and progress persistence. It must not be presented as authentic FSL teaching content.

No emulator data is written to the configured production Firebase project.
