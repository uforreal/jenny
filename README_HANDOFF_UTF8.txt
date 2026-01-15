This pack contains the complete source code, overrides, and configurations for the 'Jenny' Voice Project as of January 15, 2026.

Project State:
- UI: Premium Chat Interface (Midnight Gradient, Glassmorphism)
- Audio Engine: Native iOS DSP Chain (Method A) bypassing flutter_tts.
- DSP Profile: 'Clarity & Snap' (250Hz Warmth, 2500Hz Presence, 8000Hz Air).
- Build Pipeline: GitHub Actions with aggressive signing bypass and overrides injection.

Files Included:
1. lib/main.dart (Flutter UI + MethodChannel audio bridge)
2. pubspec.yaml (Project dependencies)
3. overrides/AppDelegate.swift (The Core DSP audio engine logic)
4. .github/workflows/build.yml (The CI/CD pipeline logic)
5. assets/ (Icons)

To resume work:
1. Unzip contents.
2. Push to a new GitHub repo.
3. The 'Build Unsigned IPA' workflow is plug-and-play.
