# aldurar_alnaqia

This is a Flutter project.

Recent improvements:
- Fixed local audio playback path to use downloaded file IDs instead of titles.
- Added graceful completion/reset and disposal for the audio player.
- Tightened desktop window init to only run on desktop and awaited setup.
- Minor cleanup in drawer controller API to reduce prints and improve readability.

Development
- Requires Flutter 3.32+ and Dart 3.8+.
- Run: `flutter run -d linux` or your target platform.
