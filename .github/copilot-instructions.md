## Project snapshot

- **App Name**: RideTrack — Personal bike ride tracking app with GPS, goals, statistics, and ride history.
- **Language & framework**: Flutter (Dart) app. Entry point: `lib/main.dart`.
- **Packages**: managed in `pubspec.yaml` (currently `cupertino_icons` + dev lints; expect GPS, maps, charts, and state management packages).
- **Platforms**: Android (`android/`), iOS (`ios/`), macOS, Windows, Linux and Web folders present.

## Big-picture architecture (quick)

- **Clean architecture** with separation: `data/` (models, repositories), `presentation/` (UI), `providers/` (state), `core/` (utilities, services).
- **Feature-based structure** in `presentation/pages/`: dashboard, ride tracking, goals, statistics, profile, settings.
- **GPS & background tracking**: Core feature requiring location permissions (Android: `AndroidManifest.xml`, iOS: `Info.plist`).
- Platform integration (native code, permissions, plugins) lives in platform subfolders: `android/`, `ios/`, `windows/`, `macos/`, `linux/`.
- Build outputs and temporary artifacts are under `build/` — do not edit generated files.

## App folder structure (`lib/`)

```
lib/
├── routes/                      # App navigation/routing config
├── core/
│   ├── constants/               # App-wide constants (colors, strings, API keys)
│   ├── utils/                   # Helper functions (date formatting, calculations)
│   └── services/                # GPS, storage, notification, auth services
├── data/
│   ├── models/                  # Data classes (Ride, Goal, User)
│   └── repositories/            # Data access layer (local DB, Firebase, auth)
├── presentation/
│   ├── components/              # Reusable small widgets (buttons, cards)
│   ├── widgets/                 # Feature-specific composite widgets
│   └── pages/                   # Full-screen pages
│       ├── auth/                # Login, register, forgot password, onboarding
│       ├── dashboard/           # Home screen: stats summary, recent rides
│       ├── ride/                # Start ride, live tracking, ride details
│       ├── goals/               # Goal setting and progress tracking
│       ├── statistics/          # Charts, all-time stats
│       ├── profile/             # User info, preferences, milestones
│       └── settings/            # App settings, privacy, notifications
└── providers/                   # State management (e.g., Riverpod, Provider, Bloc)
```

## Key files to inspect when making changes

- `lib/main.dart` — app entry, routing setup, theme configuration.
- `lib/routes/` — navigation/routing logic; centralized route definitions; route guards for auth.
- `lib/data/models/` — data classes for Ride, Goal, User (with JSON serialization).
- `lib/data/repositories/` — data persistence layer (local storage, Firebase sync, auth repository).
- `lib/core/services/` — GPS tracking, background location, notifications, storage, auth services.
- `lib/presentation/pages/` — feature pages (auth, dashboard, ride tracking, goals, statistics, profile, settings).
- `lib/providers/` — state management providers (expect Riverpod, Provider, or Bloc).
- `pubspec.yaml` — dependencies, assets, versioning (`version: 1.0.0+1`).
- `analysis_options.yaml` — linting rules; follow project lints when editing code.
- `test/` — unit and widget tests; mirror `lib/` structure for new features.
- `android/app/src/main/AndroidManifest.xml` — Android permissions (location, background services).
- `ios/Runner/Info.plist` — iOS permissions (location, background modes).

## Core features & their locations

**Authentication** (`presentation/pages/auth/`)
- Login, register, forgot password screens.
- Onboarding flow for new users (profile setup, preferences).
- Auth service in `core/services/auth_service.dart`; auth repository in `data/repositories/auth_repository.dart`.
- Auth state management in `providers/auth_provider.dart`.

**Dashboard** (`presentation/pages/dashboard/`)
- Total rides, distance, time; recent rides summary; weekly/monthly charts.
- Quick action buttons: Start Ride, Ride History, Goals.

**Start Ride** (`presentation/pages/ride/`)
- Real-time GPS tracking with live map, speed, distance, duration.
- Pause/Resume/End controls; background tracking support.
- End ride → summary screen → Save/Discard.

**Ride History** (`presentation/pages/ride/`)
- List all saved rides; filter by date/type; tap for details.

**Ride Details** (`presentation/pages/ride/`)
- Route map, full stats (distance, duration, speed, elevation); notes section.

**Goals** (`presentation/pages/goals/`)
- Set distance, frequency, or calorie targets; track progress with visual indicators.

**Statistics** (`presentation/pages/statistics/`)
- All-time stats; graphical insights (charts for weekly/monthly performance, trends).

