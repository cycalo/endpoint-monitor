# Android Build Toolchain Upgrade Design

## Goal

Remove Flutter's pending-support warnings by upgrading to the minimum requested
Android build tool versions while minimizing compatibility risk.

## Changes

- Upgrade the Gradle wrapper from 8.14 to 9.1.0.
- Upgrade the Android Gradle Plugin from 8.11.1 to 9.0.1.
- Upgrade the Kotlin Gradle Plugin and Kotlin BOM from 2.2.20 to 2.3.20.
- Keep Java and Kotlin JVM targets at Java 17.
- Do not upgrade unrelated Dart or Flutter dependencies.

## Validation

Run `flutter analyze`, then build a debug Android APK. The upgrade succeeds when
both commands pass and the three pending-support warnings no longer appear.

## Failure Handling

If the build exposes an AGP 9 migration incompatibility, use the build error to
make the smallest required configuration adjustment. Do not bypass Flutter's
dependency validation or broaden the dependency upgrade.
