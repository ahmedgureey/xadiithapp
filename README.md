# Xadiis App

Read, Understand, Learn, Memorize. A Flutter app (Android and iOS) that helps Somali speakers read, understand, study and memorize authentic Hadiths, backed by a NestJS + PostgreSQL REST API deployed on Coolify.

```
Flutter app  ──HTTPS / REST (/api/v1)──▶  NestJS API (Docker)  ──private network──▶  PostgreSQL
                                           └──────────── deployed on Coolify ────────────┘
```

| Part | Location | Docs |
|------|----------|------|
| Mobile app (Flutter, Material 3, Riverpod, go_router, Dio) | `lib/`, `test/` | this file |
| REST API (NestJS, Prisma, JWT) | `backend/` | [backend/README.md](backend/README.md) |
| Deployment | `backend/Dockerfile`, `backend/docker-compose.yml` | [docs/DEPLOYMENT_COOLIFY.md](docs/DEPLOYMENT_COOLIFY.md) |

## Religious content policy

The app never ships or invents Hadith text, translations, gradings or references. All religious content comes from the API, and the API only serves Hadiths whose status is `PUBLISHED`. A Hadith can only be published through the review workflow (editor drafts it, then a different reviewer approves it, and it must have a source reference and a sourced grading). Empty states say plainly that verified content isn't available yet.

## Running the app

```bash
flutter pub get
```

Point the app at an API using `--dart-define`. Never hardcode the production URL:

```bash
# Local backend (Android emulator reaches the host via 10.0.2.2; this is also the default)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

```bash
# Deployed backend
flutter run --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Plain-HTTP traffic is allowed only in Android **debug** builds (`android/app/src/debug/AndroidManifest.xml`) and for iOS local networking (`NSAllowsLocalNetworking`). Release builds require HTTPS.

## Code structure

```
lib/
  main.dart, app.dart              Bootstrap, ProviderScope, MaterialApp.router
  core/
    config/app_config.dart         API_BASE_URL (dart-define), timeouts
    network/api_client.dart        Dio + bearer token + one-shot refresh on 401
    network/api_exception.dart     Normalized errors (network/timeout/401/404/…)
    storage/token_storage.dart     Tokens in Keychain/Keystore (flutter_secure_storage)
    storage/local_store.dart       Preferences, offline favorites, recently viewed
    l10n/app_strings.dart          UI copy: Somali (default) + English
    theme/app_theme.dart           Dark green / emerald / cream, light + dark
    router/app_router.dart         go_router, 5-tab StatefulShellRoute
    providers.dart                 Riverpod providers (settings, auth, favorites, …)
    widgets/                       ArabicText (RTL), SomaliText (LTR), cards, states
  data/
    models/models.dart             API contract models (JSON round-trip)
    repositories/                  HadithRepository, Auth/Bookmark/Memorization/History
  features/                        splash, onboarding, home, collections, hadith,
                                   search, favorites, memorization, profile, auth, shell
```

### Behaviour notes

- **Guests** can browse, search and read everything public. Favorites and recently viewed are stored on the device.
- **Signed in:** local favorites are merged into server bookmarks on login, then kept in sync. Reading history is recorded server-side too.
- **Memorization** progress (SM-2 spaced repetition) is stored server-side, so it requires sign-in. The daily goal is a device setting.
- **Offline:** the six collection names still show (they're static facts). Everything else shows an error state with a retry button.
- **Somali UI copy** in `app_strings.dart` should be reviewed by a native speaker before release.

## Tests

```bash
flutter analyze
flutter test
```

Tests use an in-memory fake HTTP adapter (`test/helpers/fake_api.dart`) with obviously fake fixture strings, so they don't need a network connection.

## Before release

- Change `applicationId` / `namespace` (`android/app/build.gradle.kts`, currently `com.example.xadiithapp`) and the iOS bundle identifier to your own.
- Configure release signing (Android keystore, Apple team).
- Replace the default launcher icons and native splash.
- Bundle an Arabic Quranic font (e.g. Amiri, under the SIL OFL license) for consistent rendering.
