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
    smart_insight_sheet.dart # ← ACTIVE WORK (see below)
    macro_progress_card.dart
    weekly_chart.dart
    add_entry_sheet.dart
    barcode_scanner_sheet.dart
    badge_unlock_dialog.dart
    (and others — mostly self-contained modal bottom sheets)
```

### Theme system

`theme.dart` defines `AppColorScheme` as a `ThemeExtension` with `card`, `border`, `textPrimary`, `textMuted`, `kcalColor` fields. Access via `AppColorScheme.of(context)`. Named colors (protein, carbs, fat, kcal, danger) live in `AppColors`.

### Smart Insight feature

**File:** `mobile/lib/widgets/smart_insight_sheet.dart`  
**Branch:** `claude/meal-card-carousel-7EWwK`

Smart Insight analyses 90 days of meal history (minimum 14 logged days), scores food combinations by how well they close today's remaining macro gaps, and surfaces up to 3 ranked suggestions per meal slot (breakfast / lunch / dinner / snack).

#### Complete widget tree

| Class | Role |
|---|---|
| `_SmartInsightSheet` | Modal bottom sheet entry point (`showSmartInsightSheet()`). Reads `smartInsightProvider`. |
| `_CardDeck` | Slot selector + carousel shell. Holds `_slotIndex` state; rebuilds carousel with `ValueKey` on slot change. |
| `_SlotSelector` | Horizontal scrollable pill tabs (breakfast / lunch / dinner / snack). |
| `_OptionCarousel` / `_OptionCarouselState` | Spring-physics vertical stacked-card carousel. Swipe up → next option; swipe down → previous. |
| `_MealSlotCard` | Individual option card. Meal icon, "Option N" badge, 4× `_MacroDonut` in footer. Tap → opens `_MealDetailSheet`. |
| `_MealDetailSheet` / `_MealDetailSheetState` | Full detail bottom sheet. Food item list with per-item selection toggle, `_DonutImpactSection`, Log button. |
| `_DonutImpactSection` | Macro impact row using `_MacroDonut` at `size: 76`. Reacts live to item selection. |
| `_MacroDonut` / `_DonutPainter` | Donut ring showing current fill (muted arc) + projected addition (full-color arc). Parameterised by `size` (default 58 for carousel, 76 for detail sheet). Overshoot signalled by a soft red `BoxShadow` glow — macro color is never overridden. |
| `_MacroSummaryRow` | Compact macro total strip at the foot of the food list. Driven by selected items only. |
| `_EmptyState` | Shown when `loggedDays < 14` or all meals already logged today. |

#### Carousel mechanics (all working, no known bugs)

- `_ctrl` is an `AnimationController.unbounded()` — fractional page value (0 = card 0, 1 = card 1, 2 = card 2).
- `_dragRaw` accumulates raw (un-rubber-banded) drag position. Rubber-band (`×0.2`) is applied once at output, preventing fixed-point convergence that previously froze Option 3.
- `_topFor(i)` uses the clamped page: `rel ≤ 0 → rel * _cardHeight`, `rel > 0 → rel * _kPeekH`.
- Z-order: cards sorted furthest-from-page first (deepest), active card last (on top). Clamped page used throughout for consistency.
- `_cardHeight` floored at 80 dp to prevent zero/negative heights on small screens.
- Spring: `SpringDescription(mass:1, stiffness:600, damping:60)` — over-damped, no oscillation.

#### Detail sheet selection model

`_MealDetailSheetState` holds `Set<int> _selectedIndices` (all selected by default). The computed getter `_selectedMacros` sums `MacroValues` for selected items only via `MacroValues.sum()`. Both `_DonutImpactSection` and `_MacroSummaryRow` receive `_selectedMacros`, so donuts and totals update immediately on each tap. `_logAll()` iterates `_selectedIndices.toList()..sort()` — only selected items are sent to `entriesProvider`. The Log button is disabled when the selection is empty and shows "Log N items" for partial selections.

#### Overshoot indicator

When `current + addition > goal` for a macro, `_MacroDonut` keeps its attributed color and adds two `BoxShadow` layers (`AppColors.danger` at alpha 0.28/blurRadius 10 and alpha 0.10/blurRadius 20) on a `BoxShape.circle` container, producing a soft red glow. The painter arcs clamp at 100% fill. No class-wide color override occurs, so multiple overshooting donuts each carry an independent soft glow rather than all turning solid red.
