# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev       # Start Vite dev server with HMR
npm run build     # Production build (always run before committing to verify no errors)
npm run lint      # ESLint
npm run preview   # Preview production build locally
```

No test suite is configured.

## Architecture

**MacroTracker** is a single-page nutrition tracking app. Stack: React 19 + Vite, Tailwind CSS (class-based dark mode), Radix UI primitives, Recharts, date-fns, Supabase (auth + PostgreSQL + storage), `@zxing/browser` for barcode scanning.

### Code layout

```
src/
  App.jsx              # ~5800-line monolithic component — all app state and logic lives here
  components/
    Auth.jsx           # Sign-up / sign-in / password reset
    ui/                # Shadcn-style primitives (button, card, input, select, switch, tabs, table)
  hooks/
    usePrefersDark.js  # System dark-mode preference
  lib/
    supabase.js        # Custom REST-based Supabase client (no SDK)
    utils.js           # cn(), formatNumber(), todayISO()
```

`App.jsx` is intentionally monolithic. Prefer editing it in place rather than extracting components unless a feature is genuinely self-contained.

### Date state — three synchronized values

There are three date state variables that must be kept in sync:

| State | Drives |
|---|---|
| `logDate` | Daily Log tab — which day is being logged |
| `dashboardDate` | Dashboard tab — which day all charts/cards show |
| `weekNavDate` | Weekly Nutrition chart — which week is displayed |

**Sync rules:**
- `logDate` changes → `useEffect` fires → sets `dashboardDate` + `weekNavDate`
- Dashboard date picker `onChange` → sets `dashboardDate` + `weekNavDate` directly
- Daily Log "Today" button → sets all three explicitly
- Week prev/next arrows → set `weekNavDate` only (intentional independent browse)

The "Totals for" header toggle (`stickyMode`) is **derived, not stored**: `effectiveStickyMode = (logDate !== today || dashboardDate !== today) ? 'selected' : stickyMode`. Never put `setStickyMode` inside a `useEffect` that depends on `logDate` — it causes a second render that closes native `<input type="date">` pickers mid-interaction.

### `DatePickerButton` — how date pickers work

`DatePickerButton` is a styled native `<input type="date">` with a decorative `CalendarIcon` overlay. The container calls `inputRef.current?.showPicker()` on click so the calendar opens from any click position. The `max` prop is always `todayISO()` (no future dates).

### Goal mode system

Users configure one of four setup modes: `dual` (separate train/rest day goals), `bulking`, `cutting`, `maintenance`. Key helpers:

- `resolveModeEntry(isoDate)` — returns the `{setup, profile}` entry for a date, accounting for per-date overrides in `settings.goalSchedule`
- `getGoalsForEntry(entry)` — returns `{kcal, protein, carbs, fat}` for a given mode entry
- `goalValuesForDate(iso)` — convenience wrapper combining both

### Supabase integration

Environment variables required in `.env.local`:
```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

`lib/supabase.js` implements the REST API directly (no `@supabase/supabase-js` SDK). Session is stored in `localStorage` under key `macrotracker.supabase.session` and proactively refreshed 60 seconds before expiry.

**Tables:** `foods`, `entries`, `profiles`, `user_badges`. All have RLS — users can only access their own rows. `profiles` is auto-created on signup via a DB trigger.

**Storage:** Avatar images in the `avatars` bucket at path `{user_id}/{filename}`.

### Settings persistence

`settings` object is stored in `localStorage` under `mt_settings`. It contains daily macro goals, the goal schedule (per-date mode overrides), profile history (weight/body fat log), and display preferences. Changes are also persisted to the `profiles` table in Supabase.

### Badge system

31 badges computed by `computeEarnedBadgeIds(entries, foods, goalValuesForDate)`. Badges are write-once (never unearn). New badges go into `badgeUnlockQueue` for popup display, then saved to `user_badges` table.

### Macro math

- `scaleMacros(food, qty)` — scales a food's macros by quantity (handles per-100g vs per-serving unit)
- `sumMacros(rows)` — aggregates an array of macro objects
- `computeRecipeTotals(components, foods)` — sums component foods for home recipes

### Barcode scanning

