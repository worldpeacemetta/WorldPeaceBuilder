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
