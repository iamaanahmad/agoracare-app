# AgoraCare Flutter App

Voice AI healthcare companion built with Flutter, Agora Conversation AI, and Firebase.

## Run locally

Provide the Firebase Android API key at build time. Do not commit the key or Firebase configuration files:

```bash
flutter pub get
flutter run --dart-define=AGORACARE_FIREBASE_API_KEY=your-firebase-api-key
```

The Firebase project ID and app metadata are public configuration; the API key is supplied through the local build environment.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