**Profile** (`presentation/pages/profile/`)
- Manage user info (name, age, weight); preferences (units, default ride type); milestones.

**Settings** (`presentation/pages/settings/`)
- Account, ride settings (GPS accuracy, auto-pause), notifications, privacy, data backup/restore.

## Developer workflows (commands you can run)

- Install deps: `flutter pub get` (run from repo root).
- Run app (device/emulator): `flutter run` or `flutter run -d <deviceId>`; in terminal press `r` to hot-reload, `R` for hot-restart.
- Run tests: `flutter test` (runs `test/` tests); add tests in `test/` mirroring `lib/` structure.
- Build release artifacts: `flutter build apk` (Android), `flutter build ios`, `flutter build windows`, etc.
- Quick sanity: run `flutter doctor` if a platform build/device is failing.
- Check lints: `flutter analyze` before committing.

Notes for Windows PowerShell environments: commands are the same; use `flutter.bat` in PATH if needed.

## Codebase-specific patterns & conventions

- **Clean architecture**: Keep layers separate. Models in `data/models/`, repositories in `data/repositories/`, UI in `presentation/`, business logic in `providers/`.
- **Feature-based organization**: Group related files by feature (e.g., all ride tracking logic in `presentation/pages/ride/`).
- **State management**: Use chosen provider pattern (Riverpod/Provider/Bloc) consistently across features. Place providers in `lib/providers/`.
- **Services layer**: GPS, storage, notifications live in `core/services/`. These are singleton services injected via providers.
- **Models**: Use immutable data classes with JSON serialization (`fromJson`, `toJson`) in `data/models/`.
- **Routing**: Centralize route definitions in `lib/routes/` (e.g., using `go_router` or named routes).
- **Auth patterns**: Auth service in `core/services/`, auth repository in `data/repositories/`, auth UI in `presentation/pages/auth/`, auth state in `providers/`. Use route guards in `routes/` to protect authenticated pages.
- Linting: project uses `flutter_lints` and `analysis_options.yaml`. Keep new code compliant with those rules.
- Versioning: update `version:` in `pubspec.yaml` when making public or CI releases. Android/iOS use the same fields.
- Avoid editing generated files under `build/` or platform gradle caches. Edit Gradle build scripts only under `android/` when needed.

## Integration points & external dependencies

- Plugins/dependencies are declared in `pubspec.yaml` and must be fetched with `flutter pub get`.
- Expected key packages: GPS/location tracking (`geolocator`, `location`), maps (`google_maps_flutter`, `flutter_map`), charts (`fl_chart`), state management (`riverpod`/`provider`/`bloc`), local storage (`hive`, `sqflite`), Firebase (optional for backup/sync).
- Native platform behavior (e.g., Android permissions, iOS Info.plist) is controlled in `android/` and `ios/Runner/Info.plist`.
- **Location permissions**: Must configure for both foreground and background access (Android: `AndroidManifest.xml`, iOS: `Info.plist` with usage descriptions).
- **Background tracking**: Requires platform-specific setup (Android: Foreground Service, iOS: Background Modes).

## Guidance for AI code agents (what to do and what to avoid)

- Focus changes in `lib/` for UI and app logic. Use `test/` to add tests for new behavior (see `test/widget_test.dart`).
- If adding a dependency: update `pubspec.yaml`, run `flutter pub get`, and update any platform integration (Android/iOS) if the package requires it.
- Preserve `analysis_options.yaml` lint expectations. Run `flutter analyze` locally if possible before committing.
- Do NOT modify generated build outputs under `build/` or files outside the repo's source (e.g., user IDE files).

## Examples from this repo

- Entry point: `lib/main.dart` uses `MaterialApp`, `StatefulWidget` and `setState` — follow this style for small UI features.
- Tests: `test/widget_test.dart` shows typical widget test structure; new widgets should include similar tests.

## When to touch platform folders

- Modify `android/` when adding Android-specific native code or changing Gradle configurations (see `android/app/build.gradle.kts`).
- Modify `ios/Runner/` when adding iOS entitlements or Info.plist keys required by new plugins.

## Quick checklist before creating a PR

1. Run `flutter pub get` and `flutter analyze` — ensure no new analyzer errors.
2. Run `flutter test` — pass existing tests or add tests for new behavior.
3. Test GPS/location features on real devices (emulators may not fully simulate GPS).
4. Keep commits small and focused: library changes in `lib/`, tests in `test/`, native changes in platform folders.

---
If any part of this file is unclear or you'd like more detailed examples (CI steps, sample PR template, or common refactors), tell me which area to expand and I will iterate.