Uses `@zxing/browser` + Open Food Facts API. Triggered from the Food Database tab's "Add Food" modal.

---

## Flutter Mobile App

Located in `mobile/`. A companion app to the web MacroTracker, sharing the same Supabase backend.

### Commands

```bash
cd mobile
flutter run                  # Run on connected device / emulator
flutter build apk            # Android release build
flutter analyze              # Static analysis (run before committing)
flutter pub get              # Install dependencies after pubspec changes
```

No test suite is configured beyond `flutter_test` stubs in `test/`.

### Stack

Flutter + Dart, `flutter_riverpod` for state, `go_router` for navigation, `supabase_flutter` SDK (unlike the web app which uses raw REST), `fl_chart` for charts, `mobile_scanner` for barcode, `lottie` for animations.

### Code layout

```
mobile/lib/
  main.dart                  # App entry, Supabase.initialize, badge-unlock listener
  router.dart                # go_router config — auth guard, named routes
  theme.dart                 # AppTheme (light/dark), AppColorScheme extension, AppColors
  core/
    utils.dart               # todayISO(), formatNumber(), mealLabels, etc.
    constants.dart           # App-wide constants
    open_food_facts.dart     # Open Food Facts API client
    recipe_utils.dart        # computeRecipeTotals()
  models/
    food.dart                # Food, MacroValues, scaledMacros()
    entry.dart               # Entry, MacroValues, MacroGoals, sumMacros()
    badge.dart               # Badge definitions
  providers/
    settings_provider.dart   # settingsProvider (goals, schedule, profile) — syncs with Supabase
    entries_provider.dart    # entriesProvider(date) + macroTotalsProvider(date)
    foods_provider.dart      # foodsProvider — food database
    smart_insight_provider.dart  # smartInsightProvider — AI meal suggestions
    date_provider.dart       # currentDateProvider — app-wide selected date
    badges_provider.dart     # earnedBadgesProvider, badgeUnlockQueueProvider
    auth_provider.dart       # authStateProvider
  screens/
    home_screen.dart         # Bottom nav shell (Daily Log / Dashboard / Food DB / Profile)
    auth_screen.dart         # Sign-in / sign-up
    daily_log/               # Daily entry list + food logging
    dashboard/               # Charts, macro rings, history
    food_db/                 # Food search, add, edit
    onboarding/              # Goal setup wizard
    profile/                 # Weight log, body stats, badge gallery
  widgets/
    smart_insight_sheet.dart # Smart Insight modal (see below)
    macro_progress_card.dart
    weekly_chart.dart
    add_entry_sheet.dart
    barcode_scanner_sheet.dart
    badge_unlock_dialog.dart
    (and others — mostly self-contained modal bottom sheets)
```

### Theme system

`theme.dart` defines `AppColorScheme` as a `ThemeExtension` with `card`, `border`, `textPrimary`, `textMuted`, `kcalColor`, and `smartInsightColor` fields. Access via `AppColorScheme.of(context)`. Named colors (protein, carbs, fat, kcal, danger) live in `AppColors`.

**`smartInsightColor`** — theme-aware color for all Smart Insight icons:
- Dark mode: `AppColors.kcal` — `Color(0xFFD0C3F1)` lavender
- Light mode: `Color(0xFF9BC0DA)` — same soft sky blue as calories in light mode

### Smart Insight feature

**File:** `mobile/lib/widgets/smart_insight_sheet.dart`
**Branch merged into main:** `claude/add-ai-icon-smart-insight-om0Rx`

Smart Insight analyses 90 days of meal history (minimum 14 logged days), scores food combinations by how well they close today's remaining macro gaps, and surfaces up to 3 ranked suggestions per meal slot (breakfast / lunch / dinner / snack).

#### AI icon — three locations

`SpinningSparkle` (public widget, defined in `smart_insight_sheet.dart`) is used in three places, all reading `cs.smartInsightColor`:

| Location | Widget | Animation |
|---|---|---|
| Nav bar center (below FAB) | `SpinningSparkle(size: 26)` + "Smart Insight" label | Slow 5s linear 360° rotation |
| Main sheet header, next to "Smart Insight" title | `SpinningSparkle(size: 18)` | Slow 5s linear 360° rotation |
| "What is Smart Insight?" dialog title | `_SequentialStarsSparkle` | 3 staggered stars pop in/out |

