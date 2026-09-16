# Remove Dashboard 24H Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely remove the Dashboard 24H Activity feature and its unused supporting code.

**Architecture:** Remove the feature at its composition points in the Dashboard and application provider tree, then delete the isolated bloc and card implementation. Update user-facing documentation and verify no symbols or copy remain.

**Tech Stack:** Flutter, Dart, flutter_bloc, Flutter test tooling

## Global Constraints

- Preserve disconnected, offline, Threat Intel, and system metrics behavior.
- Do not add dependencies.
- Do not alter unrelated uncommitted work.

---

### Task 1: Remove the 24H Activity feature

**Files:**
- Modify: `flutter_app/lib/screens/dashboard_screen.dart`
- Modify: `flutter_app/lib/app.dart`
- Delete: `flutter_app/lib/bloc/activity_heatmap_bloc.dart`
- Delete: `flutter_app/lib/widgets/activity_heatmap_card.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: Existing `DashboardScreen` widget tree and `MultiBlocProvider`.
- Produces: A Dashboard without `ActivityHeatmapBloc`, `ActivityHeatmapCard`, `_DashboardDataBootstrap`, or `_DashboardActivityHeatmap`.

- [ ] **Step 1: Establish the removal baseline**

Run:

```bash
rg -n "ActivityHeatmap|activity_heatmap|24H ACTIVITY|activity heatmap" flutter_app/lib README.md
```

Expected: Matches in the Dashboard, app provider tree, activity heatmap bloc/widget files, and README.

- [ ] **Step 2: Remove Dashboard composition and refresh behavior**

In `flutter_app/lib/screens/dashboard_screen.dart`:

- Remove imports of `activity_heatmap_bloc.dart` and `activity_heatmap_card.dart`.
- Remove `_DashboardDataBootstrap` from the Dashboard column.
- Change the Dashboard subtitle to `Live endpoint health and system identity.`
- Remove `_DashboardActivityHeatmap` and its following spacing.
- Delete `_DashboardDataBootstrap`, `_DashboardDataBootstrapState`, and `_DashboardActivityHeatmap`.

- [ ] **Step 3: Remove the provider and implementation files**

In `flutter_app/lib/app.dart`, remove:

```dart
BlocProvider(create: (_) => ActivityHeatmapBloc()),
```

Delete:

```text
flutter_app/lib/bloc/activity_heatmap_bloc.dart
flutter_app/lib/widgets/activity_heatmap_card.dart
```

- [ ] **Step 4: Update documentation**

In `README.md`, replace the Dashboard overview sentence so it ends with:

```text
real-time visibility into the endpoint's health, CPU/RAM utilization, and active socket counts.
```

- [ ] **Step 5: Format and verify symbol removal**

Run:

```bash
cd flutter_app
dart format lib/screens/dashboard_screen.dart lib/app.dart
cd ..
rg -n "ActivityHeatmap|activity_heatmap|24H ACTIVITY|activity heatmap" flutter_app/lib README.md
```

Expected: Formatting succeeds and the search returns no matches.

- [ ] **Step 6: Run static analysis and tests**

Run:

```bash
cd flutter_app
flutter analyze
flutter test
```

Expected: Both commands exit successfully.

- [ ] **Step 7: Commit the implementation**

```bash
git add README.md flutter_app/lib/app.dart flutter_app/lib/screens/dashboard_screen.dart flutter_app/lib/bloc/activity_heatmap_bloc.dart flutter_app/lib/widgets/activity_heatmap_card.dart docs/superpowers/plans/2026-09-17-remove-dashboard-24h-activity.md
git commit -m "refactor: remove dashboard activity heatmap"
```
