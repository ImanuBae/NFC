# Architectural & Implementation Decisions

This document records decisions made when specs are ambiguous or when technical choices require documentation.

## Decisions

### 1. Platform configuration
- Target platforms: Android and Web only. Removed unused desktop (windows, linux, macos) and ios directories to align with Section 7 M0 and avoid Windows developer mode symlink requirements during plugin builds.

### 2. Dependencies
- Dependencies pinned and resolved in `pubspec.yaml` matching Section 2 of `NFC_ATTENDANCE_PLAN.md`.
- Added `mocktail` for Dart mock testing as specified in plan.

### 3. Min SDK
- Explicitly set Android `minSdk = 23` in `android/app/build.gradle.kts` as required in Section 2.