**`SpinningSparkle`** — single `AnimationController` repeating over 5s, drives a `RotationTransition` on `Icons.auto_awesome_rounded`. Made public so `home_screen.dart` can import it.

**`_SequentialStarsSparkle`** — 44×44 `Stack` of 3 stars (26/17/11dp at different positions). Single 2.4s controller with staggered `Interval` animations per star. Each star: `elasticOut` scale pop-in, opacity 0→1→0 via a 30/40/30 `TweenSequence`. Stars activate at intervals 0.00–0.45 / 0.30–0.75 / 0.58–0.98, creating a ripple effect with a brief all-dark pause before the loop repeats.

#### Complete widget tree

| Class | Role |
|---|---|
| `_SmartInsightSheet` | Modal bottom sheet entry point (`showSmartInsightSheet()`). Reads `smartInsightProvider`. |
| `_CardDeck` | Slot selector + carousel shell. |
| `_SlotSelector` | Horizontal scrollable pill tabs (breakfast / lunch / dinner / snack). |
| `_OptionCarousel` / `_OptionCarouselState` | Spring-physics vertical stacked-card carousel. Swipe up → next option; swipe down → previous. |
| `_MealSlotCard` | Individual option card. Meal icon, "Option N" badge, 4× `_MacroDonut` in footer. Tap → opens `_MealDetailSheet`. |
| `_MealDetailSheet` / `_MealDetailSheetState` | Full detail bottom sheet. Food item list with per-item selection toggle, `_DonutImpactSection`, Log button. |
| `_DonutImpactSection` | Macro impact row using `_MacroDonut` at `size: 76`. Reacts live to item selection. |
| `_MacroDonut` / `_DonutPainter` | Donut ring showing current fill (muted arc) + projected addition (full-color arc). Overshoot signalled by a soft red `BoxShadow` glow. |
| `_InfoRow` | "What is Smart Insight?" tap target at the bottom of the carousel. Opens `AlertDialog` with `_SequentialStarsSparkle`. |
| `SpinningSparkle` / `SpinningSparkleState` | Public animated sparkle icon (rotating). Used in nav bar and sheet header. |
| `_SequentialStarsSparkle` | Private animated 3-star pop-in. Used in info dialog only. |
| `_EmptyState` | Shown when `loggedDays < 14` or all meals already logged today. |

#### Carousel mechanics

- `_ctrl` is an `AnimationController.unbounded()` — fractional page value (0 = card 0, 1 = card 1, 2 = card 2).
- `_dragRaw` accumulates raw (un-rubber-banded) drag position. Rubber-band (`×0.2`) applied once at output.
- `_topFor(i)` uses the clamped page: `rel ≤ 0 → rel * _cardHeight`, `rel > 0 → rel * _kPeekH`.
- Z-order: cards sorted furthest-from-page first (deepest), active card last (on top).
- `_cardHeight` floored at 80 dp to prevent zero/negative heights on small screens.
- Spring: `SpringDescription(mass:1, stiffness:600, damping:60)` — over-damped, no oscillation.

#### Detail sheet selection model

`_MealDetailSheetState` holds `Set<int> _selectedIndices` (all selected by default). The computed getter `_selectedMacros` sums `MacroValues` for selected items only via `MacroValues.sum()`. Both `_DonutImpactSection` and `_MacroSummaryRow` receive `_selectedMacros`, so donuts and totals update immediately on each tap. `_logAll()` iterates `_selectedIndices.toList()..sort()` — only selected items are sent to `entriesProvider`. The Log button is disabled when the selection is empty and shows "Log N items" for partial selections.

#### Overshoot indicator

When `current + addition > goal` for a macro, `_MacroDonut` keeps its attributed color and adds two `BoxShadow` layers (`AppColors.danger` at alpha 0.28/blurRadius 10 and alpha 0.10/blurRadius 20) on a `BoxShape.circle` container, producing a soft red glow.

---

## Flutter layout gotchas

### Rendering inside `ListTile.subtitle`

`ListTile` calls `getMinIntrinsicHeight` on its subtitle during tile-height measurement. This breaks several common layout approaches when used inside `ListTile.subtitle`:

| Approach | Result |
|---|---|
| `FractionallySizedBox` | Invisible — fails when parent provides unbounded width |
| `Row(Expanded, Expanded)` | Invisible — `ColoredBox` inside `Expanded` gets zero size |
| `LayoutBuilder` | Invisible — throws during intrinsic sizing pass, widget not rendered |
| `Transform.scale` | Has no effect on the underlying layout failure |

**Working pattern — use `CustomPaint` + `SizedBox.expand()`:**

```dart
Container(
  height: 4,
  child: CustomPaint(
    painter: _MyPainter(...),
    child: const SizedBox.expand(), // forces CustomPaint to fill available width
  ),
)
```

`SizedBox.expand()` inside `Container(height: N)` gets clamped to the tile's bounded width × N. The painter receives the correct `Size` and draws directly on canvas, bypassing widget layout entirely. Any fractional sizing (e.g. 50% width) is computed inside `paint(Canvas, Size)` rather than in the widget tree.

**Diagnostic approach:** replace the widget body with `Container(height: 8, color: Colors.red)` — if visible, the widget executes and the issue is in the rendering logic, not the call site.

---

## Branch & Git state (as of session 2026-04-28)

### Current branch structure

| Branch | Status |
|---|---|
| `main` | **Source of truth** — fully up to date, contains all features |
| `dev` | Keep — working branch |
| `claude/add-ai-icon-smart-insight-om0Rx` | Last feature branch — AI icon work, fully merged into main |
| 9 other `claude/*` branches | Have unmerged code differences vs. main — do not delete without reviewing |

**Always start new sessions from `main`** — it is the most complete branch.

### What was accomplished in session 2026-04-29

**Macro ratio bar fix + 50% width reduction (Flutter mobile, branch `claude/reduce-macro-bar-length-9wTwe`):**

1. Diagnosed that `Row/Expanded/ColoredBox` inside `ListTile.subtitle` silently produces invisible bars — `ListTile`'s intrinsic sizing pass breaks `FractionallySizedBox`, `LayoutBuilder`, and `Expanded`-based approaches
2. Rewrote `_MacroRatioBar` using `CustomPaint` + `SizedBox.expand()` inside `Container(height: 4)` — painter draws segments directly on canvas
3. Baked the 50% width reduction into the painter (`barWidth = size.width * 0.5`) with a `clipRRect` for rounded ends
4. Documented the `ListTile.subtitle` layout gotcha in CLAUDE.md

### What was accomplished in session 2026-04-28

**AI icon & animation work (Flutter mobile, merged into main):**

1. Added `Icons.auto_awesome_rounded` sparkle icon in two locations:
   - Next to "Smart Insight" title in the main bottom sheet header
   - At the top of the "What is Smart Insight?" `AlertDialog`

2. Animated both icons:
   - Sheet header & nav bar: `SpinningSparkle` — slow 5s continuous 360° rotation
   - Info dialog: `_SequentialStarsSparkle` — 3 staggered stars (large/medium/small) that elastically pop in and fade out sequentially over a 2.4s loop

3. Replaced the Lottie animation in the nav bar center with `SpinningSparkle(size: 26)` + "Smart Insight" label, removing the `lottie` import from `home_screen.dart`

4. Made `SpinningSparkle` public so it can be shared between `smart_insight_sheet.dart` and `home_screen.dart`

5. Added `smartInsightColor` to `AppColorScheme` (dark: lavender / light: sky blue) and wired all three icon sites to use it, replacing hardcoded `AppColors.kcal`

**Branch hygiene:**
- Cherry-picked all 6 feature commits onto `main` (resolved 2 minor conflicts)
- Deleted 4 fully-merged stale branches: `claude/fix-flutter-recipes-kSGH9`, `claude/profile-categories-ui-emxoo`, `claude/add-onboarding-questionnaire-9KkJu`, `claude/test-onboarding-macro-targets-z1OUc`
- Confirmed 9 remaining `claude/*` branches have real unmerged code — preserved
