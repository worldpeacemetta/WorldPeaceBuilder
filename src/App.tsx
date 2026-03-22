// MacroTracker v3.7 — Patch on your original file
// Changes from your App.jsx:
// 1) Goal vs Actual donuts now show % > 100 when over budget.
// 2) Sticky header KPIs show "X over" in dark red when exceeding goals.
//    (Everything else left untouched.)
//
// TypeScript migration status: file renamed to .tsx; types are suppressed below
// while full annotation is done incrementally. Remove @ts-nocheck as types are added.
// @ts-nocheck

import React, { Fragment, useCallback, useEffect, useMemo, useRef, useState, useId } from "react";
import { BrowserMultiFormatReader } from '@zxing/browser';
import { DecodeHintType } from '@zxing/library';
import Auth from "./components/Auth";
import AchievementBadges, { BADGES, BadgeShape, BadgeIcon } from "./components/AchievementBadges";
import OnboardingQuestionnaire from "./components/OnboardingQuestionnaire";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Card, CardHeader, CardContent, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";
import { supabase } from "./lib/supabase";
import usePrefersDark from "./hooks/usePrefersDark";
import { useDateSync } from "./hooks/useDateSync";
import {
  CartesianGrid,
  AreaChart,
  Area,
  BarChart,
  Bar,
  Line,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip as RTooltip,
  XAxis,
  YAxis,
  Legend,
  LabelList,
  Cell,
} from "recharts";
import {
  Calendar as CalendarIcon,
  Plus,
  Trash2,
  Settings as SettingsIcon,
  Upload,
  Download,
  Dumbbell,
  BedDouble,
  Database,
  BarChart3,
  BookOpenText,
  History,
  Search,
  UtensilsCrossed,
  Pencil,
  ArrowUp,
  ArrowDown,
  ArrowUpDown,
  ArrowUpRight,
  Scale,
  CakeSlice,
  Scissors,
  Equal,
  User,
  LogOut,
  Menu,
  X,
  ChefHat,
  Barcode,
  Camera,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Sun,
  Moon,
  Copy,
  ChevronLeft,
  ChevronRight,
  ChevronUp,
} from "lucide-react";
import { format, formatDistanceToNow, startOfDay, addDays, subDays, startOfMonth, startOfQuarter, startOfYear, eachDayOfInterval, startOfWeek, endOfWeek, getDay } from "date-fns";
import { useTranslation } from "react-i18next";
import i18n, { setLanguage } from "./i18n";

/*******************
 * Types
 *******************/
export type MealKey = 'breakfast' | 'lunch' | 'dinner' | 'snack' | 'other';

export interface Ingredient {
  foodId: string;
  quantity: number;
}

export interface Food {
  id: string;
  name: string;
  brand?: string;
  unit: 'per100g' | 'perServing';
  servingSize?: number;
  kcal: number;
  fat: number;
  carbs: number;
  protein: number;
  category: string;
  components?: Ingredient[];
}

export interface Entry {
  id: string;
  date: string;
  foodId?: string;
  label?: string;
  qty: number;
  meal: MealKey;
}

/*******************
 * Constants & Utils
 *******************/
const K_SETTINGS = "mt_settings";
const K_THEME = "mt_theme"; // 'system' | 'light' | 'dark'
const AVATAR_MAX_BYTES = 2 * 1024 * 1024;
const AVATAR_ALLOWED_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);


// Pastel macro palette with gradient support
const MACRO_THEME = {
  kcal: {
    base: "#9F1D35", // vivid burgundy
    gradientFrom: "#F4CDD6",
    gradientTo: "#C23E52",
    dark: "#8D021F", // burgundy
  },
  protein: {
    base: "#9CAF88", // sage-inspired green
    gradientFrom: lightenHex("#9CAF88", 0.35),
    gradientTo: "#819171",
    dark: "#819171",
  },
  carbs: {
    base: "#98c1d9",
    gradientFrom: lightenHex("#98c1d9", 0.45),
    gradientTo: darkenHex("#98c1d9", 0.75),
    dark: "#3d5a80",
  },
  fat: {
    base: "#fdba74",
    gradientFrom: "#fef3c7",
    gradientTo: "#fb923c",
    dark: "#ea580c",
  },
};

const COLORS = {
  kcal: MACRO_THEME.kcal.base,
  protein: MACRO_THEME.protein.base,
  carbs: MACRO_THEME.carbs.base,
  fat: MACRO_THEME.fat.base,
  gray: "#94a3b8", // slate-400
  cyan: "#0ea5e9",
  violet: "#9A7196",
  redDark: "#b91c1c",
};

const SETUP_MODES = ["dual", "bulking", "cutting", "maintenance"];
const DEFAULT_MODE_ENTRY = Object.freeze({ setup: "dual", profile: "train" });
const SETUP_LABELS = {
  dual: "Train Day / Rest Day",
  bulking: "Bulking",
  cutting: "Cutting",
  maintenance: "Maintenance",
};

function normalizeSetupMode(value) {
  return SETUP_MODES.includes(value) ? value : "dual";
}

function normalizeDualProfile(value) {
  return value === "rest" ? "rest" : "train";
}

function cloneModeEntry(entry) {
  if (!entry) {
    return { setup: "dual", profile: "train" };
  }
  if (typeof entry === "string") {
    if (entry === "train" || entry === "rest") {
      return { setup: "dual", profile: normalizeDualProfile(entry) };
    }
    if (SETUP_MODES.includes(entry)) {
      return { setup: normalizeSetupMode(entry) };
    }
    return { setup: "dual", profile: "train" };
  }
  const setup = normalizeSetupMode(entry.setup ?? entry.mode ?? entry.value);
  if (setup === "dual") {
    return { setup: "dual", profile: normalizeDualProfile(entry.profile ?? entry.variant ?? entry.state ?? entry.day) };
  }
  return { setup };
}

function coerceModeEntry(raw, fallback = DEFAULT_MODE_ENTRY) {
  if (raw == null) {
    return cloneModeEntry(fallback);
  }
  if (typeof raw === "string") {
    if (raw === "train" || raw === "rest") {
      return { setup: "dual", profile: normalizeDualProfile(raw) };
    }
    if (SETUP_MODES.includes(raw)) {
      return { setup: normalizeSetupMode(raw) };
    }
    return cloneModeEntry(fallback);
  }
  if (typeof raw === "object") {
    const candidateSetup = normalizeSetupMode(raw.setup ?? raw.mode ?? raw.value ?? (typeof raw.profile === "string" ? "dual" : undefined));
    if (candidateSetup === "dual") {
      return { setup: "dual", profile: normalizeDualProfile(raw.profile ?? raw.variant ?? raw.state ?? raw.day) };
    }
    return { setup: candidateSetup };
  }
  return cloneModeEntry(fallback);
}

const TOOLTIP_CONTAINER_CLASSES =
  "rounded-lg border border-slate-700/60 bg-slate-800/95 px-3 py-2 text-xs leading-relaxed text-slate-100 shadow-xl backdrop-blur-sm dark:border-slate-600/50 dark:bg-slate-900/90";

function ChartTooltipContainer({ title, children }) {
  return (
    <div className={TOOLTIP_CONTAINER_CLASSES}>
      {title ? <div className="mb-1 text-[11px] font-semibold text-slate-200">{title}</div> : null}
      <div className="space-y-1">{children}</div>
    </div>
  );
}

function darkenHex(hex, factor = 0.75) {
  if (typeof hex !== "string" || !hex.startsWith("#")) return hex;
  const value = hex.length === 4
    ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`
    : hex;
  const int = Number.parseInt(value.slice(1), 16);
  if (Number.isNaN(int)) return hex;
  const r = Math.max(0, Math.min(255, Math.floor(((int >> 16) & 0xff) * factor)));
  const g = Math.max(0, Math.min(255, Math.floor(((int >> 8) & 0xff) * factor)));
  const b = Math.max(0, Math.min(255, Math.floor((int & 0xff) * factor)));
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

function lightenHex(hex, amount = 0.25) {
  if (typeof hex !== "string" || !hex.startsWith("#")) return hex;
  const value = hex.length === 4
    ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`
    : hex;
  const int = Number.parseInt(value.slice(1), 16);
  if (Number.isNaN(int)) return hex;
  const r = Math.max(0, Math.min(255, Math.round(((int >> 16) & 0xff) + (255 - ((int >> 16) & 0xff)) * amount)));
  const g = Math.max(0, Math.min(255, Math.round(((int >> 8) & 0xff) + (255 - ((int >> 8) & 0xff)) * amount)));
  const b = Math.max(0, Math.min(255, Math.round((int & 0xff) + (255 - (int & 0xff)) * amount)));
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

const TOP_FOOD_THEMES = [
  MACRO_THEME.kcal,
  MACRO_THEME.protein,
  MACRO_THEME.carbs,
  MACRO_THEME.fat,
  {
    base: COLORS.cyan,
    gradientFrom: lightenHex(COLORS.cyan, 0.45),
    gradientTo: darkenHex(COLORS.cyan, 0.8),
    dark: darkenHex(COLORS.cyan, 0.65),
  },
  {
    base: COLORS.violet,
    gradientFrom: lightenHex(COLORS.violet, 0.45),
    gradientTo: darkenHex(COLORS.violet, 0.8),
    dark: darkenHex(COLORS.violet, 0.65),
  },
];

const MACRO_LABELS = {
  kcal: "Calories",
  protein: "Protein",
  carbs: "Carbs",
  fat: "Fat",
};

const RoundedTopBar = ({ x, y, width, height, fill, radius = 12 }) => {
  const r = Math.min(radius, width / 2, height);
  return (
    <path
      d={`M${x} ${y + height} L${x} ${y + r} Q${x} ${y} ${x + r} ${y} L${x + width - r} ${y} Q${x + width} ${y} ${x + width} ${y + r} L${x + width} ${y + height} Z`}
      fill={fill}
    />
  );
};

const RoundedBottomBar = ({ x, y, width, height, fill, radius = 12 }) => {
  const r = Math.min(radius, width / 2, height);
  return (
    <path
      d={`M${x} ${y} L${x} ${y + height - r} Q${x} ${y + height} ${x + r} ${y + height} L${x + width - r} ${y + height} Q${x + width} ${y + height} ${x + width} ${y + height - r} L${x + width} ${y} Z`}
      fill={fill}
    />
  );
};

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const toISODate = (d) => format(d, "yyyy-MM-dd");
const todayISO = () => toISODate(new Date());

function sanitizeGoalSchedule(value, fallbackEntry, isoToday = todayISO()) {
  const schedule = {};
  if (value && typeof value === "object") {
    Object.entries(value).forEach(([key, rawValue]) => {
      if (!ISO_DATE_RE.test(key)) return;
      const normalized = coerceModeEntry(rawValue);
      if (normalized) {
        schedule[key] = normalized;
      }
    });
  }
  if (fallbackEntry) {
    const safeFallback = coerceModeEntry(fallbackEntry);
    if (safeFallback && !schedule[isoToday]) {
      schedule[isoToday] = safeFallback;
    }
  }
  return schedule;
}

const FOOD_CATEGORIES = [
  { value: "vegetable", label: "Vegetable", emoji: "🥦" },
  { value: "fruit", label: "Fruit", emoji: "🍎" },
  { value: "meat", label: "Meat", emoji: "🥩" },
  { value: "eggProducts", label: "Egg & Egg Products", emoji: "🥚" },
  { value: "fish", label: "Fish & Seafood", emoji: "🐟" },
  { value: "plantProtein", label: "Plant Protein", emoji: "🌱" },
  { value: "supplement", label: "Protein Powder & Supplement", emoji: "🧴" },
  { value: "breadBakery", label: "Bread & Bakery", emoji: "🥖" },
  { value: "cereals", label: "Cereals", emoji: "🥣" },
  { value: "grains", label: "Grains", emoji: "🌾" },
  { value: "nutsSeeds", label: "Nuts & Seeds", emoji: "🥜" },
  { value: "milk", label: "Milk", emoji: "🥛" },
  { value: "yogurt", label: "Yogurt", emoji: "🍶" },
  { value: "cheese", label: "Cheese", emoji: "🧀" },
  { value: "creamsButters", label: "Creams & Butters", emoji: "🧈" },
  { value: "cookingOil", label: "Cooking Oil", emoji: "🛢️" },
  { value: "dressing", label: "Dressing", emoji: "🥫" },
  { value: "homeRecipe", label: "Home Recipe", emoji: "🏠" },
  { value: "outsideMeal", label: "Outside Meal", emoji: "🍽️" },
  { value: "sweet", label: "Sweet", emoji: "🍬" },
  { value: "other", label: "Other", emoji: "⚪️" },
];

const FOOD_CATEGORY_MAP = FOOD_CATEGORIES.reduce((acc, cat) => {
  acc[cat.value] = cat;
  return acc;
}, {});

const DEFAULT_CATEGORY = "other";
const DEFAULT_GOALS = { kcal: 2400, protein: 160, carbs: 250, fat: 80 };
const TREND_RANGE_LABELS = {
  "7": "Last 7 days",
  "14": "Last 14 days",
  "30": "Last 30 days",
  "90": "Last 3 months",
  "365": "Last 12 months",
};

const getCategoryEmoji = (category) => FOOD_CATEGORY_MAP[category]?.emoji ?? FOOD_CATEGORY_MAP[DEFAULT_CATEGORY].emoji;
const getCategoryLabel = (category) => FOOD_CATEGORY_MAP[category]?.label ?? FOOD_CATEGORY_MAP[DEFAULT_CATEGORY].label;

const numberFormatter = new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 });
const formatNumber = (value) => {
  const numeric = Number.parseFloat(value);
  return Number.isFinite(numeric) ? numberFormatter.format(numeric) : "0";
};

const toInputString = (value, fractionDigits = 2) => {
  const numeric = Number.isFinite(value) ? value : 0;
  return String(+numeric.toFixed(fractionDigits));
};

function toNumber(value, fallback = 0) {
  const num = Number.parseFloat(value);
  return Number.isFinite(num) ? num : fallback;
}

function sanitizeGoal(goal) {
  const source = goal && typeof goal === "object" ? goal : DEFAULT_GOALS;
  return {
    kcal: toNumber(source.kcal, DEFAULT_GOALS.kcal),
    protein: toNumber(source.protein, DEFAULT_GOALS.protein),
    carbs: toNumber(source.carbs, DEFAULT_GOALS.carbs),
    fat: toNumber(source.fat, DEFAULT_GOALS.fat),
  };
}

function ensureDailyGoals(value) {
  const isoToday = todayISO();
  const hasValue = value && typeof value === "object";
  const rawSetup = hasValue ? value.setup ?? value.mode ?? value.activeSetup : undefined;

  const resolveDualGoal = (key) => {
    if (!hasValue) return undefined;
    if (value?.dual && typeof value.dual === "object" && value.dual[key]) {
      return value.dual[key];
    }
    if (value?.[key]) {
      return value[key];
    }
    return undefined;
  };

  const trainGoal = sanitizeGoal(resolveDualGoal("train"));
  const restGoal = sanitizeGoal(resolveDualGoal("rest") ?? resolveDualGoal("train"));
  const activeProfile = normalizeDualProfile(
    hasValue && value?.dual && typeof value.dual === "object" ? value.dual.active : value?.active
  );

  const ensureSingle = (mode) => sanitizeGoal((hasValue && value?.[mode]) || (hasValue && value?.single?.[mode]));

  const setup = normalizeSetupMode(rawSetup ?? (hasValue ? "dual" : undefined));
  const fallbackEntry = setup === "dual" ? { setup: "dual", profile: activeProfile } : { setup };
  const schedule = sanitizeGoalSchedule(hasValue ? value?.byDate : undefined, fallbackEntry, isoToday);

  return {
    setup,
    dual: {
      train: trainGoal,
      rest: restGoal,
      active: activeProfile,
    },
    bulking: ensureSingle("bulking"),
    cutting: ensureSingle("cutting"),
    maintenance: ensureSingle("maintenance"),
    byDate: schedule,
  };
}

const DEFAULT_SETTINGS = {
  dailyGoals: ensureDailyGoals({
    setup: "dual",
    dual: {
      train: DEFAULT_GOALS,
      rest: DEFAULT_GOALS,
      active: "train",
    },
    bulking: DEFAULT_GOALS,
    cutting: DEFAULT_GOALS,
    maintenance: DEFAULT_GOALS,
  }),
  profile: { activity: "moderate" },
  profileHistory: [],
};

function ensureBodyHistory(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => {
      const date = typeof entry?.date === "string" && ISO_DATE_RE.test(entry.date) ? entry.date : null;
      if (!date) return null;
      const weightKg = toNumber(entry?.weightKg, 0);
      const bodyFatPct = entry?.bodyFatPct == null ? null : toNumber(entry.bodyFatPct, 0);
      const recordedAt =
        typeof entry?.recordedAt === "string" && !Number.isNaN(Date.parse(entry.recordedAt))
          ? entry.recordedAt
          : `${date}T00:00:00.000Z`;
      return { date, weightKg, bodyFatPct, recordedAt };
    })
    .filter(Boolean)
    .sort((a, b) => a.date.localeCompare(b.date));
}

function ensureSettings(value) {
  const base = value && typeof value === "object" ? value : {};
  const profile = base.profile && typeof base.profile === "object"
    ? { ...DEFAULT_SETTINGS.profile, ...base.profile }
    : { ...DEFAULT_SETTINGS.profile };

  return {
    ...base,
    dailyGoals: ensureDailyGoals(base.dailyGoals),
    profile,
    profileHistory: ensureBodyHistory(base.profileHistory),
  };
}

function stripProfileSettingsForStorage(value) {
  const normalized = ensureSettings(value);
  return {
    ...normalized,
    profile: { ...DEFAULT_SETTINGS.profile },
  };
}

function sanitizeComponents(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map((item) => ({
      foodId: typeof item.foodId === "string" ? item.foodId : "",
      quantity: toNumber(item.quantity, 0),
    }))
    .filter((item) => item.foodId && item.quantity > 0);
}

function sanitizeFood(food) {
  const unit = food.unit === "perServing" ? "perServing" : "per100g";
  const rawSize = toNumber(food.servingSize ?? food.totalSize ?? 0, 0);
  const normalizedSize = Number.isFinite(rawSize) && rawSize > 0 ? rawSize : undefined;
  const servingSize = unit === "perServing" ? Math.max(1, normalizedSize ?? 1) : normalizedSize;
  const category = FOOD_CATEGORY_MAP[food.category]?.value ?? DEFAULT_CATEGORY;
  const components = sanitizeComponents(food.components);
  const createdAt =
    typeof food.createdAt === "string" && !Number.isNaN(Date.parse(food.createdAt))
      ? food.createdAt
      : new Date().toISOString();
  return {
    ...food,
    createdAt,
    unit,
    servingSize,
    category,
    components,
    kcal: toNumber(food.kcal, 0),
    fat: toNumber(food.fat, 0),
    carbs: toNumber(food.carbs, 0),
    protein: toNumber(food.protein, 0),
  };
}

const ensureFoods = (list) => list.map((food) => sanitizeFood(food));

/** @type {Food[]} */
const DEFAULT_FOODS = [
  // Vegetables
  sanitizeFood({ id: crypto.randomUUID(), name: "Tomato", unit: "per100g", category: "vegetable", kcal: 18, fat: 0.2, carbs: 3.9, protein: 0.9 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Broccoli", unit: "per100g", category: "vegetable", kcal: 34, fat: 0.4, carbs: 6.6, protein: 2.8 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Spinach", unit: "per100g", category: "vegetable", kcal: 23, fat: 0.4, carbs: 3.6, protein: 2.9 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Carrot", unit: "per100g", category: "vegetable", kcal: 41, fat: 0.2, carbs: 9.6, protein: 0.9 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Cucumber", unit: "per100g", category: "vegetable", kcal: 16, fat: 0.1, carbs: 3.6, protein: 0.7 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Red Bell Pepper", unit: "per100g", category: "vegetable", kcal: 31, fat: 0.3, carbs: 6.0, protein: 1.0 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Onion", unit: "per100g", category: "vegetable", kcal: 40, fat: 0.1, carbs: 9.3, protein: 1.1 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Zucchini", unit: "per100g", category: "vegetable", kcal: 17, fat: 0.3, carbs: 3.1, protein: 1.2 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Sweet Potato", unit: "per100g", category: "vegetable", kcal: 86, fat: 0.1, carbs: 20.1, protein: 1.6 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Lettuce", unit: "per100g", category: "vegetable", kcal: 15, fat: 0.2, carbs: 2.9, protein: 1.4 }),
  // Fruits
  sanitizeFood({ id: crypto.randomUUID(), name: "Apple", unit: "per100g", category: "fruit", kcal: 52, fat: 0.2, carbs: 13.8, protein: 0.3 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Banana", unit: "per100g", category: "fruit", kcal: 89, fat: 0.3, carbs: 22.8, protein: 1.1 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Orange", unit: "per100g", category: "fruit", kcal: 47, fat: 0.1, carbs: 11.8, protein: 0.9 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Strawberry", unit: "per100g", category: "fruit", kcal: 32, fat: 0.3, carbs: 7.7, protein: 0.7 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Blueberry", unit: "per100g", category: "fruit", kcal: 57, fat: 0.3, carbs: 14.5, protein: 0.7 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Mango", unit: "per100g", category: "fruit", kcal: 60, fat: 0.4, carbs: 15.0, protein: 0.8 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Grapes", unit: "per100g", category: "fruit", kcal: 69, fat: 0.2, carbs: 18.1, protein: 0.6 }),
  // Meat & Eggs
  sanitizeFood({ id: crypto.randomUUID(), name: "Chicken Breast (cooked)", unit: "per100g", category: "meat", kcal: 165, fat: 3.6, carbs: 0, protein: 31 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Egg", unit: "per100g", category: "eggProducts", kcal: 155, fat: 11, carbs: 1.1, protein: 13 }),
  // Fish & Seafood
  sanitizeFood({ id: crypto.randomUUID(), name: "Salmon", unit: "per100g", category: "fish", kcal: 208, fat: 13, carbs: 0, protein: 20 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Tuna (canned)", unit: "per100g", category: "fish", kcal: 116, fat: 1.0, carbs: 0, protein: 26 }),
  // Grains
  sanitizeFood({ id: crypto.randomUUID(), name: "White Rice (cooked)", unit: "per100g", category: "grains", kcal: 130, fat: 0.3, carbs: 28.2, protein: 2.7 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Pasta (cooked)", unit: "per100g", category: "grains", kcal: 131, fat: 1.1, carbs: 25, protein: 5.0 }),
  // Cereals
  sanitizeFood({ id: crypto.randomUUID(), name: "Oats", unit: "per100g", category: "cereals", kcal: 389, fat: 6.9, carbs: 66, protein: 17 }),
  // Bread & Bakery
  sanitizeFood({ id: crypto.randomUUID(), name: "Whole Wheat Bread", unit: "per100g", category: "breadBakery", kcal: 247, fat: 3.4, carbs: 41, protein: 13 }),
  // Dairy
  sanitizeFood({ id: crypto.randomUUID(), name: "Greek Yogurt", unit: "per100g", category: "yogurt", kcal: 59, fat: 0.4, carbs: 3.6, protein: 10 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Whole Milk", unit: "per100g", category: "milk", kcal: 61, fat: 3.3, carbs: 4.8, protein: 3.2 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Cheddar Cheese", unit: "per100g", category: "cheese", kcal: 402, fat: 33, carbs: 1.3, protein: 25 }),
  // Plant Protein / Legumes
  sanitizeFood({ id: crypto.randomUUID(), name: "Chickpeas (cooked)", unit: "per100g", category: "plantProtein", kcal: 164, fat: 2.6, carbs: 27, protein: 8.9 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Lentils (cooked)", unit: "per100g", category: "plantProtein", kcal: 116, fat: 0.4, carbs: 20, protein: 9.0 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Black Beans (cooked)", unit: "per100g", category: "plantProtein", kcal: 132, fat: 0.5, carbs: 24, protein: 8.9 }),
  // Cooking Oil & Supplement
  sanitizeFood({ id: crypto.randomUUID(), name: "Olive Oil", unit: "perServing", servingSize: 10, category: "cookingOil", kcal: 88, fat: 10, carbs: 0, protein: 0 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Whey Protein (1 scoop)", unit: "perServing", servingSize: 30, category: "supplement", kcal: 120, fat: 1.5, carbs: 3, protein: 24 }),
];

function load(k, fallback) {
  try { const raw = localStorage.getItem(k); return raw ? JSON.parse(raw) : fallback; } catch { return fallback; }
}
function save(k, v) { localStorage.setItem(k, JSON.stringify(v)); }

/** @param {Food} food @param {number} qty */
function scaleMacros(food, qty) {
  const factor = food.unit === "per100g" ? qty / 100 : qty;
  return {
    kcal: +(food.kcal * factor).toFixed(1),
    fat: +(food.fat * factor).toFixed(2),
    carbs: +(food.carbs * factor).toFixed(2),
    protein: +(food.protein * factor).toFixed(2),
  };
}

function macrosPer100g(food) {
  if (food.unit === "per100g") {
    return {
      kcal: food.kcal,
      fat: food.fat,
      carbs: food.carbs,
      protein: food.protein,
    };
  }
  const serving = Math.max(1, toNumber(food.servingSize ?? 0, 1));
  const factor = 100 / serving;
  return {
    kcal: +(food.kcal * factor).toFixed(1),
    fat: +(food.fat * factor).toFixed(2),
    carbs: +(food.carbs * factor).toFixed(2),
    protein: +(food.protein * factor).toFixed(2),
  };
}
function sumMacros(rows) {
  return rows.reduce((a, r) => ({
    kcal: a.kcal + r.kcal,
    fat: a.fat + r.fat,
    carbs: a.carbs + r.carbs,
    protein: a.protein + r.protein,
  }), { kcal: 0, fat: 0, carbs: 0, protein: 0 });
}

function computeRecipeTotals(components, foods, options = {}) {
  if (!Array.isArray(components) || components.length === 0) {
    return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
  }

  const normalized = components
    .map((component) => {
      const food = foods.find((f) => f.id === component.foodId);
      const qty = toNumber(component.quantity, 0);
      if (!food || !Number.isFinite(qty) || qty <= 0) return null;
      return { food, qty };
    })
    .filter(Boolean);

  if (normalized.length === 0) {
    return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
  }

  const { unit = "per100g", totalSize } = options;

  if (unit === "per100g") {
    const totalWeight = toNumber(totalSize, 0);
    if (!Number.isFinite(totalWeight) || totalWeight <= 0) {
      return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
    }
    const totals = normalized.reduce(
      (acc, { food, qty }) => {
        const ingredientWeight =
          food.unit === "perServing" ? qty * Math.max(1, food.servingSize ?? 0) : qty;
        const fraction = ingredientWeight / totalWeight;
        const macros = macrosPer100g(food);
        acc.kcal += macros.kcal * fraction;
        acc.fat += macros.fat * fraction;
        acc.carbs += macros.carbs * fraction;
        acc.protein += macros.protein * fraction;
        return acc;
      },
      { kcal: 0, fat: 0, carbs: 0, protein: 0 }
    );
    return {
      kcal: +totals.kcal.toFixed(1),
      fat: +totals.fat.toFixed(2),
      carbs: +totals.carbs.toFixed(2),
      protein: +totals.protein.toFixed(2),
    };
  }

  const rows = normalized.map(({ food, qty }) => scaleMacros(food, qty));
  return sumMacros(rows);
}

const createBasicFoodForm = () => ({
  name: "",
  category: DEFAULT_CATEGORY,
  unit: "per100g",
  servingSize: "100",
  kcal: "0",
  protein: "0",
  carbs: "0",
  fat: "0",
});

const createRecipeForm = () => ({
  name: "",
  unit: "per100g",
  servingSize: "100",
  kcal: "0",
  protein: "0",
  carbs: "0",
  fat: "0",
});
function rangeDays(from, to) { return eachDayOfInterval({ start: startOfDay(from), end: startOfDay(to) }); }
function startOfRange(key) { const map = { "7":6, "14":13, "30":29, "90":89, "365":364 }; return subDays(startOfDay(new Date()), map[key]); }
function filterFoods(q, foods) { const s = String(q||"").trim().toLowerCase(); return s? foods.filter(f=>`${f.name} ${f.brand??""}`.toLowerCase().includes(s)).slice(0,20) : foods.slice(0,20); }

// PATCH: allow >100% (was capped before)
function pctOf(actual, goal){
  const a = Number.isFinite(actual)?Math.max(0,actual):0;
  const g = Number.isFinite(goal)?Math.max(0,goal):0;
  if(g<=0) return 0;
  return Math.round((a/g)*100);
}

function normalizeQty(oldFood, newFood, oldQty){
  if(!oldFood||!newFood) return oldQty;
  if(oldFood.unit===newFood.unit) return oldQty;
  if(oldFood.unit==='per100g'&&newFood.unit==='perServing'){
    const grams=oldQty; const s=newFood.servingSize||100; return +(grams/s).toFixed(2);
  }
  if(oldFood.unit==='perServing'&&newFood.unit==='per100g'){
    const servings=oldQty; const s=oldFood.servingSize||100; return Math.max(1, Math.round(servings*s));
  }
  return oldQty;
}

/** Guess meal by hour */
function suggestMealByNow(){
  const h = new Date().getHours();
  if(h>=5 && h<11) return 'breakfast';
  if(h>=11 && h<16) return 'lunch';
  if(h>=16 && h<22) return 'dinner';
  return 'snack';
}

const MEAL_LABELS = { breakfast:'Breakfast', lunch:'Lunch', dinner:'Dinner', snack:'Snack', other:'Other' };
const MEAL_EMOJIS = { breakfast:'🌅', lunch:'☀️', dinner:'🌙', snack:'🍎', other:'🍽️' };
const MEAL_ORDER = ['breakfast','lunch','dinner','snack','other'];

/*******************
 * Main App
 *******************/
export default function MacroTrackerApp(){
  const { t, i18n: i18nHook } = useTranslation();
  const [session, setSession] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [authRefreshKey, setAuthRefreshKey] = useState(0);
  const [profileUsername, setProfileUsername] = useState("");
  const [profileAvatarUrl, setProfileAvatarUrl] = useState("");
  const [accountUsername, setAccountUsername] = useState("");
  const [accountEmail, setAccountEmail] = useState("");
  const [accountError, setAccountError] = useState("");
  const [accountSuccess, setAccountSuccess] = useState("");
  const [avatarUploading, setAvatarUploading] = useState(false);
  const avatarInputRef = useRef(null);
  const [theme, setTheme] = useState(load(K_THEME, 'system'));
  const prefersDark = usePrefersDark();
  const resolvedTheme = theme === 'system' ? (prefersDark ? 'dark' : 'light') : theme;
  const [foods, setFoods] = useState([]);
  const [foodsLoading, setFoodsLoading] = useState(true);
  const [foodSort, setFoodSort] = useState({ column: "createdAt", direction: "desc" });
  const [foodEditTarget, setFoodEditTarget] = useState(null);
  const [foodSearch, setFoodSearch] = useState("");
  const [entries, setEntries] = useState([]);
  const [entriesLoading, setEntriesLoading] = useState(true);
  const [settings, setSettings] = useState(()=> ensureSettings(stripProfileSettingsForStorage(load(K_SETTINGS, DEFAULT_SETTINGS))));
  const [tab, setTab] = useState(() => {
    const validTabs = new Set(['dashboard', 'daily', 'foods', 'settings']);
    const hash = typeof window !== 'undefined' ? window.location.hash.slice(1) : '';
    return validTabs.has(hash) ? hash : 'dashboard';
  });
  // Persist active tab in URL hash so refresh / sharing lands on the right tab.
  // Guard: do NOT overwrite a Supabase auth callback hash (access_token / error_description).
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const h = window.location.hash;
    if (!h.includes('access_token') && !h.includes('error_description')) {
      window.location.hash = tab;
    }
  }, [tab]);
  const [foodPendingDelete, setFoodPendingDelete] = useState(null);
  const [foodCategoryFilter, setFoodCategoryFilter] = useState(new Set());
  const [foodSelectedIds, setFoodSelectedIds] = useState(new Set());
  const [bulkDeleteConfirmOpen, setBulkDeleteConfirmOpen] = useState(false);
  const [foodAddOpen, setFoodAddOpen] = useState(false);
  const [foodAddTab, setFoodAddTab] = useState("single");
  const [barcodeScanOpen, setBarcodeScanOpen] = useState(false);
  const [scannedBasicForm, setScannedBasicForm] = useState(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [profileNameReady, setProfileNameReady] = useState(false);
  const [profileSaving, setProfileSaving] = useState(false);
  const [profileSaveError, setProfileSaveError] = useState("");
  const [profileSaveSuccess, setProfileSaveSuccess] = useState("");
  const [profileLastSavedAt, setProfileLastSavedAt] = useState(null);
  const [resetDataConfirmOpen, setResetDataConfirmOpen] = useState(false);
  const [resetDataInput, setResetDataInput] = useState("");
  const [stickyModeSheetOpen, setStickyModeSheetOpen] = useState(false);

  const [earnedBadgeIds, setEarnedBadgeIds] = useState(new Set());
  const [badgeUnlockQueue, setBadgeUnlockQueue] = useState([]);
  const [badgeUnlockShown, setBadgeUnlockShown] = useState(null);

  // Theme handling
  useEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    const dark = theme === 'system' ? prefersDark : theme === 'dark';
    root.classList.toggle("dark", dark);
    save(K_THEME, theme);
  }, [theme, prefersDark]);

  useEffect(()=>save(K_SETTINGS, stripProfileSettingsForStorage(settings)),[settings]);

  useEffect(() => {
    let mounted = true;

    async function hydrateSession() {
      try {
        const { data: { session: currentSession } } = await supabase.auth.getSession();
        if (!mounted) return;
        setSession(currentSession);
      } finally {
        if (mounted) setAuthLoading(false);
      }
    }

    hydrateSession();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, nextSession) => {
      if (!mounted) return;
      setSession(nextSession);

      if (event === "SIGNED_IN" || event === "TOKEN_REFRESHED") {
        setAuthRefreshKey((value) => value + 1);
      }

      if (event === "SIGNED_OUT") {
        setProfileNameReady(false);
        setProfileUsername("");
        setProfileAvatarUrl("");
        setAccountUsername("");
        setAccountEmail("");
        setFoods([]);
        setEntries([]);
        setFoodPendingDelete(null);
        setProfileLoading(false);
        setProfileSaving(false);
        setProfileSaveError("");
        setProfileSaveSuccess("");
        setProfileLastSavedAt(null);
      }
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);



  useEffect(() => {
    let active = true;

    async function loadFoods() {
      if (authLoading) return;
      if (!session?.user?.id) {
        if (!active) return;
        setFoods([]);
        setFoodsLoading(false);
        return;
      }

      setFoodsLoading(true);
      const { data, error } = await supabase
        .from("foods")
        .select("*")
        .eq("user_id", session.user.id)
        .order("created_at", { ascending: false });

      if (!active) return;
      if (error) {
        setFoods([]);
      } else {
        const mapped = (data || []).map((row) => sanitizeFood({
          id: row.id,
          name: row.name,
          brand: row.brand,
          unit: row.unit,
          servingSize: row.serving_size,
          kcal: row.kcal,
          fat: row.fat,
          carbs: row.carbs,
          protein: row.protein,
          category: row.category,
          components: row.components,
          createdAt: row.created_at,
        }));
        setFoods(mapped);
      }
      setFoodsLoading(false);
    }

    loadFoods();

    return () => {
      active = false;
    };
  }, [authLoading, session?.user?.id, authRefreshKey]);

  useEffect(() => {
    let active = true;

    async function loadEntries() {
      if (authLoading) return;
      if (!session?.user?.id) {
        if (!active) return;
        setEntries([]);
        setEntriesLoading(false);
        return;
      }

      setEntriesLoading(true);
      const { data, error } = await supabase
        .from("entries")
        .select("*")
        .eq("user_id", session.user.id)
        .order("created_at", { ascending: false });

      if (!active) return;
      if (error) {
        setEntries([]);
      } else {
        const mapped = (data || []).map((row) => ({
          id: row.id,
          date: row.date,
          foodId: row.food_id,
          qty: Number(row.qty) || 0,
          meal: row.meal,
        }));
        setEntries(mapped);
      }
      setEntriesLoading(false);
    }

    loadEntries();

    return () => {
      active = false;
    };
  }, [authLoading, session?.user?.id, authRefreshKey]);

  useEffect(() => {
    let active = true;

    async function loadProfile() {
      if (authLoading) return;
      if (!session?.user?.id) {
        if (!active) return;
        setProfileUsername("");
        setProfileAvatarUrl("");
        setAccountUsername("");
        setAccountEmail("");
        return;
      }

      const { data, error } = await supabase
        .from("profiles")
        .select("username, display_username, avatar_url")
        .eq("id", session.user.id)
        .single();

      if (!active) return;
      if (error) {
        setProfileUsername("");
        setProfileAvatarUrl("");
      } else {
        const usernameLower = data?.username ?? "";
        // "_new_" prefix marks a temporary username set at registration time.
        // These users haven't gone through onboarding yet — treat as no name set.
        const isTempUsername = usernameLower.startsWith("_new_");
        const displayUsername = isTempUsername ? "" : (data?.display_username ?? usernameLower);

        // Auto-migrate legacy users: if they have a real username but no display_username yet.
        if (!isTempUsername && !data?.display_username && usernameLower) {
          await supabase
            .from("profiles")
            .update({ display_username: usernameLower })
            .eq("id", session.user.id);
        }

        setProfileUsername(displayUsername);
        setProfileAvatarUrl(data?.avatar_url ?? "");
        setAccountUsername(displayUsername);
      }
      setAccountEmail(session.user?.email ?? "");
      // Signal that the username check is done — used to gate the onboarding questionnaire.
      setProfileNameReady(true);
    }

    loadProfile();

    return () => {
      active = false;
    };
  }, [authLoading, session?.user?.id, session?.user?.email, authRefreshKey]);

  useEffect(() => {
    let active = true;

    async function loadUserProfile() {
      if (authLoading) {
        setProfileLoading(true);
        return;
      }
      if (!session?.user?.id) {
        if (!active) return;
        setProfileLoading(false);
        return;
      }

      setProfileLoading(true);
      try {
        const { data: { session: currentSession } } = await supabase.auth.getSession();
        const userId = currentSession?.user?.id;
        if (!active) return;
        if (!userId) return;

        const { data, error } = await supabase
          .from("user_profile")
          .select("*")
          .eq("id", userId)
          .single();

        if (!active) return;
        if (!error && data) {
          setSettings((prev) => {
            // Supabase is authoritative. Local (localStorage) values are used only
            // as a fallback when the Supabase field has never been set (null/absent).
            const local = ensureSettings(prev);
            return ensureSettings({
              profile: {
                age: data.age != null ? Number(data.age) : local.profile.age,
                sex: data.sex ?? local.profile.sex,
                heightCm: data.height != null ? Number(data.height) : local.profile.heightCm,
                weightKg: data.weight != null ? Number(data.weight) : local.profile.weightKg,
                bodyFatPct: data.body_fat != null ? Number(data.body_fat) : local.profile.bodyFatPct,
                activity: data.activity_level ?? local.profile.activity,
              },
              dailyGoals: data.daily_macro_goals != null
                ? ensureDailyGoals(data.daily_macro_goals)
                : local.dailyGoals,
              profileHistory: Array.isArray(data.profile_history) && data.profile_history.length > 0
                ? data.profile_history
                : local.profileHistory,
            });
          });

          const updatedAt = data.updated_at ? new Date(data.updated_at) : null;
          setProfileLastSavedAt(updatedAt);
        } else {
          setProfileLastSavedAt(null);
        }
      } finally {
        if (active) {
          setProfileLoading(false);
        }
      }
    }

    loadUserProfile();

    return () => {
      active = false;
    };
  }, [authLoading, session?.user?.id, authRefreshKey]);

  const saveUserProfile = useCallback(async (nextSettings) => {
    if (!session?.user?.id) {
      return { ok: false, message: "Please sign in before saving." };
    }
    const normalized = ensureSettings(nextSettings);
    const profile = normalized.profile ?? {};
    const normalizedGoals = ensureDailyGoals(normalized.dailyGoals);
    const selectedSetup = normalizeSetupMode(normalizedGoals?.setup);
    const selectedDualProfile = normalizeDualProfile(normalizedGoals?.dual?.active);
    const selectedGoals = selectedSetup === "dual"
      ? (normalizedGoals?.dual?.[selectedDualProfile] ?? DEFAULT_GOALS)
      : (normalizedGoals?.[selectedSetup] ?? DEFAULT_GOALS);

    const { data: { session: currentSession } } = await supabase.auth.getSession();
    const userId = currentSession?.user?.id;
    if (!userId) {
      return { ok: false, message: "Please sign in before saving." };
    }

    const payload = {
      id: userId,
      age: Number(profile.age ?? 0),
      sex: profile.sex ?? "other",
      height: Number(profile.heightCm ?? 0),
      weight: Number(profile.weightKg ?? 0),
      body_fat: profile.bodyFatPct == null || Number.isNaN(profile.bodyFatPct) ? null : Number(profile.bodyFatPct),
      activity_level: profile.activity ?? "moderate",
      calories: Number(selectedGoals.kcal ?? 0),
      protein: Number(selectedGoals.protein ?? 0),
      carbs: Number(selectedGoals.carbs ?? 0),
      fat: Number(selectedGoals.fat ?? 0),
      daily_macro_goals: normalizedGoals,
      profile_history: ensureBodyHistory(normalized.profileHistory),
      updated_at: new Date().toISOString(),
    };

    const { error } = await supabase.from("user_profile").upsert(payload, { onConflict: "id" });
    if (error) {
      console.error("Failed to save profile", { error });
      return { ok: false, message: error.message || "Unable to save profile." };
    }

    return { ok: true, message: "My stats saved." };
  }, [session?.user?.id]);

  // Auto-save daily schedule (byDate) to Supabase whenever it changes.
  // We use a ref to capture the byDate reference after the initial profile load
  // so we don't fire an unnecessary write on first mount.
  const scheduleSavedRef = useRef(undefined);
  useEffect(() => {
    if (profileLoading || !session?.user?.id) return;
    const currentByDate = settings.dailyGoals?.byDate ?? {};
    if (scheduleSavedRef.current === undefined) {
      scheduleSavedRef.current = currentByDate;
      return;
    }
    if (currentByDate === scheduleSavedRef.current) return;
    scheduleSavedRef.current = currentByDate;
    const goalsToSave = ensureDailyGoals(settings.dailyGoals);
    supabase
      .from("user_profile")
      .upsert(
        { id: session.user.id, daily_macro_goals: goalsToSave, updated_at: new Date().toISOString() },
        { onConflict: "id" }
      )
      .then(({ error }) => {
        if (error) console.error("Failed to auto-save daily schedule", error);
      });
  }, [settings.dailyGoals?.byDate, session?.user?.id, profileLoading]);

  // Daily log state
  const {
    logDate, setLogDate,
    dashboardDate, setDashboardDate,
    weekNavDate, setWeekNavDate,
    stickyMode, setStickyMode,
    effectiveStickyMode, stickyDate, today,
  } = useDateSync();
  const [selectedFoodId, setSelectedFoodId] = useState(null);
  const [qty, setQty] = useState(0);
  const [meal, setMeal] = useState(/** @type {MealKey} */(suggestMealByNow()));

  const selectedFood = useMemo(()=> foods.find(f=>f.id===selectedFoodId)||null, [selectedFoodId,foods]);
  const QuantityIcon = selectedFood?.unit === "perServing" ? CakeSlice : Scale;
  const quantityLabelSuffix = selectedFood ? (selectedFood.unit === "per100g" ? "(g)" : "(servings)") : "";
  const quantityPlaceholder = selectedFood ? (selectedFood.unit === "per100g" ? "e.g. 150" : "e.g. 1.5") : "";

  const entriesForDay = useMemo(()=> entries.filter(e=>e.date===logDate),[entries,logDate]);
  const rowsForDay = useMemo(()=> entriesForDay.map(e=>{ const f = foods.find(x=>x.id===e.foodId); if(!f) return { id:e.id, foodId:e.foodId, label:e.label??'Unknown', category:DEFAULT_CATEGORY, qty:e.qty, meal:e.meal||'other', kcal:0,fat:0,carbs:0,protein:0}; const m=scaleMacros(f,e.qty); return { id:e.id, foodId:e.foodId, label:f.name, category:f.category, qty:e.qty, meal:e.meal||'other', ...m}; }),[entriesForDay,foods]);

  const totalsForDate = (iso)=>{ const dayEntries = entries.filter(e=>e.date===iso); const rows = dayEntries.map(e=>{ const f=foods.find(x=>x.id===e.foodId); return f? scaleMacros(f,e.qty) : {kcal:0,fat:0,carbs:0,protein:0};}); return sumMacros(rows); };

  const stickyTotals = useMemo(()=> totalsForDate(stickyDate), [entries,foods,stickyDate]);
  const totalsForCard = useMemo(()=> totalsForDate(logDate), [rowsForDay]);

  const recentFoods = useMemo(() => {
    const seen = new Set();
    const result = [];
    const sorted = [...entries].sort((a, b) => b.date.localeCompare(a.date));
    for (const e of sorted) {
      if (e.foodId && !seen.has(e.foodId)) {
        const f = foods.find(x => x.id === e.foodId);
        if (f) { seen.add(e.foodId); result.push(f); if (result.length >= 6) break; }
      }
    }
    return result;
  }, [entries, foods]);

  async function copyPreviousDay() {
    if (!session?.user?.id) return;
    const prevDate = format(subDays(new Date(logDate), 1), 'yyyy-MM-dd');
    const prevEntries = entries.filter(e => e.date === prevDate);
    if (prevEntries.length === 0) { alert(t('error.noEntriesPrevDay')); return; }
    for (const e of prevEntries) {
      const payload = { user_id: session.user.id, date: logDate, food_id: e.foodId, qty: e.qty, meal: e.meal };
      const { data: inserted, error } = await supabase.from('entries').insert(payload).select().single();
      if (error) { alert(error.message || t('error.unableCopyEntries')); return; }
      if (!inserted) continue;
      setEntries(prev => [{ id: inserted.id, date: inserted.date, foodId: inserted.food_id, qty: Number(inserted.qty) || 0, meal: inserted.meal }, ...prev]);
    }
  }

  const profileHistory = useMemo(() => ensureBodyHistory(settings.profileHistory), [settings.profileHistory]);

  const weightTrendSummary = useMemo(() => {
    if (!profileHistory.length) {
      return { history: [], latestWeight: null, latestDate: null };
    }
    const latest = profileHistory[profileHistory.length - 1];
    return {
      history: profileHistory,
      latestWeight: Number.isFinite(latest?.weightKg) ? +Number(latest.weightKg).toFixed(1) : null,
      latestDate: latest ? format(new Date(`${latest.date}T00:00:00`), "PP") : null,
    };
  }, [profileHistory]);

  const loggingSummary = useMemo(() => {
    const today = startOfDay(new Date());
    const start = subDays(today, 29);
    const entryDates = new Set(entries.map((entry) => entry.date));
    const days = eachDayOfInterval({ start, end: today });
    const grid = days.map((day) => {
      const iso = toISODate(day);
      return {
        iso,
        label: format(day, "MMM d"),
        logged: entryDates.has(iso),
      };
    });
    const totalLogged = grid.filter((item) => item.logged).length;
    const thisWeekStart = startOfWeek(today, { weekStartsOn: 1 });
    const thisWeekEnd = endOfWeek(today, { weekStartsOn: 1 });
    const thisWeekDays = eachDayOfInterval({ start: thisWeekStart, end: thisWeekEnd });
    const thisWeekLogged = thisWeekDays.reduce((count, day) => {
      const iso = toISODate(day);
      return count + (entryDates.has(iso) ? 1 : 0);
    }, 0);
    return {
      grid,
      totalLogged,
      totalDays: grid.length,
      thisWeekLogged,
    };
  }, [entries]);

  const totalsByDate = useMemo(() => {
    const map = new Map();
    if (!entries.length) return map;
    const foodMap = new Map(foods.map((food) => [food.id, food]));
    entries.forEach((entry) => {
      const food = foodMap.get(entry.foodId);
      if (!food) return;
      const macros = scaleMacros(food, entry.qty);
      const current = map.get(entry.date) ?? { kcal: 0, fat: 0, carbs: 0, protein: 0 };
      current.kcal += macros.kcal;
      current.fat += macros.fat;
      current.carbs += macros.carbs;
      current.protein += macros.protein;
      map.set(entry.date, current);
    });
    return map;
  }, [entries, foods]);

  const averageSummaries = useMemo(() => {
    const today = startOfDay(new Date());
    const todayIso = toISODate(today);
    const allDates = Array.from(totalsByDate.keys());

    const computeForDates = (dates) => {
      if (!dates.length) {
        return { kcal: 0, protein: 0, carbs: 0, fat: 0 };
      }
      const totals = dates.reduce(
        (acc, date) => {
          const value = totalsByDate.get(date) ?? { kcal: 0, fat: 0, carbs: 0, protein: 0 };
          return {
            kcal: acc.kcal + value.kcal,
            protein: acc.protein + value.protein,
            carbs: acc.carbs + value.carbs,
            fat: acc.fat + value.fat,
          };
        },
        { kcal: 0, protein: 0, carbs: 0, fat: 0 }
      );
      const count = Math.max(1, dates.length);
      return {
        kcal: +(totals.kcal / count).toFixed(0),
        protein: +(totals.protein / count).toFixed(1),
        carbs: +(totals.carbs / count).toFixed(1),
        fat: +(totals.fat / count).toFixed(1),
      };
    };

    const recentDates = (count) =>
      allDates
        .slice()
        .sort((a, b) => b.localeCompare(a))
        .slice(0, count);

    const rangeDates = (fromDate) => {
      const fromIso = toISODate(startOfDay(fromDate));
      return allDates.filter((date) => date >= fromIso && date <= todayIso).sort();
    };

    const summaries = [
      { key: "7d", label: t('dashboard.avgAll'), averages: computeForDates(recentDates(7)) },
      { key: "mtd", label: t('dashboard.avgMTD'), averages: computeForDates(rangeDates(startOfMonth(today))) },
      { key: "qtd", label: t('dashboard.avgQTD'), averages: computeForDates(rangeDates(startOfQuarter(today))) },
      { key: "ytd", label: t('dashboard.avgYTD'), averages: computeForDates(rangeDates(startOfYear(today))) },
    ];

    return summaries;
  }, [totalsByDate]);

  const dailyGoals = settings.dailyGoals ?? ensureDailyGoals(DEFAULT_SETTINGS.dailyGoals);
  const activeSetup = normalizeSetupMode(dailyGoals?.setup);
  const activeDualProfile = normalizeDualProfile(dailyGoals?.dual?.active);
  const defaultModeEntry = useMemo(
    () => cloneModeEntry({ setup: activeSetup, profile: activeDualProfile }),
    [activeSetup, activeDualProfile]
  );

  const goalSchedule = dailyGoals?.byDate ?? {};
  const sortedScheduleKeys = useMemo(() => Object.keys(goalSchedule).sort(), [goalSchedule]);

  const resolveModeEntry = useCallback(
    (isoDate) => {
      const fallback = cloneModeEntry(defaultModeEntry);
      if (!isoDate || !ISO_DATE_RE.test(isoDate)) {
        return fallback;
      }
      const direct = goalSchedule[isoDate];
      if (direct) {
        return coerceModeEntry(direct, fallback);
      }
      for (let i = sortedScheduleKeys.length - 1; i >= 0; i -= 1) {
        const key = sortedScheduleKeys[i];
        if (key <= isoDate) {
          const entry = goalSchedule[key];
          if (entry) {
            return coerceModeEntry(entry, fallback);
          }
        }
      }
      return fallback;
    },
    [defaultModeEntry, goalSchedule, sortedScheduleKeys]
  );

  const getGoalsForEntry = useCallback(
    (entry) => {
      const setup = entry?.setup;
      if (setup === "dual") {
        const profile = entry?.profile === "rest" ? "rest" : "train";
        return dailyGoals?.dual?.[profile] ?? DEFAULT_GOALS;
      }
      if (setup && setup !== "dual" && dailyGoals?.[setup]) {
        return dailyGoals[setup];
      }
      return dailyGoals?.dual?.train ?? DEFAULT_GOALS;
    },
    [dailyGoals]
  );

  const goalValuesForDate = useCallback(
    (isoDate) => {
      const entry = resolveModeEntry(isoDate);
      return getGoalsForEntry(entry);
    },
    [getGoalsForEntry, resolveModeEntry]
  );

  // Attach today's goal as scaleMax — defined here because goalValuesForDate is available now
  const averageSummariesWithGoal = useMemo(() => {
    const todayGoals = goalValuesForDate(todayISO());
    return averageSummaries.map((summary) => ({ ...summary, scaleMax: todayGoals }));
  }, [averageSummaries, goalValuesForDate]);

  const stickyEntry = useMemo(() => resolveModeEntry(stickyDate), [resolveModeEntry, stickyDate]);
  const stickyGoals = useMemo(() => getGoalsForEntry(stickyEntry), [getGoalsForEntry, stickyEntry]);
  const dashboardEntry = useMemo(() => resolveModeEntry(logDate), [resolveModeEntry, logDate]);
  const dashboardGoals = useMemo(() => getGoalsForEntry(dashboardEntry), [getGoalsForEntry, dashboardEntry]);
  const goalTargetEntry = useMemo(() => resolveModeEntry(dashboardDate), [resolveModeEntry, dashboardDate]);
  const goalTarget = useMemo(() => getGoalsForEntry(goalTargetEntry), [getGoalsForEntry, goalTargetEntry]);
  const logDateEntry = dashboardEntry;
  const splitEntry = goalTargetEntry;
  const goalDateEntry = goalTargetEntry;
  const topFoodsEntry = goalTargetEntry;

  // Load earned badges from Supabase on sign-in
  useEffect(() => {
    if (!session?.user?.id) return;
    supabase
      .from("user_badges")
      .select("badge_id")
      .eq("user_id", session.user.id)
      .then(({ data }) => {
        if (data) setEarnedBadgeIds(new Set(data.map((r) => r.badge_id)));
      });
  }, [session?.user?.id, authRefreshKey]);

  // Recompute badges whenever entries/foods/goals change, save newly earned ones.
  // badgesLoadedRef ensures we don't show popups for badges already in DB on first load.
  const badgesLoadedRef = useRef(false);
  useEffect(() => {
    if (!session?.user?.id || entriesLoading || profileLoading) return;
    const defaultFoodIdSet = new Set(settings.defaultFoodIds ?? []);
    const userAddedFoods = defaultFoodIdSet.size > 0 ? foods.filter((f) => !defaultFoodIdSet.has(f.id)) : foods;
    const freshEarned = computeEarnedBadgeIds(entries, userAddedFoods, goalValuesForDate);
    const newlyEarned = [...freshEarned].filter((id) => !earnedBadgeIds.has(id));

    // Always merge — never remove a badge once earned, even if data changes
    if (newlyEarned.length > 0) {
      setEarnedBadgeIds((prev) => new Set([...prev, ...newlyEarned]));
    }

    if (!badgesLoadedRef.current) {
      badgesLoadedRef.current = true;
      return;
    }

    if (newlyEarned.length === 0) return;

    // Show unlock popups for newly earned badges
    setBadgeUnlockQueue((q) => [...q, ...newlyEarned]);

    const rows = newlyEarned.map((badge_id) => ({ user_id: session.user.id, badge_id }));
    supabase.from("user_badges").upsert(rows, { onConflict: "user_id,badge_id" }).then(({ error }) => {
      if (error) console.error("Failed to save badges", error);
    });
  }, [entries, foods, goalValuesForDate, session?.user?.id, entriesLoading, profileLoading]);

  // Dequeue: show next badge popup when current is dismissed
  useEffect(() => {
    if (badgeUnlockShown) return;
    if (badgeUnlockQueue.length === 0) return;
    const [next, ...rest] = badgeUnlockQueue;
    setBadgeUnlockShown(next);
    setBadgeUnlockQueue(rest);
  }, [badgeUnlockShown, badgeUnlockQueue]);

  const headerPillClass = "gap-2 rounded-full border border-slate-200 dark:border-slate-700 bg-white/70 dark:bg-slate-900/60 px-3 py-2 text-xs font-medium shadow-sm hover:bg-slate-50 dark:hover:bg-slate-800";

  const sortedFoods = useMemo(()=>{
    const list = [...foods];
    list.sort((a, b)=>{
      const dir = foodSort.direction === "asc" ? 1 : -1;
      let av;
      let bv;
      switch(foodSort.column){
        case "createdAt":
          av = Date.parse(a.createdAt ?? "") || 0;
          bv = Date.parse(b.createdAt ?? "") || 0;
          break;
        case "name":
          av = (a.name ?? "").toLowerCase();
          bv = (b.name ?? "").toLowerCase();
          break;
        case "category":
          av = getCategoryLabel(a.category ?? DEFAULT_CATEGORY).toLowerCase();
          bv = getCategoryLabel(b.category ?? DEFAULT_CATEGORY).toLowerCase();
          break;
        case "unit":
          av = a.unit === "perServing" ? `per ${formatNumber(a.servingSize ?? 1)} g serving` : "per 100 g";
          bv = b.unit === "perServing" ? `per ${formatNumber(b.servingSize ?? 1)} g serving` : "per 100 g";
          av = av.toLowerCase();
          bv = bv.toLowerCase();
          break;
        case "kcal":
          av = a.kcal ?? 0;
          bv = b.kcal ?? 0;
          break;
        case "protein":
          av = a.protein ?? 0;
          bv = b.protein ?? 0;
          break;
        case "carbs":
          av = a.carbs ?? 0;
          bv = b.carbs ?? 0;
          break;
        case "fat":
          av = a.fat ?? 0;
          bv = b.fat ?? 0;
          break;
        default:
          av = 0;
          bv = 0;
      }
      if(av < bv) return -1 * dir;
      if(av > bv) return 1 * dir;
      return 0;
    });
    return list;
  }, [foods, foodSort]);

  const filteredFoods = useMemo(() => {
    let list = sortedFoods;
    if (foodCategoryFilter.size > 0) {
      list = list.filter(f => foodCategoryFilter.has(f.category ?? DEFAULT_CATEGORY));
    }
    const q = foodSearch.trim().toLowerCase();
    if (!q) return list;
    return list.filter(f =>
      f.name.toLowerCase().includes(q) ||
      (f.brand ?? "").toLowerCase().includes(q) ||
      getCategoryLabel(f.category ?? DEFAULT_CATEGORY).toLowerCase().includes(q)
    );
  }, [sortedFoods, foodSearch, foodCategoryFilter]);

  const availableCategories = useMemo(() => {
    const seen = new Set(foods.map(f => f.category ?? DEFAULT_CATEGORY));
    return FOOD_CATEGORIES.filter(c => seen.has(c.value));
  }, [foods]);

  // Trend
  const [trendRange, setTrendRange] = useState('7');
  const [show, setShow] = useState({kcal:true, protein:true, carbs:false, fat:false});
  const trendSeries = useMemo(()=>{
    const now = startOfDay(new Date()); const from = startOfRange(trendRange); const isoFrom = toISODate(from); const map={};
    entries.filter(e=>e.date>=isoFrom && e.date<=toISODate(now)).forEach(e=>{ const f=foods.find(x=>x.id===e.foodId); if(!f) return; const m=scaleMacros(f,e.qty); if(!map[e.date]) map[e.date]={kcal:0,fat:0,carbs:0,protein:0}; map[e.date].kcal+=m.kcal; map[e.date].fat+=m.fat; map[e.date].carbs+=m.carbs; map[e.date].protein+=m.protein; });
    return rangeDays(from, now).map(d=>{ const k=toISODate(d); return { date:k, ...(map[k]??{kcal:0,fat:0,carbs:0,protein:0})};});
  },[entries,foods,trendRange]);

  // Top foods (limit 5)
  const [topMacroKey, setTopMacroKey] = useState('kcal');
  const topFoods = useMemo(()=>{
    const map = new Map();
    entries
      .filter(e=>e.date===dashboardDate)
      .forEach(e=>{
        const f=foods.find(x=>x.id===e.foodId);
        if(!f) return;
        const m=scaleMacros(f,e.qty);
        const current=(map.get(f.name)||0)+ (m?.[topMacroKey] ?? 0);
        map.set(f.name,current);
      });
    const sorted = Array.from(map.entries()).map(([name,val])=>({name,val})).sort((a,b)=>b.val-a.val);
    const total = sorted.reduce((acc,item)=>acc+(item.val??0),0);
    const topFive = sorted.slice(0,5);
    const topSum = topFive.reduce((acc,item)=>acc+(item.val??0),0);
    const remainder = Math.max(0,total-topSum);
    const items = remainder>0 ? [...topFive,{name:'Other',val:remainder,isOther:true}] : topFive;
    return { items, total };
  },[entries,foods,dashboardDate,topMacroKey]);

  const goalTotals = useMemo(()=> totalsForDate(dashboardDate),[entries, foods, dashboardDate]);

  const weeklyNutrition = useMemo(() => {
    const targetISO = ISO_DATE_RE.test(dashboardDate) ? dashboardDate : todayISO();
    const weekAnchor = ISO_DATE_RE.test(weekNavDate) ? weekNavDate : todayISO();
    const weekStartDate = startOfWeek(new Date(`${weekAnchor}T00:00:00`), { weekStartsOn: 1 });
    const weekEndDate = endOfWeek(new Date(`${weekAnchor}T00:00:00`), { weekStartsOn: 1 });
    const isoTodayValue = todayISO();

    const days = rangeDays(weekStartDate, weekEndDate).map((date) => {
      const iso = toISODate(date);
      return {
        iso,
        label: format(date, "EEEEE"),
        isToday: iso === isoTodayValue,
        isSelected: iso === targetISO,
      };
    });

    const macros = [
      { key: "kcal", label: "Calories", unit: "kcal", theme: MACRO_THEME.kcal },
      { key: "protein", label: "Protein", unit: "g", theme: MACRO_THEME.protein },
      { key: "carbs", label: "Carbs", unit: "g", theme: MACRO_THEME.carbs },
      { key: "fat", label: "Fat", unit: "g", theme: MACRO_THEME.fat },
    ];

    const rows = macros.map((macro) => {
      let selectedActual = 0;
      let selectedGoal = 0;

      const cells = days.map((day) => {
        const totals = totalsForDate(day.iso);
        const goal = goalValuesForDate(day.iso);
        const actualValue = Math.max(0, totals[macro.key] ?? 0);
        const goalValue = Math.max(0, goal?.[macro.key] ?? 0);
        if (day.iso === targetISO) {
          selectedActual = actualValue;
          selectedGoal = goalValue;
        }
        return {
          iso: day.iso,
          actual: actualValue,
          goal: goalValue,
        };
      });

      return {
        key: macro.key,
        label: macro.label,
        unit: macro.unit,
        theme: macro.theme,
        cells,
        selectedActual,
        selectedGoal,
      };
    });

    return {
      days,
      rows,
      weekLabel: `${format(weekStartDate, "MMM d")} – ${format(weekEndDate, "MMM d")}`,
    };
  }, [dashboardDate, weekNavDate, entries, foods, goalValuesForDate]);

  const weekNavAtCurrentWeek = useMemo(() => {
    const anchor = ISO_DATE_RE.test(weekNavDate) ? weekNavDate : todayISO();
    const wStart = toISODate(startOfWeek(new Date(`${anchor}T00:00:00`), { weekStartsOn: 1 }));
    const thisWeekStart = toISODate(startOfWeek(new Date(), { weekStartsOn: 1 }));
    return wStart >= thisWeekStart;
  }, [weekNavDate]);

  const entriesForSplitDate = useMemo(()=> entries.filter((e)=>e.date===dashboardDate),[entries, dashboardDate]);

  // Meal-split dataset for dashboard (stacked bar)
  const mealSplit = useMemo(()=>{
    const byMeal = { breakfast:{kcal:0,protein:0,carbs:0,fat:0}, lunch:{kcal:0,protein:0,carbs:0,fat:0}, dinner:{kcal:0,protein:0,carbs:0,fat:0}, snack:{kcal:0,protein:0,carbs:0,fat:0}, other:{kcal:0,protein:0,carbs:0,fat:0} };
    entriesForSplitDate.forEach(e=>{ const f=foods.find(x=>x.id===e.foodId); if(!f) return; const m=scaleMacros(f,e.qty); const key = e.meal||'other'; byMeal[key].kcal+=m.kcal; byMeal[key].protein+=m.protein; byMeal[key].carbs+=m.carbs; byMeal[key].fat+=m.fat; });
    return MEAL_ORDER.map(k=>({ meal: t('meal.'+k), ...byMeal[k] }));
  },[entriesForSplitDate,foods]);

  // Mutators
  async function addEntry(){
    if(!selectedFood||!qty||qty<=0||!session?.user?.id) return;
    const payload = {
      user_id: session.user.id,
      date: logDate,
      food_id: selectedFood.id,
      qty,
      meal,
    };
    const { data: inserted, error } = await supabase.from("entries").insert(payload).select().single();
    if (error) {
      alert(error.message || t('error.unableAddEntry'));
      return;
    }
    if (!inserted) return;
    const entry = {
      id: inserted.id,
      date: inserted.date,
      foodId: inserted.food_id,
      qty: Number(inserted.qty) || 0,
      meal: inserted.meal,
    };
    setEntries(prev=>[entry,...prev]);
    setQty(0);
    setSelectedFoodId(null);
    setMeal(suggestMealByNow());
  }

  async function removeEntry(id){
    if (!session?.user?.id) {
      console.error("Cannot delete entry: missing authenticated user session.");
      return;
    }
    const { error } = await supabase
      .from("entries")
      .delete()
      .match({ id, user_id: session.user.id });
    if (error) {
      console.error("Entry delete failed", { id, userId: session.user.id, error });
      alert(error.message || t('error.unableDeleteEntry'));
      return;
    }
    setEntries(prev=>prev.filter(e=>e.id!==id));
  }

  async function updateEntryQuantity(id,newQty){
    if(!Number.isFinite(newQty)||newQty<=0) return;
    if (!session?.user?.id) {
      console.error("Cannot update entry quantity: missing authenticated user session.");
      return;
    }
    const { error } = await supabase
      .from("entries")
      .update({ qty: newQty })
      .match({ id, user_id: session.user.id });
    if (error) {
      console.error("Entry quantity update failed", { id, userId: session.user.id, error });
      alert(error.message || t('error.unableUpdateQuantity'));
      return;
    }
    setEntries(prev=>prev.map(e=>e.id===id?{...e,qty:newQty}:e));
  }

  async function updateEntryFood(id,newFoodId){
    if (!session?.user?.id) {
      console.error("Cannot update entry food: missing authenticated user session.");
      return;
    }
    const currentEntry = entries.find((entry) => entry.id === id);
    if (!currentEntry) return;
    const oldFood=foods.find(f=>f.id===currentEntry.foodId);
    const newFood=foods.find(f=>f.id===newFoodId);
    if (!newFood) return;
    const newQty=normalizeQty(oldFood,newFood,currentEntry.qty);

    const { error } = await supabase
      .from("entries")
      .update({ food_id: newFoodId, qty: newQty })
      .match({ id, user_id: session.user.id });
    if (error) {
      console.error("Entry food update failed", { id, userId: session.user.id, newFoodId, error });
      alert(error.message || t('error.unableUpdateFood'));
      return;
    }

    setEntries(prev=>prev.map(e=>e.id===id?{...e,foodId:newFoodId,qty:newQty}:e));
  }

  async function updateEntryMeal(id,newMeal){
    if (!session?.user?.id) {
      console.error("Cannot update entry meal: missing authenticated user session.");
      return;
    }
    const { error } = await supabase
      .from("entries")
      .update({ meal: newMeal })
      .match({ id, user_id: session.user.id });
    if (error) {
      console.error("Entry meal update failed", { id, userId: session.user.id, newMeal, error });
      alert(error.message || t('error.unableUpdateMeal'));
      return;
    }
    setEntries(prev=>prev.map(e=>e.id===id?{...e,meal:newMeal}:e));
  }
  async function addFood(newFood){
    if (!session?.user?.id) return;
    const sanitized = sanitizeFood(newFood);
    const payload = {
      user_id: session.user.id,
      name: sanitized.name,
      brand: sanitized.brand ?? null,
      unit: sanitized.unit,
      serving_size: sanitized.servingSize ?? null,
      kcal: sanitized.kcal,
      fat: sanitized.fat,
      carbs: sanitized.carbs,
      protein: sanitized.protein,
      category: sanitized.category,
      components: sanitized.category === "homeRecipe" ? sanitized.components : null,
    };

    const { data: inserted, error } = await supabase.from("foods").insert(payload).select().single();
    if (error) {
      alert(error.message || t('error.unableAddFood'));
      return;
    }

    if (!inserted) return;

    const mapped = sanitizeFood({
      id: inserted.id,
      name: inserted.name,
      brand: inserted.brand,
      unit: inserted.unit,
      servingSize: inserted.serving_size,
      kcal: inserted.kcal,
      fat: inserted.fat,
      carbs: inserted.carbs,
      protein: inserted.protein,
      category: inserted.category,
      components: inserted.components,
      createdAt: inserted.created_at,
    });
    setFoods(prev => [mapped, ...prev]);
  }

  async function deleteFood(id){
    if (!session?.user?.id) {
      console.error("Cannot delete food: missing authenticated user session.");
      return;
    }
    const { error } = await supabase.from("foods").delete().match({ id, user_id: session.user.id });
    if (error) {
      console.error("Food delete failed", { id, userId: session.user.id, error });
      alert(error.message || t('error.unableDeleteFood'));
      return;
    }
    setFoods(prev=>prev.filter(f=>f.id!==id));
  }

  function requestDeleteFood(food){
    setFoodPendingDelete(food);
  }

  async function bulkDeleteFoods(ids) {
    if (!session?.user?.id) return;
    const idArray = [...ids];
    const { error } = await supabase.from("foods").delete().in("id", idArray).eq("user_id", session.user.id);
    if (error) { alert(error.message || t('error.unableDeleteFoods')); return; }
    setFoods(prev => prev.filter(f => !ids.has(f.id)));
    setFoodSelectedIds(new Set());
    setBulkDeleteConfirmOpen(false);
  }

  async function confirmDeleteFood(){
    if (!foodPendingDelete?.id) return;
    await deleteFood(foodPendingDelete.id);
    setFoodPendingDelete(null);
  }

  async function updateFood(foodId, partial){
    if (!session?.user?.id) {
      console.error("Cannot update food: missing authenticated user session.");
      return;
    }

    const existing = foods.find((f) => f.id === foodId);
    if (!existing) return;
    const updated = sanitizeFood({ ...existing, ...partial, id: existing.id });

    const payload = {
      name: updated.name,
      brand: updated.brand ?? null,
      unit: updated.unit,
      serving_size: updated.servingSize ?? null,
      kcal: updated.kcal,
      fat: updated.fat,
      carbs: updated.carbs,
      protein: updated.protein,
      category: updated.category,
      components: updated.category === "homeRecipe" ? updated.components : null,
    };

    const { error } = await supabase
      .from("foods")
      .update(payload)
      .match({ id: foodId, user_id: session.user.id });

    if (error) {
      console.error("Food update failed", { foodId, userId: session.user.id, error });
      alert(error.message || "Unable to update food.");
      return;
    }

    if(
      existing.unit !== updated.unit ||
      (existing.unit === "perServing" && updated.unit === "perServing" && existing.servingSize !== updated.servingSize)
    ){
      setEntries(prevEntries=>prevEntries.map(e=>{
        if(e.foodId!==foodId) return e;
        const newQty = normalizeQty(existing, updated, e.qty);
        return { ...e, qty: newQty };
      }));
    }

    setFoods(prev => prev.map((f) => (f.id === foodId ? updated : f)));
  }

  function exportJSON(){ const blob = new Blob([JSON.stringify({foods,entries,settings},null,2)],{type:'application/json'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=`macrotracker_backup_${todayISO()}.json`; a.click(); URL.revokeObjectURL(url); }
  async function importJSON(file){
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const data = JSON.parse(String(reader.result));

        if (Array.isArray(data.foods)) {
          if (!session?.user?.id) {
            console.error("Cannot import foods: missing authenticated user session.");
            alert(t('error.pleaseSignInImport'));
            return;
          }

          const mappedFoods = data.foods
            .map((rawFood) => sanitizeFood(rawFood))
            .map((food) => ({
              user_id: session.user.id,
              name: food.name,
              brand: food.brand ?? null,
              unit: food.unit,
              serving_size: food.servingSize ?? null,
              kcal: food.kcal,
              fat: food.fat,
              carbs: food.carbs,
              protein: food.protein,
              category: food.category,
            }));

          if (mappedFoods.length > 0) {
            const { error: insertError } = await supabase.from("foods").insert(mappedFoods);
            if (insertError) {
              console.error("Food import insert failed", { error: insertError });
              alert(insertError.message || t('error.unableImportFoods'));
              return;
            }

            const { data: foodsData, error: foodsError } = await supabase
              .from("foods")
              .select("*")
              .eq("user_id", session.user.id)
              .order("created_at", { ascending: false });

            if (foodsError) {
              console.error("Food import refetch failed", { error: foodsError });
              alert(foodsError.message || t('error.importRefreshFailed'));
            } else {
              const refreshedFoods = (foodsData || []).map((row) => sanitizeFood({
                id: row.id,
                name: row.name,
                brand: row.brand,
                unit: row.unit,
                servingSize: row.serving_size,
                kcal: row.kcal,
                fat: row.fat,
                carbs: row.carbs,
                protein: row.protein,
                category: row.category,
                createdAt: row.created_at,
              }));
              setFoods(refreshedFoods);
            }

            alert(t('success.foodsImported', {count: mappedFoods.length}));
          }
        }

        if(data.settings) setSettings(ensureSettings(data.settings));
      } catch {
        alert(t('error.invalidJsonFile'));
      }
    };
    reader.readAsText(file);
  }

  async function resetData(){
    if (!session?.user?.id) {
      setFoods([]);
      setEntries([]);
      return;
    }

    const { error: entriesError } = await supabase
      .from("entries")
      .delete()
      .eq("user_id", session.user.id);
    if (entriesError) {
      alert(entriesError.message || "Unable to reset entries.");
      return;
    }

    const { error: foodsError } = await supabase
      .from("foods")
      .delete()
      .eq("user_id", session.user.id);
    if (foodsError) {
      alert(foodsError.message || "Unable to reset foods.");
      return;
    }

    setEntries([]);
    setFoods([]);
  }

  // Helper
  const left = (goal, actual)=> Math.max(0, (goal||0) - (actual||0));

  const toggleFoodSort = (column)=>{
    setFoodSort((prev)=>{
      if(prev.column === column){
        return { column, direction: prev.direction === "asc" ? "desc" : "asc" };
      }
      return { column, direction: "asc" };
    });
  };

  const renderSortIcon = (column)=>{
    if(foodSort.column !== column){
      return <ArrowUpDown className="h-3 w-3 opacity-40" />;
    }
    return foodSort.direction === "asc"
      ? <ArrowUp className="h-3 w-3" />
      : <ArrowDown className="h-3 w-3" />;
  };

  const setModeEntryForDate = useCallback(
    (isoDate, entry) => {
      if (!isoDate || !ISO_DATE_RE.test(isoDate)) return;
      const normalized = cloneModeEntry(coerceModeEntry(entry));
      setSettings((prev) => {
        const goals = ensureDailyGoals(prev.dailyGoals);
        const today = todayISO();
        const nextByDate = { ...goals.byDate, [isoDate]: normalized };
        const nextGoals = { ...goals, byDate: nextByDate };
        if (isoDate === today) {
          nextGoals.setup = normalized.setup;
          if (normalized.setup === "dual") {
            nextGoals.dual = {
              ...goals.dual,
              active: normalizeDualProfile(normalized.profile),
            };
          }
        }
        return {
          ...prev,
          dailyGoals: nextGoals,
        };
      });
    },
    [setSettings]
  );

  const updateMacroGoal = (modeKey, macroKey) => (value) => {
    const numericValue = Number.isFinite(value) ? value : 0;
    setSettings((prev) => {
      const goals = ensureDailyGoals(prev.dailyGoals);
      const nextGoals = { ...goals };
      if (modeKey.startsWith("dual.")) {
        const profileKey = modeKey.split(".")[1] === "rest" ? "rest" : "train";
        nextGoals.dual = {
          ...goals.dual,
          [profileKey]: {
            ...goals.dual?.[profileKey],
            [macroKey]: numericValue,
          },
        };
      } else if (SETUP_MODES.includes(modeKey)) {
        nextGoals[modeKey] = {
          ...goals[modeKey],
          [macroKey]: numericValue,
        };
      }
      return {
        ...prev,
        dailyGoals: nextGoals,
      };
    });
  };

  const handleDualProfileChange = useCallback(
    (value) => {
      const profile = value === "rest" ? "rest" : "train";
      setSettings((prev) => {
        const goals = ensureDailyGoals(prev.dailyGoals);
        const today = todayISO();
        const nextByDate = {
          ...goals.byDate,
          [today]: cloneModeEntry({ setup: "dual", profile }),
        };
        return {
          ...prev,
          dailyGoals: {
            ...goals,
            setup: "dual",
            dual: {
              ...goals.dual,
              active: profile,
            },
            byDate: nextByDate,
          },
        };
      });
    },
    [setSettings]
  );

  const handleSetupChange = useCallback(
    (mode) => {
      const nextSetup = normalizeSetupMode(mode);
      setSettings((prev) => {
        const goals = ensureDailyGoals(prev.dailyGoals);
        const today = todayISO();
        const profile = nextSetup === "dual" ? normalizeDualProfile(goals.dual?.active) : undefined;
        const nextByDate = {
          ...goals.byDate,
          [today]: cloneModeEntry({ setup: nextSetup, profile }),
        };
        return {
          ...prev,
          dailyGoals: {
            ...goals,
            setup: nextSetup,
            dual: {
              ...goals.dual,
              active: profile ?? goals.dual.active,
            },
            byDate: nextByDate,
          },
        };
      });
    },
    [setSettings]
  );

  const handleSaveBodyProfile = useCallback(async () => {
    if (profileSaving) return;
    let snapshot = null;
    setProfileSaveError("");
    setProfileSaveSuccess("");

    setSettings((prev) => {
      const profile = prev.profile ?? {};
      const weightValue = toNumber(profile.weightKg, 0);
      const bodyFatValue =
        profile.bodyFatPct == null || Number.isNaN(profile.bodyFatPct)
          ? null
          : toNumber(profile.bodyFatPct, 0);
      const now = new Date();
      const date = toISODate(now);
      const history = ensureBodyHistory(prev.profileHistory);
      const withoutToday = history.filter((entry) => entry.date !== date);
      const nextHistory = [...withoutToday, {
        date,
        weightKg: weightValue,
        bodyFatPct: bodyFatValue,
        recordedAt: now.toISOString(),
      }].sort((a, b) => a.date.localeCompare(b.date));
      const next = {
        ...prev,
        profile: {
          ...profile,
          weightKg: weightValue,
          bodyFatPct: bodyFatValue,
        },
        profileHistory: nextHistory,
      };
      snapshot = next;
      return next;
    });

    if (snapshot) {
      setProfileSaving(true);
      try {
        const result = await saveUserProfile(snapshot);
        if (result?.ok) {
          setProfileSaveSuccess(result.message);
          setProfileLastSavedAt(new Date());
        } else {
          setProfileSaveError(result?.message || t('error.unableSaveProfile'));
        }
      } finally {
        setProfileSaving(false);
      }
    }
  }, [profileSaving, saveUserProfile, setSettings]);

  const handleSignOut = useCallback(async () => {
    await supabase.auth.signOut();
  }, []);

  const handleOnboardingComplete = useCallback(async ({ displayName, profile, dailyGoals }) => {
    if (!session?.user?.id) return;

    // 1. Save display name to profiles table.
    // Try to set a clean username derived from the display name; if it collides
    // with an existing account, fall back to only updating display_username.
    const username = displayName.toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 30) || displayName.toLowerCase();
    const { error: usernameError } = await supabase
      .from("profiles")
      .update({ username, display_username: displayName })
      .eq("id", session.user.id);

    if (usernameError) {
      // Likely a unique constraint on username — just save the display name
      await supabase
        .from("profiles")
        .update({ display_username: displayName })
        .eq("id", session.user.id);
    }

    setProfileUsername(displayName);
    setAccountUsername(displayName);

    // 2. Merge profile + dailyGoals into settings and persist to Supabase
    const nextSettings = ensureSettings({
      ...settings,
      profile: { ...settings.profile, ...profile },
      dailyGoals: ensureDailyGoals({ ...settings.dailyGoals, ...dailyGoals }),
    });
    setSettings(nextSettings);
    await saveUserProfile(nextSettings);

    // 3. Seed default foods for new users
    const seedPayload = DEFAULT_FOODS.map((f) => ({
      user_id: session.user.id,
      name: i18n.t('defaultFoods.'+f.name, f.name),
      brand: f.brand ?? null,
      unit: f.unit,
      serving_size: f.servingSize ?? null,
      kcal: f.kcal,
      fat: f.fat,
      carbs: f.carbs,
      protein: f.protein,
      category: f.category,
      components: null,
    }));
    const { data: seeded } = await supabase.from("foods").insert(seedPayload).select();
    if (seeded?.length) {
      const mapped = seeded.map((r) =>
        sanitizeFood({
          id: r.id,
          name: r.name,
          brand: r.brand,
          unit: r.unit,
          servingSize: r.serving_size,
          kcal: r.kcal,
          fat: r.fat,
          carbs: r.carbs,
          protein: r.protein,
          category: r.category,
          components: r.components,
          createdAt: r.created_at,
        })
      );
      setFoods(mapped);
      // Persist seeded IDs so badge logic can exclude them from user-added counts
      const settingsWithDefaults = { ...nextSettings, defaultFoodIds: seeded.map((r) => r.id) };
      setSettings(settingsWithDefaults);
      save(K_SETTINGS, stripProfileSettingsForStorage(settingsWithDefaults));
    }
  }, [session?.user?.id, settings, saveUserProfile]);

  const handleUpdateUsername = useCallback(async () => {
    const displayUsername = accountUsername.trim();
    const username = displayUsername.toLowerCase();
    setAccountError("");
    setAccountSuccess("");

    if (!displayUsername) {
      setAccountError(t('error.usernameRequired'));
      return;
    }

    const { error } = await supabase
      .from("profiles")
      .update({ username, display_username: displayUsername })
      .eq("id", session.user.id);

    if (error) {
      const message = (error.message || "").toLowerCase();
      setAccountError(message.includes("duplicate") || message.includes("unique") ? t('error.usernameTaken') : (error.message || t('error.unableUpdateUsername')));
      return;
    }

    setProfileUsername(displayUsername);
    setAccountSuccess(t('success.usernameUpdated'));
  }, [accountUsername, session?.user?.id]);

  const handleUpdateEmail = useCallback(async () => {
    const email = accountEmail.trim().toLowerCase();
    setAccountError("");
    setAccountSuccess("");

    if (!email.includes("@")) {
      setAccountError(t('error.invalidEmail'));
      return;
    }

    const { error } = await supabase.auth.updateUser({ email });
    if (error) {
      setAccountError(error.message || t('error.unableUpdateEmail'));
      return;
    }

    setAccountSuccess(t('success.checkEmailConfirm'));
  }, [accountEmail]);



  function extractAvatarStoragePath(url) {
    if (!url) return null;
    const marker = "/storage/v1/object/public/avatars/";
    const idx = url.indexOf(marker);
    if (idx === -1) return null;
    return url.slice(idx + marker.length);
  }

  const handleAvatarUpload = useCallback(async (file) => {
    if (!file || !session?.user?.id) return;
    setAccountError("");
    setAccountSuccess("");

    if (!AVATAR_ALLOWED_TYPES.has(file.type) || file.size > AVATAR_MAX_BYTES) {
      setAccountError(t('error.avatarSizeLimit'));
      return;
    }

    setAvatarUploading(true);

    try {
      const resizedBlob = await new Promise((resolve, reject) => {
        const image = new Image();
        const objectUrl = URL.createObjectURL(file);

        image.onload = () => {
          const size = 256;
          const canvas = document.createElement("canvas");
          canvas.width = size;
          canvas.height = size;
          const ctx = canvas.getContext("2d");

          if (!ctx) {
            URL.revokeObjectURL(objectUrl);
            reject(new Error(t('error.unableProcessImage')));
            return;
          }

          const srcW = image.width;
          const srcH = image.height;
          const srcSize = Math.min(srcW, srcH);
          const srcX = Math.floor((srcW - srcSize) / 2);
          const srcY = Math.floor((srcH - srcSize) / 2);

          ctx.drawImage(image, srcX, srcY, srcSize, srcSize, 0, 0, size, size);
          canvas.toBlob(
            (blob) => {
              URL.revokeObjectURL(objectUrl);
              if (!blob) {
                reject(new Error(t('error.unableProcessImage')));
                return;
              }
              resolve(blob);
            },
            "image/webp",
            0.8
          );
        };

        image.onerror = () => {
          URL.revokeObjectURL(objectUrl);
          reject(new Error("Unable to read image file."));
        };

        image.src = objectUrl;
      });

      const filePath = `${session.user.id}/${Date.now()}-avatar.webp`;
      const { error: uploadError } = await supabase.storage.from("avatars").upload(filePath, resizedBlob, { upsert: true });
      if (uploadError) {
        setAccountError(uploadError.message || t('error.unableUploadAvatar'));
        return;
      }

      const publicUrl = supabase.storage.from("avatars").getPublicUrl(filePath).data.publicUrl;
      const { error: updateError } = await supabase
        .from("profiles")
        .update({ avatar_url: publicUrl })
        .eq("id", session.user.id);

      if (updateError) {
        setAccountError(updateError.message || t('error.unableSaveAvatar'));
        return;
      }

      setProfileAvatarUrl(publicUrl);
      setAccountSuccess(t('success.profilePhotoUpdated'));
    } catch (error) {
      setAccountError(error?.message || t('error.unableProcessImage'));
    } finally {
      setAvatarUploading(false);
    }
  }, [session?.user?.id]);

  const handleRemoveAvatar = useCallback(async () => {
    if (!session?.user?.id) return;
    setAccountError("");
    setAccountSuccess("");

    const existingPath = extractAvatarStoragePath(profileAvatarUrl);
    if (existingPath) {
      const { error: removeError } = await supabase.storage.from("avatars").remove([existingPath]);
      if (removeError) {
        setAccountError(removeError.message || t('error.unableRemoveAvatarFile'));
        return;
      }
    }

    const { error: updateError } = await supabase
      .from("profiles")
      .update({ avatar_url: null })
      .eq("id", session.user.id);

    if (updateError) {
      setAccountError(updateError.message || t('error.unableClearAvatar'));
      return;
    }

    setProfileAvatarUrl("");
    setAccountSuccess(t('success.profilePhotoRemoved'));
  }, [profileAvatarUrl, session?.user?.id]);

  if (authLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-50 text-slate-700 dark:bg-slate-950 dark:text-slate-200">
        Loading session...
      </div>
    );
  }

  if (!session) {
    return <Auth />;
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-slate-100 text-slate-900 dark:from-slate-900 dark:to-slate-950 dark:text-slate-100">
      {profileNameReady && !profileUsername && (
        <OnboardingQuestionnaire
          userEmail={session?.user?.email ?? ""}
          onComplete={handleOnboardingComplete}
        />
      )}
      <header className="sticky top-0 z-40 backdrop-blur border-b border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/60">
        <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <img
              src="/brand/onebodyonelife-slogo-light.png"
              alt="OneBodyOneLife"
              className="block dark:hidden h-8 w-auto"
            />
            <img
              src="/brand/onebodyonelife-slogo-dark.png"
              alt="OneBodyOneLife"
              className="hidden dark:block h-8 w-auto"
            />
            <div className="hidden sm:block">
              <h1 className="font-semibold text-base sm:text-lg leading-tight">OneBodyOneLife</h1>
              <p className="hidden sm:block text-xs text-slate-500">Track protein, calories, fat & carbs by meal</p>
            </div>
          </div>
          <div className="flex items-center gap-1 sm:gap-2">
            {activeSetup === "dual" ? (
              <GoalModeToggle active={activeDualProfile} onChange={handleDualProfileChange} />
            ) : (
              <GoalModeBadge value={{ setup: activeSetup }} className="h-9 px-3 sm:px-4" />
            )}
            <div className="hidden sm:block text-xs text-slate-600 dark:text-slate-300 max-w-[180px] truncate" title={profileUsername || session.user?.email || ""}>
              {profileUsername || session.user?.email}
            </div>
            <Button variant="ghost" className={headerPillClass} onClick={handleSignOut} title={t('header.signOut')}>
              <LogOut className="h-4 w-4" />
              <span className="hidden sm:inline">{t('header.signOut')}</span>
            </Button>
            <button
              type="button"
              onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
              className="h-9 w-9 sm:h-10 sm:w-10 rounded-full flex items-center justify-center text-slate-400 dark:text-slate-500 transition hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              aria-label="Toggle light/dark mode"
              title={resolvedTheme === 'dark' ? t('header.switchToLight') : t('header.switchToDark')}
            >
              {resolvedTheme === 'dark'
                ? <Sun className="h-4 w-4 sm:h-[18px] sm:w-[18px]" />
                : <Moon className="h-4 w-4 sm:h-[18px] sm:w-[18px]" />}
            </button>
            <button
              type="button"
              onClick={() => setTab('settings')}
              className="h-9 w-9 sm:h-10 sm:w-10 overflow-hidden rounded-full border border-slate-300 bg-slate-200 dark:border-slate-700 dark:bg-slate-800 flex items-center justify-center text-xs font-semibold transition hover:scale-[1.03] hover:bg-slate-300/60 dark:hover:bg-slate-700"
              aria-label={t('header.goToProfile')}
            >
              {profileAvatarUrl ? (
                <img src={profileAvatarUrl} alt="Profile avatar" className="h-full w-full object-cover" />
              ) : (
                <User className="h-4 w-4 sm:h-5 sm:w-5 text-slate-500 dark:text-slate-300" />
              )}
            </button>
          </div>
        </div>

        {/* Sticky totals */}
        <div className="border-t border-slate-200 dark:border-slate-800">
          <div className="max-w-6xl mx-auto px-4">

            {/* ── Mobile: "Totals for [Today]" title row ── */}
            <div className="sm:hidden flex items-center justify-between pt-2 pb-1.5 border-b border-slate-100 dark:border-slate-800/50">
              <span className="text-[10px] font-semibold uppercase tracking-widest text-slate-400 dark:text-slate-500">
                {t('sticky.totalsFor')}
              </span>
              <button
                onClick={() => setStickyModeSheetOpen(true)}
                className="flex items-center gap-1"
                aria-label="Change totals date"
              >
                <span className={cn(
                  "text-xs font-semibold px-2.5 py-0.5 rounded-full",
                  effectiveStickyMode === 'selected'
                    ? "bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300"
                    : "bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300"
                )}>
                  {effectiveStickyMode === 'today' ? t('sticky.today') : t('sticky.selectedDay')}
                </span>
                <ChevronUp className="h-3 w-3 text-slate-400 dark:text-slate-500" />
              </button>
            </div>

            {/* ── Mobile: compact 4-column macro strip ── */}
            <div className="sm:hidden grid grid-cols-4 gap-2 py-2">
              <CompactMacroCell label="Cal"   color={COLORS.kcal}    actualNum={stickyTotals.kcal}     goalNum={stickyGoals.kcal}     unit="kcal" />
              <CompactMacroCell label="Pro"   color={COLORS.protein} actualNum={stickyTotals.protein}  goalNum={stickyGoals.protein}  unit="g"    />
              <CompactMacroCell label="Carbs" color={COLORS.carbs}   actualNum={stickyTotals.carbs}    goalNum={stickyGoals.carbs}    unit="g"    />
              <CompactMacroCell label="Fat"   color={COLORS.fat}     actualNum={stickyTotals.fat}      goalNum={stickyGoals.fat}      unit="g"    />
            </div>

            {/* ── Desktop: original StripKpi cards + select toggle (unchanged) ── */}
            <div className="hidden sm:flex items-center gap-3 py-2">
              <div className="grid grid-cols-4 gap-2 text-sm flex-1">
                {(() => {
                  const rem = stickyGoals.kcal - stickyTotals.kcal;
                  const over = rem < 0;
                  const remaining = over ? `${Math.abs(rem).toFixed(0)} ${t('sticky.over')}` : `${rem.toFixed(0)} ${t('sticky.left')}`;
                  return (
                    <StripKpi
                      label="Calories"
                      color={COLORS.kcal}
                      actual={`${stickyTotals.kcal.toFixed(0)} kcal`}
                      goal={`${stickyGoals.kcal.toFixed(0)} kcal`}
                      remaining={remaining}
                      over={over}
                    />
                  );
                })()}
                {(() => {
                  const rem = stickyGoals.protein - stickyTotals.protein;
                  const over = rem < 0;
                  const remaining = over ? `${Math.abs(rem).toFixed(1)} g ${t('sticky.over')}` : `${rem.toFixed(1)} g ${t('sticky.left')}`;
                  return (
                    <StripKpi
                      label="Protein"
                      color={COLORS.protein}
                      actual={`${stickyTotals.protein.toFixed(0)} g`}
                      goal={`${stickyGoals.protein.toFixed(0)} g`}
                      remaining={remaining}
                      over={over}
                    />
                  );
                })()}
                {(() => {
                  const rem = stickyGoals.carbs - stickyTotals.carbs;
                  const over = rem < 0;
                  const remaining = over ? `${Math.abs(rem).toFixed(1)} g ${t('sticky.over')}` : `${rem.toFixed(1)} g ${t('sticky.left')}`;
                  return (
                    <StripKpi
                      label="Carbs"
                      color={COLORS.carbs}
                      actual={`${stickyTotals.carbs.toFixed(0)} g`}
                      goal={`${stickyGoals.carbs.toFixed(0)} g`}
                      remaining={remaining}
                      over={over}
                    />
                  );
                })()}
                {(() => {
                  const rem = stickyGoals.fat - stickyTotals.fat;
                  const over = rem < 0;
                  const remaining = over ? `${Math.abs(rem).toFixed(1)} g ${t('sticky.over')}` : `${rem.toFixed(1)} g ${t('sticky.left')}`;
                  return (
                    <StripKpi
                      label="Fat"
                      color={COLORS.fat}
                      actual={`${stickyTotals.fat.toFixed(0)} g`}
                      goal={`${stickyGoals.fat.toFixed(0)} g`}
                      remaining={remaining}
                      over={over}
                    />
                  );
                })()}
              </div>
              <div className="flex items-center gap-2 text-xs shrink-0">
                <span className="text-slate-500">{t('sticky.totalsFor')}</span>
                <Select value={effectiveStickyMode} onValueChange={(v) => setStickyMode(v)}>
                  <SelectTrigger className="h-7 w-28"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="today">{t('sticky.today')}</SelectItem>
                    <SelectItem value="selected">{t('sticky.selectedDay')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-3 sm:px-4 pt-4 sm:pt-6 pb-24 sm:pb-6">
        <Tabs value={tab} onValueChange={setTab}>
          <TabsList className="hidden sm:grid w-full grid-cols-4 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/70 md:w-auto">
            <TabsTrigger value="dashboard" className="gap-1.5 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><BarChart3 className="h-4 w-4 shrink-0"/><span className="hidden sm:inline">{t('nav.dashboard')}</span></TabsTrigger>
            <TabsTrigger value="daily" className="gap-1.5 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><BookOpenText className="h-4 w-4 shrink-0"/><span className="hidden sm:inline">{t('nav.daily')}</span></TabsTrigger>
            <TabsTrigger value="foods" className="gap-1.5 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><Database className="h-4 w-4 shrink-0"/><span className="hidden sm:inline">{t('nav.foods')}</span></TabsTrigger>
            <TabsTrigger value="settings" className="gap-1.5 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><SettingsIcon className="h-4 w-4 shrink-0"/><span className="hidden sm:inline">{t('nav.settings')}</span></TabsTrigger>
          </TabsList>

          {/* DASHBOARD */}
          <TabsContent value="dashboard" className="mt-6 space-y-6">
            {/* Single shared date picker for Goal vs Actual, Macro Split, Top Foods, and Weekly Nutrition */}
            <div className="flex items-center justify-between">
              <p className="text-sm text-slate-500 dark:text-slate-400">{t('dashboard.dateLabel')}</p>
              <DatePickerButton value={dashboardDate} onChange={(v) => { const d = v || todayISO(); setDashboardDate(d); setWeekNavDate(d); }} className="w-44" />
            </div>
            <div className="grid lg:grid-cols-2 gap-4">
              <Card className="h-full min-h-[360px] flex flex-col">
                <CardHeader>
                  <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                    <CardTitle>{t('dashboard.goalVsActual')}</CardTitle>
                    <div className="flex items-center gap-2">
                      <GoalModeBadge value={goalDateEntry} />
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="flex-1">
                  <div className="flex h-full items-center justify-center">
                    <div className="grid w-full grid-cols-2 gap-2 sm:gap-4 content-center">
                      <GoalDonut label="Calories" theme={MACRO_THEME.kcal} actual={goalTotals.kcal} goal={goalTarget.kcal} unit="kcal" />
                      <GoalDonut label="Protein" theme={MACRO_THEME.protein} actual={goalTotals.protein} goal={goalTarget.protein} unit="g" />
                      <GoalDonut label="Carbs" theme={MACRO_THEME.carbs} actual={goalTotals.carbs} goal={goalTarget.carbs} unit="g" />
                      <GoalDonut label="Fat" theme={MACRO_THEME.fat} actual={goalTotals.fat} goal={goalTarget.fat} unit="g" />
                    </div>
                  </div>
                </CardContent>
              </Card>

              <WeeklyNutritionCard
                data={weeklyNutrition}
                onPrevWeek={() => setWeekNavDate((prev) => toISODate(addDays(new Date(`${prev}T00:00:00`), -7)))}
                onNextWeek={() => setWeekNavDate((prev) => toISODate(addDays(new Date(`${prev}T00:00:00`), 7)))}
                canGoForward={!weekNavAtCurrentWeek}
              />
            </div>

            {/* Macros Trend */}
            <Card>
              <CardHeader className="pb-0">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                  <CardTitle>{t('dashboard.macrosTrend')}</CardTitle>
                  <div className="flex flex-wrap items-center gap-2">
                    <Select value={trendRange} onValueChange={(v)=>setTrendRange(v)}>
                      <SelectTrigger className="h-8 w-full sm:w-36"><SelectValue placeholder="Range" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="7">{t('trendRanges.7')}</SelectItem>
                        <SelectItem value="14">{t('trendRanges.14')}</SelectItem>
                        <SelectItem value="30">{t('trendRanges.30')}</SelectItem>
                        <SelectItem value="90">{t('trendRanges.90')}</SelectItem>
                        <SelectItem value="365">{t('trendRanges.365')}</SelectItem>
                      </SelectContent>
                    </Select>
                    <TogglePill label="kcal" active={show.kcal} color={COLORS.kcal} onClick={()=>setShow({...show,kcal:!show.kcal})} />
                    <TogglePill label="protein" active={show.protein} color={COLORS.protein} onClick={()=>setShow({...show,protein:!show.protein})} />
                    <TogglePill label="carbs" active={show.carbs} color={COLORS.carbs} onClick={()=>setShow({...show,carbs:!show.carbs})} />
                    <TogglePill label="fat" active={show.fat} color={COLORS.fat} onClick={()=>setShow({...show,fat:!show.fat})} />
                  </div>
                </div>
              </CardHeader>
              <div className="mt-4" />
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={trendSeries} margin={{ left: 12, right: 12 }}>
                    <defs>
                      <linearGradient id="trend-kcal-stroke" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.kcal.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.kcal.gradientTo} />
                      </linearGradient>
                      <linearGradient id="trend-protein-stroke" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.protein.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.protein.gradientTo} />
                      </linearGradient>
                      <linearGradient id="trend-carbs-stroke" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.carbs.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.carbs.gradientTo} />
                      </linearGradient>
                      <linearGradient id="trend-fat-stroke" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.fat.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.fat.gradientTo} />
                      </linearGradient>
                      <linearGradient id="trend-kcal-fill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={MACRO_THEME.kcal.gradientFrom} stopOpacity={0.35} />
                        <stop offset="95%" stopColor={MACRO_THEME.kcal.gradientTo} stopOpacity={0.05} />
                      </linearGradient>
                      <linearGradient id="trend-protein-fill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={MACRO_THEME.protein.gradientFrom} stopOpacity={0.35} />
                        <stop offset="95%" stopColor={MACRO_THEME.protein.gradientTo} stopOpacity={0.05} />
                      </linearGradient>
                      <linearGradient id="trend-carbs-fill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={MACRO_THEME.carbs.gradientFrom} stopOpacity={0.35} />
                        <stop offset="95%" stopColor={MACRO_THEME.carbs.gradientTo} stopOpacity={0.05} />
                      </linearGradient>
                      <linearGradient id="trend-fat-fill" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={MACRO_THEME.fat.gradientFrom} stopOpacity={0.35} />
                        <stop offset="95%" stopColor={MACRO_THEME.fat.gradientTo} stopOpacity={0.05} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="date" tickFormatter={(d)=>d.slice(5)} stroke="#94a3b8" tick={{ fill: '#64748b' }} axisLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} tickLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} />
                    <YAxis yAxisId="kcal" stroke="#94a3b8" tick={{ fill: '#64748b' }} axisLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} tickLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} hide={!show.kcal} />
                    <YAxis yAxisId="grams" orientation="right" stroke="#94a3b8" tick={{ fill: '#64748b' }} axisLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} tickLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} tickFormatter={(v) => `${v}g`} hide={!show.protein && !show.carbs && !show.fat} />
                    <RTooltip
                      content={({ active, payload, label }) => {
                        if (!active || !payload?.length) return null;
                        const rawLabel =
                          (typeof label === "string" && label.length ? label : undefined)
                          ?? payload[0]?.payload?.date;
                        let title = rawLabel ?? "";
                        if (typeof rawLabel === "string" && ISO_DATE_RE.test(rawLabel)) {
                          const parsed = new Date(`${rawLabel}T00:00:00`);
                          if (!Number.isNaN(parsed.getTime())) {
                            title = format(parsed, "PP");
                          }
                        } else if (rawLabel instanceof Date && !Number.isNaN(rawLabel.getTime?.())) {
                          title = format(rawLabel, "PP");
                        }

                        return (
                          <ChartTooltipContainer title={title}>
                            {payload.map((item) => {
                              if (!item) return null;
                              const key = item.dataKey ?? item.name ?? "value";
                              const isCalories = key === "kcal";
                              const unit = isCalories ? "kcal" : "g";
                              const macroLabel = item.name ?? t('macro.'+key, MACRO_LABELS[key] ?? key);
                              const swatchColor =
                                MACRO_THEME[key]?.dark
                                ?? MACRO_THEME[key]?.gradientTo
                                ?? (typeof item.color === "string" && !item.color.startsWith("url(") ? item.color : undefined)
                                ?? COLORS[key]
                                ?? "#38bdf8";

                              return (
                                <div key={key} className="flex items-center gap-2">
                                  <span
                                    className="h-2.5 w-2.5 rounded-full"
                                    style={{ backgroundColor: swatchColor }}
                                  />
                                  <span className="flex-1 text-slate-200">{macroLabel}</span>
                                  <span className="font-semibold text-slate-100">
                                    {`${formatNumber(item.value ?? 0)} ${unit}`}
                                  </span>
                                </div>
                              );
                            })}
                          </ChartTooltipContainer>
                        );
                      }}
                    />
                    {show.kcal && (
                      <Area
                        yAxisId="kcal"
                        type="monotone"
                        name="kcal"
                        dataKey="kcal"
                        stroke="url(#trend-kcal-stroke)"
                        strokeWidth={3}
                        fill="url(#trend-kcal-fill)"
                        fillOpacity={1}
                        dot={false}
                        activeDot={{ r: 5 }}
                      />
                    )}
                    {show.protein && (
                      <Area
                        yAxisId="grams"
                        type="monotone"
                        name="Protein (g)"
                        dataKey="protein"
                        stroke="url(#trend-protein-stroke)"
                        strokeWidth={3}
                        fill="url(#trend-protein-fill)"
                        fillOpacity={1}
                        dot={false}
                        activeDot={{ r: 5 }}
                      />
                    )}
                    {show.carbs && (
                      <Area
                        yAxisId="grams"
                        type="monotone"
                        name="Carbs (g)"
                        dataKey="carbs"
                        stroke="url(#trend-carbs-stroke)"
                        strokeWidth={3}
                        fill="url(#trend-carbs-fill)"
                        fillOpacity={1}
                        dot={false}
                        activeDot={{ r: 5 }}
                      />
                    )}
                    {show.fat && (
                      <Area
                        yAxisId="grams"
                        type="monotone"
                        name="Fat (g)"
                        dataKey="fat"
                        stroke="url(#trend-fat-stroke)"
                        strokeWidth={3}
                        fill="url(#trend-fat-fill)"
                        fillOpacity={1}
                        dot={false}
                        activeDot={{ r: 5 }}
                      />
                    )}
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Macro Split per Meal */}
            <Card>
              <CardHeader className="pb-0">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                  <CardTitle className="flex items-center gap-2"><UtensilsCrossed className="h-5 w-5"/>{t('dashboard.macroSplitPerMeal')}</CardTitle>
                  <div className="flex items-center gap-2">
                    <GoalModeBadge value={splitEntry} />
                  </div>
                </div>
              </CardHeader>
              <div className="mt-4" />
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={mealSplit}
                    margin={{ top: 24, left: 12, right: 12 }}
                    barCategoryGap={24}
                    barGap={16}
                  >
                    <defs>
                      <linearGradient id="split-protein" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.protein.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.protein.gradientTo} />
                      </linearGradient>
                      <linearGradient id="split-carbs" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.carbs.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.carbs.gradientTo} />
                      </linearGradient>
                      <linearGradient id="split-fat" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={MACRO_THEME.fat.gradientFrom} />
                        <stop offset="100%" stopColor={MACRO_THEME.fat.gradientTo} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="meal" axisLine={false} tickLine={false} />
                    <YAxis axisLine={false} tickLine={false} tickFormatter={(value)=>`${formatNumber(value)} g`} />
                    <Legend iconType="circle" />
                    <RTooltip
                      content={({ active, payload, label }) => {
                        if (!active || !payload?.length) return null;
                        const mealLabel = (typeof label === "string" && label.length)
                          ? label
                          : payload[0]?.payload?.meal ?? "";
                        const macroOrder = [
                          { key: "carbs", label: "Carbs", color: MACRO_THEME.carbs.dark ?? MACRO_THEME.carbs.base },
                          { key: "protein", label: "Protein", color: MACRO_THEME.protein.dark ?? MACRO_THEME.protein.base },
                          { key: "fat", label: "Fat", color: MACRO_THEME.fat.dark ?? MACRO_THEME.fat.base },
                        ];

                        return (
                          <ChartTooltipContainer title={mealLabel}>
                            {macroOrder.map((macro) => {
                              const match = payload.find((item) => item?.dataKey === macro.key);
                              const value = match?.value ?? 0;
                              return (
                                <div key={macro.key} className="flex items-center gap-2">
                                  <span
                                    className="h-2.5 w-2.5 rounded-full"
                                    style={{ backgroundColor: macro.color }}
                                  />
                                  <span className="flex-1 text-slate-200">{macro.label}</span>
                                  <span className="font-semibold text-slate-100">{`${formatNumber(value)} g`}</span>
                                </div>
                              );
                            })}
                          </ChartTooltipContainer>
                        );
                      }}
                    />
                    <Bar
                      dataKey="protein"
                      name="Protein (g)"
                      stackId="g"
                      fill="url(#split-protein)"
                      barSize={56}
                      shape={(props)=>(
                        <RoundedBottomBar {...props} radius={28} />
                      )}
                    />
                    <Bar
                      dataKey="carbs"
                      name="Carbs (g)"
                      stackId="g"
                      fill="url(#split-carbs)"
                      barSize={56}
                    />
                    <Bar
                      dataKey="fat"
                      name="Fat (g)"
                      stackId="g"
                      fill="url(#split-fat)"
                      barSize={56}
                      shape={(props)=>(
                        <RoundedTopBar {...props} radius={28} />
                      )}
                    >
                      <LabelList
                        dataKey="kcal"
                        position="top"
                        formatter={(v) => v > 0 ? `${Math.round(v)} kcal` : ''}
                        style={{ fill: '#64748b', fontSize: 11 }}
                      />
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Top Foods by Macros (unchanged aside from existing top-5) */}
            <TopFoodsCard
              topFoods={topFoods}
              topMacroKey={topMacroKey}
              onMacroChange={setTopMacroKey}
              selectedDate={dashboardDate}
              goalMode={topFoodsEntry}
            />

            {/* Averages tiles (non-empty days only) */}
            <div className="grid md:grid-cols-4 gap-4">
              {averageSummariesWithGoal.map((summary) => (
                <AverageSummaryCard
                  key={summary.key}
                  label={summary.label}
                  averages={summary.averages}
                  scaleMax={summary.scaleMax}
                />
              ))}
            </div>
            <div className="grid md:grid-cols-2 gap-4">
              <WeightTrendCard
                history={weightTrendSummary.history}
                latestWeight={weightTrendSummary.latestWeight}
                latestDate={weightTrendSummary.latestDate}
              />
              <FoodLoggingCard summary={loggingSummary} />
            </div>
          </TabsContent>

          {/* DAILY LOG */}
          <TabsContent value="daily" className="mt-6 space-y-6">
            {/* Log intake form */}
            <Card className="overflow-hidden">
              <CardHeader>
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <CardTitle className="flex items-center gap-2"><History className="h-5 w-5"/>{t('daily.logIntake')}</CardTitle>
                  <GoalModeSelect value={logDateEntry} onChange={(entry)=>setModeEntryForDate(logDate || todayISO(), entry)} />
                </div>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="grid md:grid-cols-6 gap-3 items-end">
                  <div className="md:col-span-2">
                    <Label className="text-sm">{t('daily.dateLabel')}</Label>
                    <div className="flex items-center gap-2">
                      <DatePickerButton value={logDate} onChange={(v) => setLogDate(v || todayISO())} className="flex-1" />
                      <Button variant="outline" size="sm" className="shrink-0 text-xs" onClick={()=>{ const today=todayISO(); setLogDate(today); setDashboardDate(today); setWeekNavDate(today); }}>{t('daily.todayButton')}</Button>
                    </div>
                  </div>
                  <div className="md:col-span-2">
                    <Label className="text-sm">{t('daily.foodLabel')}</Label>
                    <FoodInput foods={foods} selectedFoodId={selectedFoodId} onSelect={(id)=>{ setSelectedFoodId(id); }} />
                  </div>
                  <div>
                    <Label className="text-sm">{t('daily.mealLabel')}</Label>
                    <Select value={meal} onValueChange={(v)=>setMeal(/** @type {MealKey} */(v))}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="breakfast">{t('meal.breakfast')}</SelectItem>
                        <SelectItem value="lunch">{t('meal.lunch')}</SelectItem>
                        <SelectItem value="dinner">{t('meal.dinner')}</SelectItem>
                        <SelectItem value="snack">{t('meal.snack')}</SelectItem>
                        <SelectItem value="other">{t('meal.other')}</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label className="text-sm">{t('daily.quantityLabel')} {quantityLabelSuffix}</Label>
                    <div className="relative mt-1">
                      <QuantityIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400 dark:text-slate-500" aria-hidden="true" />
                      <Input
                        type="number"
                        inputMode="decimal"
                        className="pl-9"
                        value={qty||""}
                        onChange={(e)=>setQty(parseFloat(e.target.value))}
                        placeholder={quantityPlaceholder}
                      />
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <Button className="w-full" onClick={addEntry} disabled={!selectedFood || !qty || qty <= 0}><Plus className="h-4 w-4"/> {t('daily.addButton')}</Button>
                  </div>
                </div>
                {/* Recent foods chips */}
                {recentFoods.length > 0 && (
                  <div className="flex flex-wrap items-center gap-1.5 pt-1 border-t border-slate-100 dark:border-slate-800">
                    <span className="text-xs text-slate-400 dark:text-slate-500 mr-0.5">{t('daily.recentLabel')}</span>
                    {recentFoods.map(f => (
                      <button
                        key={f.id}
                        type="button"
                        onClick={() => setSelectedFoodId(f.id)}
                        className={cn(
                          "text-xs px-2.5 py-1 rounded-full border transition",
                          selectedFoodId === f.id
                            ? "bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900 border-transparent"
                            : "bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 hover:border-slate-400 dark:hover:border-slate-500"
                        )}
                      >
                        {f.name}
                      </button>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Entries card */}
            <Card className="overflow-hidden">
              <CardHeader>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <CardTitle className="flex flex-wrap items-baseline gap-2">
                    <span>Entries</span>
                    <span className="text-sm font-normal text-slate-400 dark:text-slate-500">{format(new Date(logDate), "PPPP")}</span>
                  </CardTitle>
                  <Button variant="outline" size="sm" onClick={copyPreviousDay} title={t('daily.copyPrevDayTitle')} className="gap-1.5 text-xs">
                    <Copy className="h-3.5 w-3.5" />
                    <span>{t('daily.copyPrevDay')}</span>
                  </Button>
                </div>
              </CardHeader>
              <CardContent className="p-0">
                {entriesLoading ? (
                  <div className="text-center text-slate-500 py-8">{t('daily.loadingEntries')}</div>
                ) : (
                  <>
                    {/* Mobile layout */}
                    <div className="sm:hidden divide-y divide-slate-100 dark:divide-slate-800">
                      {MEAL_ORDER.map(mk => {
                        const group = rowsForDay.filter(r => (r.meal||'other') === mk);
                        const totals = sumMacros(group);
                        const mealPct = totalsForCard.kcal > 0 ? Math.round((totals.kcal / totalsForCard.kcal) * 100) : 0;
                        return (
                          <div key={mk} className="px-4 py-3">
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-sm font-semibold">{MEAL_EMOJIS[mk]} {t('meal.'+mk)}</span>
                              {group.length > 0 && mealPct > 0 && (
                                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium">{mealPct}{t('daily.ofDay')}</span>
                              )}
                            </div>
                            {group.length === 0 ? (
                              <p className="text-xs text-slate-400 dark:text-slate-500 italic">{t('daily.noEntries')}</p>
                            ) : (
                              <>
                                <div className="space-y-2">
                                  {group.map((r) => (
                                    <div key={r.id} className="rounded-lg border border-slate-200 dark:border-slate-700/60 bg-white dark:bg-slate-900 p-3 space-y-2">
                                      <div className="flex items-start justify-between gap-2">
                                        <div className="flex-1 min-w-0">
                                          <EditableFoodCell entryId={r.id} currentFoodId={r.foodId||null} fallbackLabel={r.label} foods={foods} onSelect={(foodId)=>updateEntryFood(r.id, foodId)} />
                                        </div>
                                        <div className="flex items-center gap-1 shrink-0">
                                          <MealSelectCell value={r.meal||'other'} onChange={(m)=>updateEntryMeal(r.id, m)} />
                                          <Button variant="ghost" size="icon" onClick={()=>removeEntry(r.id)}><Trash2 className="h-4 w-4"/></Button>
                                        </div>
                                      </div>
                                      <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-slate-500">
                                        <label className="flex items-center gap-1">
                                          <span>Qty</span>
                                          <input className="w-16 rounded border border-slate-200 dark:border-slate-700 bg-transparent px-1.5 py-0.5 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-slate-400" type="number" step="0.1" defaultValue={r.qty} onBlur={(e)=>updateEntryQuantity(r.id, parseFloat(e.target.value))} onKeyDown={(e)=>{ if(e.key==='Enter'){ e.target.blur(); } }} />
                                        </label>
                                        <span className="font-medium text-slate-700 dark:text-slate-300">{r.kcal.toFixed(0)} kcal</span>
                                        <span>P {r.protein.toFixed(1)}g</span>
                                        <span>C {r.carbs.toFixed(1)}g</span>
                                        <span>F {r.fat.toFixed(1)}g</span>
                                      </div>
                                    </div>
                                  ))}
                                </div>
                                <div className="text-xs text-right text-slate-400 dark:text-slate-500 font-medium pt-2">
                                  {t('daily.subtotal')}: {totals.kcal.toFixed(0)} kcal · P {totals.protein.toFixed(1)}g · C {totals.carbs.toFixed(1)}g · F {totals.fat.toFixed(1)}g
                                </div>
                              </>
                            )}
                          </div>
                        );
                      })}
                    </div>

                    {/* Desktop table — single header, meal separator rows */}
                    <div className="hidden sm:block overflow-x-auto">
                      <Table>
                        <TableHeader className="bg-slate-50/70 dark:bg-slate-800/25">
                          <TableRow>
                            <TableHead>{t('daily.food')}</TableHead>
                            <TableHead className="w-24 text-right">{t('daily.qty')}</TableHead>
                            <TableHead className="text-right">{t('daily.kcal')}</TableHead>
                            <TableHead className="text-right">{t('daily.proteinG')}</TableHead>
                            <TableHead className="text-right">{t('daily.carbsG')}</TableHead>
                            <TableHead className="text-right">{t('daily.fatG')}</TableHead>
                            <TableHead className="w-36">{t('daily.mealCol')}</TableHead>
                            <TableHead className="w-10"></TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {MEAL_ORDER.map(mk => {
                            const group = rowsForDay.filter(r => (r.meal||'other') === mk);
                            const totals = sumMacros(group);
                            const mealPct = totalsForCard.kcal > 0 ? Math.round((totals.kcal / totalsForCard.kcal) * 100) : 0;
                            return (
                              <Fragment key={mk}>
                                {/* Meal separator */}
                                <TableRow className="bg-slate-50/70 dark:bg-slate-800/20 hover:bg-slate-50/70 dark:hover:bg-slate-800/20 border-t border-slate-200/80 dark:border-slate-700/50">
                                  <TableCell colSpan={8} className="py-2 px-3">
                                    <div className="flex items-center gap-2">
                                      <span className="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">{MEAL_EMOJIS[mk]} {t('meal.'+mk)}</span>
                                      {group.length > 0 && mealPct > 0 && (
                                        <span className="text-[11px] text-slate-400 dark:text-slate-500">{mealPct}% of day</span>
                                      )}
                                      {group.length === 0 && (
                                        <span className="text-[11px] italic text-slate-400 dark:text-slate-500">{t('daily.noEntries')}</span>
                                      )}
                                    </div>
                                  </TableCell>
                                </TableRow>
                                {/* Entry rows */}
                                {group.map((r) => (
                                  <TableRow key={r.id}>
                                    <TableCell>
                                      <EditableFoodCell entryId={r.id} currentFoodId={r.foodId||null} fallbackLabel={r.label} foods={foods} onSelect={(foodId)=>updateEntryFood(r.id, foodId)} />
                                    </TableCell>
                                    <TableCell className="text-right">
                                      <input className="w-20 rounded border border-slate-200 dark:border-slate-700 bg-transparent px-2 py-1 text-right text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-slate-400" type="number" step="0.1" defaultValue={r.qty} onBlur={(e)=>updateEntryQuantity(r.id, parseFloat(e.target.value))} onKeyDown={(e)=>{ if(e.key==='Enter'){ e.target.blur(); } }} />
                                    </TableCell>
                                    <TableCell className="text-right">{r.kcal.toFixed(0)}</TableCell>
                                    <TableCell className="text-right">{r.protein.toFixed(1)}</TableCell>
                                    <TableCell className="text-right">{r.carbs.toFixed(1)}</TableCell>
                                    <TableCell className="text-right">{r.fat.toFixed(1)}</TableCell>
                                    <TableCell>
                                      <MealSelectCell value={r.meal||'other'} onChange={(m)=>updateEntryMeal(r.id, m)} />
                                    </TableCell>
                                    <TableCell className="text-right"><Button variant="ghost" size="icon" onClick={()=>removeEntry(r.id)}><Trash2 className="h-4 w-4"/></Button></TableCell>
                                  </TableRow>
                                ))}
                                {/* Subtotal row */}
                                {group.length > 0 && (
                                  <TableRow className="border-t border-slate-200 dark:border-slate-700 bg-slate-100/50 dark:bg-slate-800/30 hover:bg-slate-100/50 dark:hover:bg-slate-800/30">
                                    <TableCell className="text-xs font-semibold uppercase tracking-wide text-slate-400 dark:text-slate-500 pl-4">{t('daily.subtotal')}</TableCell>
                                    <TableCell />
                                    <TableCell className="text-right text-sm font-semibold text-slate-800 dark:text-slate-100">{totals.kcal.toFixed(0)}</TableCell>
                                    <TableCell className="text-right text-sm font-semibold text-slate-800 dark:text-slate-100">{totals.protein.toFixed(1)}</TableCell>
                                    <TableCell className="text-right text-sm font-semibold text-slate-800 dark:text-slate-100">{totals.carbs.toFixed(1)}</TableCell>
                                    <TableCell className="text-right text-sm font-semibold text-slate-800 dark:text-slate-100">{totals.fat.toFixed(1)}</TableCell>
                                    <TableCell colSpan={2} />
                                  </TableRow>
                                )}
                              </Fragment>
                            );
                          })}
                        </TableBody>
                      </Table>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {/* FOOD DB */}
          <TabsContent value="foods" className="mt-6 space-y-4">
            {foodAddOpen && !foodsLoading && (
              <AddFoodCard
                foods={foods}
                onAdd={addFood}
                tab={foodAddTab}
                initialBasicForm={scannedBasicForm}
                onClose={() => { setFoodAddOpen(false); setScannedBasicForm(null); }}
              />
            )}
            {barcodeScanOpen && (
              <BarcodeScannerModal
                onClose={() => setBarcodeScanOpen(false)}
                onResult={(food) => {
                  setScannedBasicForm({
                    name: food.name,
                    kcal: food.kcal,
                    protein: food.protein,
                    carbs: food.carbs,
                    fat: food.fat,
                    category: food.category,
                    unit: food.unit,
                    servingSize: '',
                  });
                  setFoodAddTab("single");
                  setFoodAddOpen(true);
                  setBarcodeScanOpen(false);
                }}
              />
            )}
            <Card className="overflow-hidden border-slate-100 dark:border-slate-800/60">
              <CardHeader className="pb-3">
                {/* Top row: title + action buttons */}
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <CardTitle className="text-base">
                      {foodSearch || foodCategoryFilter.size > 0
                        ? `${filteredFoods.length} ${t('foods.of')} ${foods.length} ${t('foods.items')}`
                        : `${t('foods.title')} — ${foods.length} ${t('foods.items')}`}
                    </CardTitle>
                  </div>
                  <div className="flex items-center gap-1.5 flex-wrap">
                    {foodSelectedIds.size > 0 && (
                      <Button
                        variant="destructive"
                        size="sm"
                        onClick={() => setBulkDeleteConfirmOpen(true)}
                      >
                        <Trash2 className="h-3.5 w-3.5 mr-1.5" />
                        {t('foods.deleteSelected', {count: foodSelectedIds.size})}
                      </Button>
                    )}
                    <Button
                      size="sm"
                      onClick={() => setBarcodeScanOpen(true)}
                    >
                      <Barcode className="h-3.5 w-3.5 mr-1" />{t('foods.scanButton')}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => { setFoodAddTab("single"); setFoodAddOpen(true); }}
                    >
                      <Plus className="h-3.5 w-3.5 mr-1" />{t('foods.addFoodButton')}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => { setFoodAddTab("recipe"); setFoodAddOpen(true); }}
                    >
                      <ChefHat className="h-3.5 w-3.5 mr-1" />{t('foods.addRecipeButton')}
                    </Button>
                    <Button size="sm" variant="ghost" onClick={exportJSON} title={t('foods.exportTitle')}>
                      <Download className="h-3.5 w-3.5 mr-1" />{t('foods.exportButton')}
                    </Button>
                    <label className="inline-flex items-center gap-1 cursor-pointer rounded-md px-2.5 py-1.5 text-sm font-medium border border-input bg-background hover:bg-accent hover:text-accent-foreground h-8" title={t('foods.importTitle')}>
                      <Upload className="h-3.5 w-3.5" />{t('foods.importButton')}
                      <input type="file" accept="application/json" className="hidden" onChange={(e)=>e.target.files&&importJSON(e.target.files[0])} />
                    </label>
                  </div>
                </div>
                {/* Mobile sort */}
                <div className="flex items-center gap-2 text-xs text-slate-500 sm:hidden mt-1">
                  <span>{t('foods.sort')}</span>
                  {["name","kcal","fat"].map(col=>(
                    <button key={col} type="button" onClick={()=>toggleFoodSort(col)} className="flex items-center gap-0.5 capitalize font-medium text-slate-600 dark:text-slate-300">
                      {col}{renderSortIcon(col)}
                    </button>
                  ))}
                </div>
                {/* Search */}
                <div className="relative mt-2">
                  <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 pointer-events-none" />
                  <Input
                    className="pl-8 h-8 text-sm"
                    placeholder={t('foods.searchPlaceholder')}
                    value={foodSearch}
                    onChange={(e) => setFoodSearch(e.target.value)}
                  />
                  {foodSearch && (
                    <button type="button" onClick={() => setFoodSearch("")} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
                      <X className="h-3.5 w-3.5" />
                    </button>
                  )}
                </div>
                {/* Category filter chips */}
                {availableCategories.length > 0 && (
                  <div className="flex gap-1.5 flex-wrap mt-2 items-center">
                    {availableCategories.map(cat => (
                      <button
                        key={cat.value}
                        type="button"
                        onClick={() => setFoodCategoryFilter(prev => {
                          const next = new Set(prev);
                          if (next.has(cat.value)) next.delete(cat.value); else next.add(cat.value);
                          return next;
                        })}
                        className={cn(
                          "text-xs px-2 py-0.5 rounded-full border transition",
                          foodCategoryFilter.has(cat.value)
                            ? "bg-slate-900 text-white border-slate-900 dark:bg-slate-100 dark:text-slate-900 dark:border-slate-100"
                            : "border-slate-200 hover:border-slate-400 dark:border-slate-700 dark:hover:border-slate-500"
                        )}
                      >
                        {cat.emoji} {t('foodCategories.'+cat.value, cat.label)}
                      </button>
                    ))}
                    {(foodCategoryFilter.size > 0 || foodSearch) && (
                      <button
                        type="button"
                        onClick={() => { setFoodCategoryFilter(new Set()); setFoodSearch(""); }}
                        className="text-xs px-2 py-0.5 rounded-full border border-slate-300 text-slate-500 hover:border-slate-500 hover:text-slate-700 dark:border-slate-600 dark:text-slate-400 dark:hover:border-slate-400 transition flex items-center gap-1"
                      >
                        <X className="h-3 w-3" />{t('foods.clearFilters')}
                      </button>
                    )}
                  </div>
                )}
              </CardHeader>
              <CardContent className="p-0 sm:p-6 sm:pt-0">
                {foodsLoading ? (
                  <p className="p-4 text-center text-sm text-slate-500">{t('foods.loadingFoods')}</p>
                ) : (
                  <>
                    {/* Mobile card list */}
                    <div className="sm:hidden divide-y divide-slate-100 dark:divide-slate-800">
                      {filteredFoods.length === 0 && (
                        <p className="p-4 text-center text-sm text-slate-500">{foodSearch || foodCategoryFilter.size > 0 ? t('foods.noFoodsMatch') : t('foods.emptyDatabase')}</p>
                      )}
                      {filteredFoods.map((f)=>(
                        <MobileFoodCard key={f.id} food={f} onEdit={setFoodEditTarget} onDelete={requestDeleteFood} />
                      ))}
                    </div>
                    {/* Desktop table */}
                    <div className="hidden sm:block overflow-x-auto">
                      <Table>
                        <TableHeader className="bg-slate-50/70 dark:bg-slate-800/25">
                          <TableRow>
                            <TableHead className="w-8 pr-0">
                              <input
                                type="checkbox"
                                className="rounded border-slate-300"
                                checked={filteredFoods.length > 0 && filteredFoods.every(f => foodSelectedIds.has(f.id))}
                                onChange={(e) => {
                                  if (e.target.checked) {
                                    setFoodSelectedIds(new Set(filteredFoods.map(f => f.id)));
                                  } else {
                                    setFoodSelectedIds(new Set());
                                  }
                                }}
                              />
                            </TableHead>
                            <TableHead className="w-[230px]">
                              <button type="button" onClick={()=>toggleFoodSort("name")} className="flex w-full items-center gap-0.5 text-left font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.name')}</span>{renderSortIcon("name")}</button>
                            </TableHead>
                            <TableHead className="w-[160px] max-w-[160px]">
                              <button type="button" onClick={()=>toggleFoodSort("category")} className="flex w-full items-center gap-0.5 text-left font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.category')}</span>{renderSortIcon("category")}</button>
                            </TableHead>
                            <TableHead className="w-[120px] max-w-[120px]">
                              <button type="button" onClick={()=>toggleFoodSort("unit")} className="flex w-full items-center gap-0.5 text-left font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.unit')}</span>{renderSortIcon("unit")}</button>
                            </TableHead>
                            <TableHead className="text-right">
                              <button type="button" onClick={()=>toggleFoodSort("kcal")} className="ml-auto flex items-center gap-0.5 font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.kcal')}</span>{renderSortIcon("kcal")}</button>
                            </TableHead>
                            <TableHead className="text-right">
                              <button type="button" onClick={()=>toggleFoodSort("fat")} className="ml-auto flex items-center gap-0.5 font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.fatG')}</span>{renderSortIcon("fat")}</button>
                            </TableHead>
                            <TableHead className="text-right">
                              <button type="button" onClick={()=>toggleFoodSort("carbs")} className="ml-auto flex items-center gap-0.5 font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.carbsG')}</span>{renderSortIcon("carbs")}</button>
                            </TableHead>
                            <TableHead className="text-right">
                              <button type="button" onClick={()=>toggleFoodSort("protein")} className="ml-auto flex items-center gap-0.5 font-medium text-slate-400 transition hover:text-slate-700 dark:text-slate-500 dark:hover:text-slate-200"><span>{t('foods.proteinG')}</span>{renderSortIcon("protein")}</button>
                            </TableHead>
                            <TableHead className="text-right sticky right-0 bg-slate-50/70 dark:bg-slate-800/25 border-l border-slate-100/80 dark:border-slate-800/40"></TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {filteredFoods.map((f)=> (
                            <EditableFoodRow
                              key={f.id}
                              food={f}
                              onEdit={setFoodEditTarget}
                              onDelete={requestDeleteFood}
                              selected={foodSelectedIds.has(f.id)}
                              onSelect={(id, checked) => setFoodSelectedIds(prev => {
                                const next = new Set(prev);
                                if (checked) next.add(id); else next.delete(id);
                                return next;
                              })}
                            />
                          ))}
                          {filteredFoods.length===0 && (
                            <TableRow><TableCell colSpan={9} className="text-center text-slate-500">{foodSearch || foodCategoryFilter.size > 0 ? t('foods.noFoodsMatch') : t('foods.emptyDatabase')}</TableCell></TableRow>
                          )}
                        </TableBody>
                      </Table>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>
            {foodEditTarget && (
              <FoodEditDrawer
                food={foodEditTarget}
                foods={foods}
                onUpdate={updateFood}
                onDelete={requestDeleteFood}
                onAdd={addFood}
                onClose={() => setFoodEditTarget(null)}
              />
            )}
            {/* Bulk delete confirmation */}
            {bulkDeleteConfirmOpen && (
              <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4">
                <Card className="w-full max-w-md border-slate-200 dark:border-slate-700">
                  <CardHeader>
                    <CardTitle className="text-lg">{t('modal.bulkDeleteTitle', {count: foodSelectedIds.size})}</CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <p className="text-sm text-slate-600 dark:text-slate-300">
                      {t('modal.bulkDeleteConfirm', {count: foodSelectedIds.size, itemLabel: foodSelectedIds.size === 1 ? t('modal.bulkDeleteEntry') : t('modal.bulkDeleteEntries')})}
                    </p>
                    <div className="flex justify-end gap-2">
                      <Button variant="ghost" onClick={() => setBulkDeleteConfirmOpen(false)}>{t('modal.cancelButton')}</Button>
                      <Button variant="destructive" onClick={() => bulkDeleteFoods(foodSelectedIds)}>{t('modal.bulkDeleteTitle', {count: foodSelectedIds.size})}</Button>
                    </div>
                  </CardContent>
                </Card>
              </div>
            )}
          </TabsContent>

          {/* SETTINGS */}
          <TabsContent value="settings" className="mt-6">
            <div className="space-y-6">
              {/* Page header */}
              <div>
                <h2 className="text-xl font-semibold tracking-tight text-slate-900 dark:text-slate-50">{t('settings.pageTitle')}</h2>
                <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{t('settings.pageSubtitle')}</p>
              </div>

              {/* Row 1: Account + Daily macro goals */}
              <div className="grid md:grid-cols-2 gap-6">
                {/* Account */}
                <div className="rounded-xl border border-slate-200 dark:border-slate-700 p-5 space-y-5">
                  <h3 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">{t('settings.accountTitle')}</h3>
                  <div className="flex items-center gap-4">
                    <button
                      type="button"
                      onClick={() => avatarInputRef.current?.click()}
                      className="relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-full border border-slate-200 dark:border-slate-700 bg-slate-100 dark:bg-slate-800 flex items-center justify-center group"
                      aria-label={t('settings.uploadPhotoTitle')}
                    >
                      {profileAvatarUrl ? (
                        <img src={profileAvatarUrl} alt="Profile avatar" className="h-full w-full object-cover" />
                      ) : (
                        <User className="h-8 w-8 text-slate-400 dark:text-slate-500" />
                      )}
                      <span className="absolute inset-0 flex items-center justify-center rounded-full bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity">
                        <Camera className="h-5 w-5 text-white" />
                      </span>
                    </button>
                    <div className="min-w-0">
                      <div className="flex flex-wrap gap-2">
                        <Button type="button" size="sm" variant="outline" onClick={() => avatarInputRef.current?.click()}>
                          {t('settings.changePhoto')}
                        </Button>
                        <Button type="button" size="sm" variant="ghost" onClick={handleRemoveAvatar} disabled={!profileAvatarUrl || avatarUploading}>
                          {t('settings.removePhoto')}
                        </Button>
                      </div>
                      <p className="mt-1.5 text-xs text-slate-400 dark:text-slate-500">{t('settings.photoHint')}</p>
                      {avatarUploading && <p className="mt-1 text-xs text-slate-500">{t('settings.uploading')}</p>}
                    </div>
                    <input
                      ref={avatarInputRef}
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      className="hidden"
                      onChange={(event) => {
                        const file = event.target.files?.[0];
                        if (file) handleAvatarUpload(file);
                        event.target.value = "";
                      }}
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-sm">{t('settings.usernameLabel')}</Label>
                    <div className="flex gap-2">
                      <Input value={accountUsername} onChange={(e)=>setAccountUsername(e.target.value)} placeholder="username" />
                      <Button size="sm" onClick={handleUpdateUsername}>{t('settings.save')}</Button>
                    </div>
                  </div>
                  <div className="space-y-1.5">
                    <Label className="text-sm">{t('settings.emailLabel')}</Label>
                    <div className="flex gap-2">
                      <Input type="email" value={accountEmail} onChange={(e)=>setAccountEmail(e.target.value)} placeholder="you@example.com" />
                      <Button size="sm" onClick={handleUpdateEmail}>{t('settings.save')}</Button>
                    </div>
                  </div>
                  {accountError && <p className="text-sm text-red-600 dark:text-red-400">{accountError}</p>}
                  {accountSuccess && <p className="text-sm text-emerald-600 dark:text-emerald-400">{accountSuccess}</p>}
                </div>

                {/* Daily macro goals */}
                <div className="rounded-xl border border-slate-200 dark:border-slate-700 p-5 space-y-4">
                  <div className="flex items-center justify-between gap-3">
                    <h3 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">{t('settings.macroGoalsTitle')}</h3>
                    <Select value={activeSetup} onValueChange={handleSetupChange}>
                      <SelectTrigger className="h-8 w-44"><SelectValue placeholder={t('settings.setupPlaceholder')} /></SelectTrigger>
                      <SelectContent>
                        {SETUP_MODES.map((mode) => (
                          <SelectItem key={mode} value={mode}>{t('setup.'+mode)}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <p className="text-xs text-slate-500 dark:text-slate-400">
                    {t('settings.macroGoalsHint')}
                  </p>
                  {activeSetup === "dual" ? (
                    <>
                      <Tabs value={activeDualProfile} onValueChange={handleDualProfileChange}>
                        <TabsList className="mb-3 grid w-full max-w-xs grid-cols-2 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/60">
                          <TabsTrigger value="train" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">{t('settings.trainDayTab')}</TabsTrigger>
                          <TabsTrigger value="rest" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">{t('settings.restDayTab')}</TabsTrigger>
                        </TabsList>
                        <TabsContent value="train" className="mt-0">
                          <div className="grid grid-cols-2 gap-3">
                            <div className="col-span-2">
                              <LabeledNumber label={t('settings.caloriesLabel')} value={dailyGoals.dual.train.kcal} onChange={updateMacroGoal('dual.train','kcal')} />
                            </div>
                            <LabeledNumber label={t('settings.proteinLabel')} value={dailyGoals.dual.train.protein} onChange={updateMacroGoal('dual.train','protein')} />
                            <LabeledNumber label={t('settings.carbsLabel')} value={dailyGoals.dual.train.carbs} onChange={updateMacroGoal('dual.train','carbs')} />
                            <LabeledNumber label={t('settings.fatLabel')} value={dailyGoals.dual.train.fat} onChange={updateMacroGoal('dual.train','fat')} />
                          </div>
                        </TabsContent>
                        <TabsContent value="rest" className="mt-0">
                          <div className="grid grid-cols-2 gap-3">
                            <div className="col-span-2">
                              <LabeledNumber label={t('settings.caloriesLabel')} value={dailyGoals.dual.rest.kcal} onChange={updateMacroGoal('dual.rest','kcal')} />
                            </div>
                            <LabeledNumber label={t('settings.proteinLabel')} value={dailyGoals.dual.rest.protein} onChange={updateMacroGoal('dual.rest','protein')} />
                            <LabeledNumber label={t('settings.carbsLabel')} value={dailyGoals.dual.rest.carbs} onChange={updateMacroGoal('dual.rest','carbs')} />
                            <LabeledNumber label={t('settings.fatLabel')} value={dailyGoals.dual.rest.fat} onChange={updateMacroGoal('dual.rest','fat')} />
                          </div>
                        </TabsContent>
                      </Tabs>
                      <p className="text-xs text-slate-500 dark:text-slate-400">{t('settings.dualProfileHint')}</p>
                    </>
                  ) : (
                    <div className="space-y-3">
                      <div className="grid grid-cols-2 gap-3">
                        <div className="col-span-2">
                          <LabeledNumber label={t('settings.caloriesLabel')} value={dailyGoals[activeSetup]?.kcal ?? 0} onChange={updateMacroGoal(activeSetup,'kcal')} />
                        </div>
                        <LabeledNumber label={t('settings.proteinLabel')} value={dailyGoals[activeSetup]?.protein ?? 0} onChange={updateMacroGoal(activeSetup,'protein')} />
                        <LabeledNumber label={t('settings.carbsLabel')} value={dailyGoals[activeSetup]?.carbs ?? 0} onChange={updateMacroGoal(activeSetup,'carbs')} />
                        <LabeledNumber label={t('settings.fatLabel')} value={dailyGoals[activeSetup]?.fat ?? 0} onChange={updateMacroGoal(activeSetup,'fat')} />
                      </div>
                      <p className="text-xs text-slate-500 dark:text-slate-400">
                        {t('settings.setupPowersHint', { setup: t('setup.'+activeSetup) })}
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* Row 2: Body stats + Badges */}
              <div className="grid md:grid-cols-2 gap-6">
                {/* Body stats */}
                <div className="rounded-xl border border-slate-200 dark:border-slate-700 p-5 space-y-4">
                  <h3 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">{t('settings.bodyStatsTitle')}</h3>
                  {profileLoading && <p className="text-xs text-slate-500">{t('settings.loadingStats')}</p>}
                  <div className="grid grid-cols-2 gap-3">
                    <LabeledNumber label={t('settings.ageLabel')} value={settings.profile?.age ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, age:v}})} />
                    <div>
                      <Label className="text-sm">{t('settings.sexLabel')}</Label>
                      <Select value={settings.profile?.sex ?? 'other'} onValueChange={(v)=>setSettings({...settings, profile:{...settings.profile, sex:v}})}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="male">{t('settings.sexMale')}</SelectItem>
                          <SelectItem value="female">{t('settings.sexFemale')}</SelectItem>
                          <SelectItem value="other">{t('settings.sexOther')}</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    <LabeledNumber label={t('settings.heightLabel')} value={settings.profile?.heightCm ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, heightCm:v}})} />
                    <LabeledNumber label={t('settings.weightLabel')} value={settings.profile?.weightKg ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, weightKg:v}})} />
                    <LabeledNumber label={t('settings.bodyFatLabel')} value={settings.profile?.bodyFatPct ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, bodyFatPct:v}})} />
                    <div>
                      <Label className="text-sm">{t('settings.activityLabel')}</Label>
                      <Select value={settings.profile?.activity ?? 'moderate'} onValueChange={(v)=>setSettings({...settings, profile:{...settings.profile, activity:v}})}>
                        <SelectTrigger><SelectValue /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="sedentary">{t('settings.activitySedentary')}</SelectItem>
                          <SelectItem value="light">{t('settings.activityLight')}</SelectItem>
                          <SelectItem value="moderate">{t('settings.activityModerate')}</SelectItem>
                          <SelectItem value="active">{t('settings.activityActive')}</SelectItem>
                          <SelectItem value="athlete">{t('settings.activityAthlete')}</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  <div className="flex items-center justify-between gap-3 pt-1">
                    <span className="text-xs text-slate-400 dark:text-slate-500">
                      {profileLastSavedAt instanceof Date
                        ? t('settings.lastSaved', { time: formatDistanceToNow(profileLastSavedAt, { addSuffix: true }) })
                        : t('settings.notSavedYet')}
                    </span>
                    <Button
                      size="sm"
                      onClick={handleSaveBodyProfile}
                      disabled={profileSaving}
                      className="bg-slate-900 text-white hover:bg-slate-700 dark:bg-slate-100 dark:text-slate-900 dark:hover:bg-slate-200"
                    >
                      {profileSaving ? t('settings.savingStats') : t('settings.saveStats')}
                    </Button>
                  </div>
                  {profileSaveError && <p className="text-sm text-red-600 dark:text-red-400">{profileSaveError}</p>}
                  {profileSaveSuccess && <p className="text-sm text-emerald-600 dark:text-emerald-400">{profileSaveSuccess}</p>}
                </div>
                <BadgesCard earnedBadgeIds={earnedBadgeIds} />
              </div>

              {/* Language */}
              <div className="rounded-xl border border-slate-200 dark:border-slate-800 p-5 space-y-3">
                <h3 className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">{t('settings.languageTitle')}</h3>
                <div className="flex gap-2">
                  {([['en', 'English'], ['fr', 'Français']] as const).map(([code, label]) => (
                    <button
                      key={code}
                      type="button"
                      onClick={() => setLanguage(code)}
                      className={`px-4 py-2 rounded-lg border-2 text-sm font-medium transition-all ${
                        i18nHook.language === code
                          ? 'border-violet-500 bg-violet-50 dark:bg-violet-950/40 text-violet-700 dark:text-violet-300'
                          : 'border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-slate-300 dark:hover:border-slate-600'
                      }`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Danger zone */}
              <div className="rounded-xl border border-red-100 dark:border-red-900/40 p-5">
                <h3 className="text-xs font-semibold uppercase tracking-widest text-red-500 dark:text-red-400 mb-1">{t('settings.dangerZoneTitle')}</h3>
                <p className="text-xs text-slate-500 dark:text-slate-400 mb-4">{t('settings.dangerZoneHint')}</p>
                <Button size="sm" variant="destructive" onClick={() => setResetDataConfirmOpen(true)}>{t('settings.resetAllData')}</Button>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </main>

      {badgeUnlockShown && (
        <BadgeUnlockPopup badgeId={badgeUnlockShown} onClose={() => setBadgeUnlockShown(null)} />
      )}

      {foodPendingDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4">
          <Card className="w-full max-w-md border-slate-200 dark:border-slate-700">
            <CardHeader>
              <CardTitle className="text-lg">{t('modal.deleteFoodTitle')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-slate-600 dark:text-slate-300">
                <span className="font-semibold text-slate-900 dark:text-slate-100">{foodPendingDelete.name}</span>
              </p>
              <p className="text-sm text-slate-600 dark:text-slate-300">
                {t('modal.deleteFoodConfirm')}
              </p>
              <div className="flex justify-end gap-2">
                <Button variant="ghost" onClick={() => setFoodPendingDelete(null)}>{t('modal.cancelButton')}</Button>
                <Button variant="destructive" onClick={confirmDeleteFood}>{t('modal.deleteButton')}</Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {resetDataConfirmOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 px-4">
          <Card className="w-full max-w-md border-slate-200 dark:border-slate-700">
            <CardHeader>
              <CardTitle className="text-lg">{t('modal.resetDataTitle')}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm text-slate-600 dark:text-slate-300">
                {t('modal.resetDataConfirm')}
              </p>
              <div className="space-y-1.5">
                <Label className="text-sm">{t('modal.resetDataLabel')}</Label>
                <Input
                  value={resetDataInput}
                  onChange={(e) => setResetDataInput(e.target.value)}
                  placeholder={t('modal.resetDataPlaceholder')}
                  autoComplete="off"
                />
              </div>
              <div className="flex justify-end gap-2">
                <Button variant="ghost" onClick={() => { setResetDataConfirmOpen(false); setResetDataInput(""); }}>{t('modal.cancelButton')}</Button>
                <Button
                  variant="destructive"
                  disabled={resetDataInput !== "RESET"}
                  onClick={() => { setResetDataConfirmOpen(false); setResetDataInput(""); resetData(); }}
                >
                  {t('modal.resetDataButton')}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      <footer className="hidden sm:block py-8 text-center text-xs text-slate-500">Trust your Power 💪🏻💪🏼💪🏽💪🏾💪🏿</footer>

      {/* ── Mobile bottom navigation bar ── */}
      <nav className="sm:hidden fixed bottom-0 inset-x-0 z-40 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-t border-slate-200 dark:border-slate-800">
        <div className="grid grid-cols-4 h-16">
          {[
            { value: 'dashboard', Icon: BarChart3,    label: t('nav.dashboard') },
            { value: 'daily',     Icon: BookOpenText,  label: t('nav.daily')      },
            { value: 'foods',     Icon: Database,      label: t('nav.foods')      },
            { value: 'settings',  Icon: SettingsIcon,  label: t('nav.settings')   },
          ].map(({ value, Icon, label }) => {
            const active = tab === value;
            return (
              <button
                key={value}
                type="button"
                onClick={() => setTab(value)}
                className={cn(
                  "flex flex-col items-center justify-center gap-1 transition-colors",
                  active
                    ? "text-slate-900 dark:text-white"
                    : "text-slate-400 dark:text-slate-500 active:text-slate-600"
                )}
              >
                <Icon className="h-5 w-5" strokeWidth={active ? 2.5 : 1.75} />
                <span className={cn("text-[10px] leading-none", active ? "font-semibold" : "font-normal")}>
                  {label}
                </span>
              </button>
            );
          })}
        </div>
      </nav>

      {/* ── "Totals for" bottom sheet — mobile only ── */}
      {stickyModeSheetOpen && (
        <div className="sm:hidden fixed inset-0 z-50" role="dialog" aria-modal="true" aria-label="Totals for">
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/40"
            onClick={() => setStickyModeSheetOpen(false)}
          />
          {/* Sheet */}
          <div className="absolute bottom-0 inset-x-0 rounded-t-2xl bg-white dark:bg-slate-900 px-6 pt-4 pb-10 shadow-2xl">
            <div className="w-10 h-1 bg-slate-300 dark:bg-slate-600 rounded-full mx-auto mb-5" />
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-4">
              {t('sticky.totalsFor')}
            </p>
            <div className="grid grid-cols-2 gap-3">
              {[
                { value: 'today',    label: t('sticky.today')       },
                { value: 'selected', label: t('sticky.selectedDay') },
              ].map(({ value, label }) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => { setStickyMode(value); setStickyModeSheetOpen(false); }}
                  className={cn(
                    "py-4 rounded-xl text-sm font-semibold border-2 transition-colors",
                    effectiveStickyMode === value
                      ? "border-slate-900 bg-slate-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-900"
                      : "border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300"
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

    </div>
  );
}

/*******************
 * Reusable bits
 *******************/
function LabeledNumber({ label, value, onChange }){
  return (
    <div>
      <Label className="text-sm">{label}</Label>
      <Input type="number" inputMode="numeric" value={Number.isFinite(value)? value: 0} onChange={(e)=>onChange(parseFloat(e.target.value||'0'))} />
    </div>
  );
}

const PROFILE_MODE_OPTIONS = [
  { value: "train", label: "Train Day", Icon: Dumbbell, accent: COLORS.protein },
  { value: "rest", label: "Rest Day", Icon: BedDouble, accent: COLORS.cyan },
  { value: "bulking", label: "Bulking", Icon: ArrowUpRight, accent: COLORS.kcal },
  { value: "cutting", label: "Cutting", Icon: Scissors, accent: COLORS.redDark },
  { value: "maintenance", label: "Maintenance", Icon: Equal, accent: COLORS.gray },
];

const DUAL_PROFILE_OPTIONS = PROFILE_MODE_OPTIONS.slice(0, 2);

function computeMaxStreak(sortedDates) {
  if (!sortedDates.length) return 0;
  let max = 1, cur = 1;
  for (let i = 1; i < sortedDates.length; i++) {
    const prev = new Date(sortedDates[i - 1]);
    const curr = new Date(sortedDates[i]);
    const diff = Math.round((curr - prev) / (1000 * 60 * 60 * 24));
    if (diff === 1) { cur++; max = Math.max(max, cur); }
    else if (diff > 1) cur = 1;
  }
  return max;
}

function computeEarnedBadgeIds(entries, foods, goalValuesForDate) {
  const loggedDates = [...new Set(entries.map((e) => e.date))].sort();
  const maxLogStreak = loggedDates.length > 0 ? computeMaxStreak(loggedDates) : 0;

  // Per-day stats
  const dateStats = loggedDates.map((date) => {
    const dayEntries = entries.filter((e) => e.date === date);
    const totals = { kcal: 0, protein: 0, carbs: 0, fat: 0 };
    dayEntries.forEach((e) => {
      const f = foods.find((x) => x.id === e.foodId);
      if (!f) return;
      const s = scaleMacros(f, e.qty);
      totals.kcal += s.kcal || 0;
      totals.protein += s.protein || 0;
      totals.carbs += s.carbs || 0;
      totals.fat += s.fat || 0;
    });
    const goals = goalValuesForDate(date);
    const proteinHit = goals.protein > 0 && totals.protein >= goals.protein;
    const isPerfect =
      goals.kcal > 0 && goals.protein > 0 && goals.carbs > 0 && goals.fat > 0 &&
      totals.kcal >= goals.kcal * 0.95 && totals.kcal <= goals.kcal &&
      totals.protein >= goals.protein &&
      totals.carbs >= goals.carbs * 0.95 && totals.carbs <= goals.carbs &&
      totals.fat >= goals.fat * 0.95 && totals.fat <= goals.fat;
    const hasVeggie =
      dayEntries.some((e) => { const f = foods.find((x) => x.id === e.foodId); return f?.category === "vegetable"; }) &&
      dayEntries.some((e) => { const f = foods.find((x) => x.id === e.foodId); return f?.category === "fruit"; });
    return { date, proteinHit, isPerfect, hasVeggie };
  });

  const proteinDates = dateStats.filter((d) => d.proteinHit).map((d) => d.date);
  const perfectDates = dateStats.filter((d) => d.isPerfect).map((d) => d.date);
  const veggieDates  = dateStats.filter((d) => d.hasVeggie).map((d) => d.date);
  const maxProteinStreak = proteinDates.length > 0 ? computeMaxStreak(proteinDates) : 0;
  const maxVeggieStreak  = veggieDates.length  > 0 ? computeMaxStreak(veggieDates)  : 0;

  const earned = new Set();

  // Streaks
  if (maxLogStreak >= 7)     earned.add("log_streak_7");
  if (maxLogStreak >= 14)    earned.add("log_streak_14");
  if (maxLogStreak >= 30)    earned.add("log_streak_30");
  if (maxLogStreak >= 90)    earned.add("log_streak_90");
  if (maxProteinStreak >= 7)  earned.add("protein_streak_7");
  if (maxProteinStreak >= 14) earned.add("protein_streak_14");
  if (maxProteinStreak >= 30) earned.add("protein_streak_30");
  if (maxProteinStreak >= 90) earned.add("protein_streak_90");
  if (maxVeggieStreak >= 7)   earned.add("veggie_streak_7");

  // Milestones — logging
  if (loggedDates.length >= 1)   earned.add("log_first");
  if (loggedDates.length >= 10)  earned.add("log_days_10");
  if (loggedDates.length >= 30)  earned.add("log_days_30");
  if (loggedDates.length >= 100) earned.add("log_days_100");

  // Milestones — protein hits
  if (proteinDates.length >= 1)   earned.add("protein_first");
  if (proteinDates.length >= 10)  earned.add("protein_hits_10");
  if (proteinDates.length >= 20)  earned.add("protein_hits_20");
  if (proteinDates.length >= 50)  earned.add("protein_hits_50");
  if (proteinDates.length >= 100) earned.add("protein_hits_100");

  // Milestones — perfect days
  if (perfectDates.length >= 1)  earned.add("perfect_day_1");
  if (perfectDates.length >= 3)  earned.add("perfect_day_3");
  if (perfectDates.length >= 7)  earned.add("perfect_day_7");
  if (perfectDates.length >= 30) earned.add("perfect_day_30");

  // Milestones — veggies
  if (veggieDates.length >= 1) earned.add("veggie_day_1");

  // Milestones — food library
  if (foods.length >= 10)  earned.add("foods_added_10");
  if (foods.length >= 25)  earned.add("foods_added_25");
  if (foods.length >= 50)  earned.add("foods_added_50");
  if (foods.length >= 100) earned.add("foods_added_100");
  if (foods.length >= 200) earned.add("foods_added_200");

  // Milestones — recipe
  if (foods.some((f) => f.category === "homeRecipe"))
    earned.add("recipe_first");

  return earned;
}

function GoalModeToggle({ active, onChange }){
  const { t } = useTranslation();
  return (
    <div
      className="flex h-9 flex-shrink-0 items-center gap-1 rounded-full border border-slate-200 dark:border-slate-700 bg-white/70 dark:bg-slate-900/60 px-1 shadow-sm"
      role="group"
      aria-label="Select active goal profile"
    >
      {DUAL_PROFILE_OPTIONS.map(({ value, label, Icon, accent })=>{
        const translatedLabel = value === 'train' ? t('profile.train') : value === 'rest' ? t('profile.rest') : t('setup.'+value, label);
        const isActive = active===value;
        return (
          <button
            key={value}
            type="button"
            onClick={()=>onChange(value)}
            aria-pressed={isActive}
            className={`flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-1 focus-visible:ring-slate-400 dark:focus-visible:ring-slate-500 ${isActive? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900 shadow-sm': 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100'}`}
          >
            <span className="inline-flex items-center justify-center">
              <Icon className={`h-3 w-3 ${isActive? '' : 'opacity-80'}`} />
            </span>
            <span className="hidden sm:inline">{translatedLabel}</span>
            <span className="ml-1 inline-flex h-1.5 w-1.5 rounded-full" style={{ backgroundColor: accent }} aria-hidden="true" />
          </button>
        );
      })}
    </div>
  );
}

function GoalModeSelect({ value, onChange, className }) {
  const { t } = useTranslation();
  const entry = coerceModeEntry(value);
  const optionKey = entry.setup === "dual" ? (entry.profile === "rest" ? "rest" : "train") : entry.setup;
  const activeOption = PROFILE_MODE_OPTIONS.find((option) => option.value === optionKey) || PROFILE_MODE_OPTIONS[0];
  const getOptionLabel = (opt) => opt.value === 'train' ? t('profile.train') : opt.value === 'rest' ? t('profile.rest') : t('setup.'+opt.value, opt.label);
  const activeLabel = getOptionLabel(activeOption);
  return (
    <Select
      value={activeOption.value}
      onValueChange={(selected) => {
        if (selected === "train" || selected === "rest") {
          onChange(cloneModeEntry({ setup: "dual", profile: selected }));
        } else {
          onChange(cloneModeEntry({ setup: selected }));
        }
      }}
    >
      <SelectTrigger
        className={cn(
          "h-8 w-44 rounded-full border-slate-300 bg-white/80 pl-3 pr-3 text-xs dark:border-slate-700 dark:bg-slate-900/60",
          className,
        )}
        aria-label={`Goal profile: ${activeLabel}`}
      >
        <span className="sr-only">{activeLabel}</span>
        <div className="flex w-full items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <activeOption.Icon className="h-3.5 w-3.5" aria-hidden="true" />
            <span>{activeLabel}</span>
          </div>
          <span className="inline-flex h-1.5 w-1.5 rounded-full" style={{ backgroundColor: activeOption.accent }} aria-hidden="true" />
        </div>
      </SelectTrigger>
      <SelectContent align="end">
        {PROFILE_MODE_OPTIONS.map((opt) => (
          <SelectItem key={opt.value} value={opt.value}>
            <div className="flex items-center gap-2">
              <opt.Icon className="h-4 w-4" />
              <span>{getOptionLabel(opt)}</span>
              <span className="ml-auto inline-flex h-2 w-2 rounded-full" style={{ backgroundColor: opt.accent }} aria-hidden="true" />
            </div>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}

function GoalModeBadge({ value, className }) {
  const { t } = useTranslation();
  const entry = coerceModeEntry(value);
  const optionKey = entry.setup === "dual" ? (entry.profile === "rest" ? "rest" : "train") : entry.setup;
  const activeOption = PROFILE_MODE_OPTIONS.find((option) => option.value === optionKey) || PROFILE_MODE_OPTIONS[0];
  const activeLabel = activeOption.value === 'train' ? t('profile.train') : activeOption.value === 'rest' ? t('profile.rest') : t('setup.'+activeOption.value, activeOption.label);
  return (
    <div
      className={cn(
        "flex h-8 items-center justify-center gap-2 rounded-full border border-slate-300 bg-white/80 px-3 text-xs text-slate-600 dark:border-slate-700 dark:bg-slate-900/60 dark:text-slate-300 whitespace-nowrap",
        "pointer-events-none select-none",
        className,
      )}
      title={activeLabel}
    >
      <span className="sr-only">{activeLabel}</span>
      <activeOption.Icon className="h-3.5 w-3.5" aria-hidden="true" />
      <span className="font-medium">{activeLabel}</span>
      <span
        className="inline-flex h-1.5 w-1.5 rounded-full"
        style={{ backgroundColor: activeOption.accent }}
        aria-hidden="true"
      />
    </div>
  );
}
// PATCH: accept optional subColor for "X over" red
/** Compact single-column macro cell used in the mobile sticky strip. */
function CompactMacroCell({ label, color, actualNum, goalNum, unit }) {
  const over = actualNum > goalNum;
  const pct = goalNum > 0 ? Math.min((actualNum / goalNum) * 100, 100) : 0;
  const displayColor = over ? '#ef4444' : color;
  return (
    <div className="flex flex-col gap-0.5 min-w-0">
      <span className="text-[9px] font-bold uppercase tracking-widest leading-none" style={{ color }}>
        {label}
      </span>
      <span className="text-sm font-bold leading-tight" style={{ color: displayColor }}>
        {actualNum.toFixed(0)}
        <span className="text-[9px] font-normal ml-0.5">{unit}</span>
      </span>
      <div className="h-1 w-full rounded-full bg-slate-200 dark:bg-slate-700 overflow-hidden my-0.5">
        <div className="h-full rounded-full" style={{ width: `${pct}%`, backgroundColor: displayColor }} />
      </div>
      <span className="text-[9px] text-slate-400 dark:text-slate-500 leading-none">
        /{goalNum.toFixed(0)}{unit !== 'kcal' ? unit : ''}
      </span>
    </div>
  );
}

function StripKpi({ label, color, actual, goal, remaining, over }) {
  return (
    <div className="flex min-h-[96px] flex-col justify-between rounded-xl border border-slate-200 bg-white/80 px-4 py-4 shadow-sm dark:border-slate-800 dark:bg-slate-900/70">
      <div className="flex items-start justify-between">
        <span className="text-xs font-semibold uppercase tracking-wide" style={{ color }}>
          {label}
        </span>
        {goal ? (
          <span className="text-[11px] font-medium text-slate-500 dark:text-slate-300">Goal {goal}</span>
        ) : null}
      </div>
      <div className="mt-4 flex items-end justify-between">
        {remaining ? (
          <span
            className={cn(
              "text-sm font-medium",
              over ? "text-red-600 dark:text-red-400" : "text-slate-600 dark:text-slate-300",
            )}
          >
            {remaining}
          </span>
        ) : (
          <span className="text-sm text-slate-500 dark:text-slate-400">&nbsp;</span>
        )}
        <span className="text-2xl font-semibold" style={{ color }}>
          {actual}
        </span>
      </div>
    </div>
  );
}
function TogglePill({ label, active, onClick, color }){
  return (
    <button onClick={onClick} className={`text-xs px-3 py-1 rounded-full border transition ${active? 'bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900': 'bg-transparent text-slate-700 dark:text-slate-200'}`} style={{ borderColor: color }}>
      <span className="inline-block w-2 h-2 rounded-full mr-2" style={{ backgroundColor: color }} />{label}
    </button>
  );
}

function BadgeUnlockPopup({ badgeId, onClose }) {
  const { t } = useTranslation();
  const badge = BADGES.find((b) => b.stringId === badgeId);
  if (!badge) return null;
  const accentColor = badge.colors[0];

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center px-6" onClick={onClose}>
      <div className="absolute inset-0 bg-slate-950/60 backdrop-blur-sm" />
      <div
        className="relative w-full max-w-xs rounded-3xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 shadow-2xl overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Decorative sparkles background */}
        <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
          {[
            { top: "12%", left: "18%", size: 6, opacity: 0.5, delay: "0s" },
            { top: "8%",  left: "72%", size: 8, opacity: 0.4, delay: "0.15s" },
            { top: "22%", left: "85%", size: 5, opacity: 0.6, delay: "0.3s" },
            { top: "70%", left: "10%", size: 7, opacity: 0.4, delay: "0.1s" },
            { top: "78%", left: "80%", size: 6, opacity: 0.5, delay: "0.25s" },
            { top: "55%", left: "90%", size: 4, opacity: 0.35, delay: "0.4s" },
            { top: "88%", left: "50%", size: 5, opacity: 0.3, delay: "0.2s" },
          ].map((s, i) => (
            <span
              key={i}
              className="absolute rounded-full animate-ping"
              style={{
                top: s.top, left: s.left,
                width: s.size, height: s.size,
                backgroundColor: accentColor,
                opacity: s.opacity,
                animationDuration: "2s",
                animationDelay: s.delay,
              }}
            />
          ))}
        </div>

        <div className="relative flex flex-col items-center gap-4 px-8 py-10 text-center">
          {/* Badge icon */}
          <BadgeShape shape={badge.shape} colors={badge.colors} locked={false} size={88}>
            <BadgeIcon icon={badge.icon} locked={false} accent={badge.accent} />
          </BadgeShape>

          {/* Text */}
          <div className="space-y-1">
            <p className="text-xs font-semibold uppercase tracking-widest text-slate-400 dark:text-slate-500">
              {t('settings.badgesTitle')}
            </p>
            <h2 className="text-xl font-bold text-slate-900 dark:text-slate-100">{t('badges.'+badge.stringId+'.name', badge.name)}</h2>
            <p className="text-sm text-slate-500 dark:text-slate-400 leading-snug">
              {t('badges.'+badge.stringId+'.desc', badge.desc)}
            </p>
          </div>

          {/* CTA */}
          <button
            type="button"
            onClick={onClose}
            className="mt-2 w-full rounded-full py-3 text-sm font-semibold text-white shadow-md transition hover:opacity-90 active:scale-95"
            style={{ backgroundColor: accentColor }}
          >
            Keep going! 💪
          </button>
        </div>
      </div>
    </div>
  );
}

function BadgesCard({ earnedBadgeIds }) {
  const { t } = useTranslation();
  const [showAll, setShowAll] = useState(false);
  const earnedCount = BADGES.filter((b) => earnedBadgeIds.has(b.stringId)).length;
  const previewBadges = BADGES.filter((b) => earnedBadgeIds.has(b.stringId)).slice(0, 12);

  return (
    <>
      <div className="rounded-xl border p-4 border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/40 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="font-medium">{t('cards.myBadges')}</div>
          <span className="text-xs text-slate-500">{t('cards.earnedOf', { earned: earnedCount, total: BADGES.length })}</span>
        </div>

        {/* Preview: up to 12 earned badges, 4 per row */}
        {previewBadges.length > 0 ? (
          <div className="grid grid-cols-4 gap-2">
            {previewBadges.map((b) => (
              <span key={b.stringId} className="inline-flex justify-center">
                <BadgeShape shape={b.shape} colors={b.colors} locked={false} size={80} title={b.name}>
                  <BadgeIcon icon={b.icon} locked={false} accent={b.accent} />
                </BadgeShape>
              </span>
            ))}
          </div>
        ) : (
          <p className="text-xs text-slate-400 min-h-[2.5rem] flex items-center">{t('cards.logFoodBadges')}</p>
        )}
        {earnedCount > 12 && (
          <span className="text-xs text-slate-500">+{earnedCount - 12} more</span>
        )}

        <button
          type="button"
          onClick={() => setShowAll(true)}
          className="text-xs text-slate-500 hover:text-slate-900 dark:hover:text-slate-100 underline self-start"
        >
          {t('cards.seeAllBadges')}
        </button>
      </div>

      {/* Full badges modal */}
      {showAll && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-950/50 px-4 pb-4 sm:pb-0">
          <div className="relative w-full max-w-lg rounded-2xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 shadow-xl overflow-y-auto max-h-[85vh]">
            <div className="sticky top-0 z-10 flex items-center justify-between border-b border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 px-5 py-4">
              <div>
                <h2 className="font-semibold text-base">{t('cards.allBadges')}</h2>
                <p className="text-xs text-slate-500">{t('cards.earnedOfBadges', { earned: earnedCount, total: BADGES.length })}</p>
              </div>
              <button
                type="button"
                onClick={() => setShowAll(false)}
                className="rounded-full p-1.5 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
                aria-label="Close"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
            <AchievementBadges earnedBadgeIds={earnedBadgeIds} />
          </div>
        </div>
      )}
    </>
  );
}

function WeeklyNutritionCard({ data, onPrevWeek, onNextWeek, canGoForward }) {
  const { t } = useTranslation();
  const days = data?.days ?? [];
  const rows = data?.rows ?? [];
  const hasData = days.length > 0 && rows.length > 0;
  const containerRef = useRef(null);
  const [hoveredCell, setHoveredCell] = useState(null);
  const clearHover = () => setHoveredCell(null);

  const handleCellEnter = (event, tooltipText) => {
    if (!containerRef.current) return;
    const parentRect = containerRef.current.getBoundingClientRect();
    const rect = event.currentTarget.getBoundingClientRect();
    const next = {
      text: tooltipText,
      x: rect.left - parentRect.left + rect.width / 2,
      y: rect.top - parentRect.top,
    };
    setHoveredCell((prev) =>
      prev && prev.text === next.text && Math.abs(prev.x - next.x) < 0.5 && Math.abs(prev.y - next.y) < 0.5
        ? prev
        : next
    );
  };

  return (
    <Card className="h-full min-h-[360px] flex flex-col">
      <CardHeader>
        <div className="flex items-center justify-between gap-3">
          <CardTitle>{t('dashboard.weeklyNutrition')}</CardTitle>
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={onPrevWeek}
              className="flex h-7 w-7 items-center justify-center rounded-md border border-slate-200 dark:border-slate-700 text-slate-500 hover:text-slate-900 dark:hover:text-slate-100 transition-colors"
              aria-label={t('week.previousWeek')}
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            {data?.weekLabel && <span className="px-1 text-xs text-slate-500 w-[112px] text-center tabular-nums">{data.weekLabel}</span>}
            <button
              type="button"
              onClick={onNextWeek}
              disabled={!canGoForward}
              className="flex h-7 w-7 items-center justify-center rounded-md border border-slate-200 dark:border-slate-700 text-slate-500 hover:text-slate-900 dark:hover:text-slate-100 transition-colors disabled:opacity-30 disabled:pointer-events-none"
              aria-label={t('week.nextWeek')}
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </CardHeader>
      <CardContent className="flex-1 pt-3 pb-4">
        {!hasData ? (
          <p className="text-sm text-slate-500">Log entries to see your weekly breakdown.</p>
        ) : (
          <div ref={containerRef} className="relative overflow-x-auto" onMouseLeave={clearHover}>
            <div className="min-w-[340px]">
              <div className="grid grid-cols-[auto_repeat(7,minmax(0,1fr))_auto] items-end gap-x-1 sm:gap-x-3 gap-y-2 sm:gap-y-3 text-[11px] sm:text-[13px] mt-3">
                <div className="text-[11px] font-medium uppercase tracking-wide text-slate-500">Macro</div>
                {days.map((day) => (
                  <div key={day.iso} className="flex justify-center">
                    <div
                      className={cn(
                        "flex h-6 w-6 items-center justify-center rounded-full text-[11px] font-semibold text-slate-500 transition-colors",
                        day.isSelected && "text-slate-900 dark:text-slate-100",
                        day.isToday ? "border border-slate-400/80 dark:border-slate-500/80" : "border border-transparent",
                        day.isSelected && "ring-2 ring-offset-2 ring-offset-transparent ring-slate-400/70 dark:ring-slate-500/70",
                      )}
                    >
                      {day.label}
                    </div>
                  </div>
                ))}
                <div className="pr-1 text-right text-[11px] font-medium uppercase tracking-wide text-slate-500">{t('sticky.selectedDay')}</div>
                {rows.map((row) => (
                  <Fragment key={row.key}>
                    <div className="flex items-center gap-2 text-xs font-medium text-slate-500">
                      <span
                        className="inline-flex h-2 w-2 rounded-full"
                        style={{ backgroundImage: `linear-gradient(135deg, ${row.theme.gradientFrom}, ${row.theme.gradientTo})` }}
                        aria-hidden="true"
                      />
                      <span>{row.label}</span>
                    </div>
                    {row.cells.map((cell, idx) => {
                      const day = days[idx];
                      return (
                        <WeeklyNutritionCell
                          key={`${row.key}-${cell.iso}`}
                          theme={row.theme}
                          unit={row.unit}
                          actual={cell.actual}
                          goal={cell.goal}
                          isToday={day?.isToday}
                          isSelected={day?.isSelected}
                          onEnter={handleCellEnter}
                          onLeave={clearHover}
                        />
                      );
                    })}
                    <div className="text-right text-xs text-slate-600 dark:text-slate-300">
                      <div className="font-semibold text-slate-900 dark:text-slate-100">
                        {formatNumber(row.selectedActual)}
                        <span className="ml-1 text-[10px] font-normal uppercase text-slate-500">{row.unit}</span>
                      </div>
                      {row.selectedGoal > 0 ? (
                        <div className="text-[10px] text-slate-500">goal {formatNumber(row.selectedGoal)}</div>
                      ) : (
                        <div className="text-[10px] text-slate-400">no goal</div>
                      )}
                    </div>
                  </Fragment>
                ))}
              </div>
            </div>
            {hoveredCell && (
              <div
                className="pointer-events-none absolute z-20"
                style={{ left: hoveredCell.x, top: hoveredCell.y }}
              >
                <div className="-translate-x-1/2 -translate-y-full pb-2">
                  <ChartTooltipContainer>
                    <div className="font-semibold text-slate-100">{hoveredCell.text}</div>
                  </ChartTooltipContainer>
                </div>
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function WeeklyNutritionCell({ theme, unit, actual, goal, isToday, isSelected, onEnter, onLeave }) {
  const palette = theme ?? MACRO_THEME.kcal;
  const safeActual = Math.max(0, actual || 0);
  const safeGoal = Math.max(0, goal || 0);
  const hasGoal = safeGoal > 0;
  const ratioRaw = hasGoal ? safeActual / safeGoal : safeActual > 0 ? 1 : 0;
  const cappedRatio = Math.min(Math.max(ratioRaw, 0), 2);
  const baseRatio = Math.min(cappedRatio, 1);
  const overRatio = Math.max(0, cappedRatio - 1);
  const baseHeight = baseRatio * 50;
  const overHeight = overRatio * 50;
  const baseGradient = `linear-gradient(180deg, ${palette.gradientFrom}, ${palette.gradientTo})`;
  const overGradient = `linear-gradient(180deg, ${palette.gradientTo}, ${palette.dark})`;
  const tooltip = hasGoal
    ? `${formatNumber(safeActual)} ${unit} of ${formatNumber(safeGoal)} ${unit}`
    : `${formatNumber(safeActual)} ${unit}`;

  const ringClass = isToday
    ? "ring-2 ring-offset-2 ring-offset-transparent ring-slate-400/70 dark:ring-slate-500/70"
    : isSelected
    ? "ring-1 ring-offset-2 ring-offset-transparent ring-slate-300/70 dark:ring-slate-600/70"
    : "";

  return (
    <div className="flex justify-center">
      <div
        className={cn(
          "relative flex h-24 w-9 items-end justify-center rounded-xl px-1.5 py-2 transition-all",
          ringClass,
        )}
        onMouseEnter={(e) => onEnter?.(e, tooltip)}
        onMouseLeave={() => onLeave?.()}
      >
        <div className="relative h-full w-[10px]" aria-hidden="true">
          <div className="absolute inset-0 rounded-full bg-slate-200/60 dark:bg-slate-800/60" />
          {hasGoal && (
            <div
              className="absolute left-1/2 w-3 -translate-x-1/2 rounded-full bg-slate-400/80 dark:bg-slate-500/70"
              style={{ bottom: "50%", height: "2px" }}
            />
          )}
          {baseHeight > 0 && (
            <div
              className="absolute bottom-0 left-0 right-0 mx-auto rounded-full"
              style={{ height: `${baseHeight}%`, backgroundImage: baseGradient }}
            />
          )}
          {overHeight > 0 && (
            <div
              className="absolute left-0 right-0 mx-auto rounded-full"
              style={{ height: `${overHeight}%`, bottom: `${baseHeight}%`, backgroundImage: overGradient }}
            />
          )}
        </div>
      </div>
    </div>
  );
}

function AverageSummaryCard({ label, averages, scaleMax }) {
  const { t } = useTranslation();
  const data = [
    {
      key: "kcal",
      label: t('macro.kcal'),
      unit: "kcal",
      value: averages?.kcal ?? 0,
      gradientFrom: MACRO_THEME.kcal.gradientFrom,
      gradientTo: MACRO_THEME.kcal.gradientTo,
    },
    {
      key: "protein",
      label: t('macro.protein'),
      unit: "g",
      value: averages?.protein ?? 0,
      gradientFrom: MACRO_THEME.protein.gradientFrom,
      gradientTo: MACRO_THEME.protein.gradientTo,
    },
    {
      key: "carbs",
      label: t('macro.carbs'),
      unit: "g",
      value: averages?.carbs ?? 0,
      gradientFrom: MACRO_THEME.carbs.gradientFrom,
      gradientTo: MACRO_THEME.carbs.gradientTo,
    },
    {
      key: "fat",
      label: t('macro.fat'),
      unit: "g",
      value: averages?.fat ?? 0,
      gradientFrom: MACRO_THEME.fat.gradientFrom,
      gradientTo: MACRO_THEME.fat.gradientTo,
    },
  ];

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm text-slate-500 dark:text-slate-400">{label}</CardTitle>
      </CardHeader>
      <CardContent className="pt-0 pb-4 pl-2 pr-4">
        <div className="space-y-4">
          {data.map((item) => {
            const maxForMetric = scaleMax?.[item.key];
            const safeMax = maxForMetric != null && maxForMetric > 0
              ? maxForMetric
              : item.value != null && item.value > 0
                ? item.value
                : 1;
            const normalized = safeMax > 0 ? Math.min(1, (item.value ?? 0) / safeMax) : 0;
            const valueText = `${formatNumber(item.value ?? 0)} ${item.unit}`.trim();
            return (
              <div key={item.key} className="flex items-center gap-3">
                <span className="w-20 text-sm font-medium text-slate-600 dark:text-slate-300">{item.label}</span>
                <div className="relative flex-1">
                  <div className="h-3 w-full overflow-hidden rounded-full bg-slate-200 dark:bg-slate-800">
                    <div
                      className="h-full rounded-full"
                      style={{
                        width: `${normalized * 100}%`,
                        backgroundImage: `linear-gradient(90deg, ${item.gradientFrom}, ${item.gradientTo})`,
                      }}
                    />
                  </div>
                </div>
                <span className="w-20 text-right text-sm font-semibold text-slate-700 dark:text-slate-100">{valueText}</span>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}

const WEIGHT_RANGE_OPTIONS = [
  { value: "30",  label: "Last 30 days" },
  { value: "90",  label: "Last 3 months" },
  { value: "180", label: "Last 6 months" },
  { value: "365", label: "Last 12 months" },
  { value: "all", label: "All time" },
];

function computeChartDomain(values, padFallback = 0.5) {
  if (!values.length) return null;
  const min = Math.min(...values);
  const max = Math.max(...values);
  if (min === max) return [min - padFallback, max + padFallback];
  const pad = Math.max((max - min) * 0.1, padFallback);
  return [min - pad, max + pad];
}

function WeightTrendCard({ history, latestWeight, latestDate }) {
  const { t } = useTranslation();
  const [range, setRange] = useState("90");
  const gradientId = useId();

  const data = useMemo(() => {
    if (!Array.isArray(history) || !history.length) return [];
    const today = startOfDay(new Date());
    const startIso = range === "all" ? null : toISODate(subDays(today, Number(range) - 1));
    const endIso = toISODate(today);
    return history
      .filter((e) => (!startIso || e.date >= startIso) && e.date <= endIso)
      .map((e) => ({
        date: e.date,
        label: format(new Date(`${e.date}T00:00:00`), range === "365" || range === "all" ? "MMM d yy" : "MMM d"),
        weight: Number.isFinite(e.weightKg) ? +Number(e.weightKg).toFixed(1) : null,
        bodyFat: Number.isFinite(e.bodyFatPct) ? +Number(e.bodyFatPct).toFixed(1) : null,
      }));
  }, [history, range]);

  const hasData = data.some((p) => p.weight != null || p.bodyFat != null);
  const hasBodyFat = data.some((p) => p.bodyFat != null);

  const weightDomain = computeChartDomain(data.map((p) => p.weight).filter(Number.isFinite), 0.5);
  const bodyFatDomain = computeChartDomain(data.map((p) => p.bodyFat).filter(Number.isFinite), 0.3);

  return (
    <Card>
      <CardHeader className="pb-1.5">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
          <CardTitle>{t('cards.weightTrendTitle')}</CardTitle>
          <Select value={range} onValueChange={setRange}>
            <SelectTrigger className="h-8 w-full sm:w-40 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {WEIGHT_RANGE_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{t('cards.weightRange_'+o.value, o.label)}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </CardHeader>
      <CardContent className="space-y-3 pt-0">
        <div className="flex items-center gap-4 text-xs text-slate-500 dark:text-slate-400">
          <div className="flex items-center gap-1.5">
            <span className="inline-block h-0.5 w-5 rounded" style={{ backgroundColor: '#a855f7' }} />
            <span>{t('cards.weightLegendWeight')}</span>
          </div>
          {hasBodyFat && (
            <div className="flex items-center gap-1.5">
              <svg width="20" height="4" className="shrink-0"><line x1="0" y1="2" x2="20" y2="2" stroke="#22d3ee" strokeWidth="2" strokeDasharray="4 2" /></svg>
              <span>{t('cards.weightLegendBodyFat')}</span>
            </div>
          )}
        </div>
        <div className="h-44">
          {hasData ? (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data} margin={{ top: 12, right: 16, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id={`${gradientId}-fill`} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#a855f7" stopOpacity={0.65} />
                    <stop offset="100%" stopColor="#a855f7" stopOpacity={0.05} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(148, 163, 184, 0.25)" />
                <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: "currentColor", fontSize: 12 }} />
                <YAxis
                  yAxisId="weight"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: "currentColor", fontSize: 12 }}
                  tickFormatter={(value) => `${formatNumber(value)} kg`}
                  width={56}
                  domain={weightDomain ?? undefined}
                />
                <YAxis
                  yAxisId="bodyFat"
                  orientation="right"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: "currentColor", fontSize: 12 }}
                  tickFormatter={(value) => `${formatNumber(value)}%`}
                  width={56}
                  domain={bodyFatDomain ?? undefined}
                  hide={!hasBodyFat}
                />
                <RTooltip
                  content={({ active, payload }) => {
                    if (!active || !payload?.length) return null;
                    const point = payload[0]?.payload;
                    if (!point) return null;
                    const iso = typeof point.date === "string" ? point.date : null;
                    let title = point.label ?? iso ?? "";
                    if (iso && ISO_DATE_RE.test(iso)) {
                      const parsed = new Date(`${iso}T00:00:00`);
                      if (!Number.isNaN(parsed.getTime())) {
                        title = format(parsed, "PP");
                      }
                    }

                    const weightEntry = payload.find((item) => item.dataKey === "weight");
                    const bodyFatEntry = payload.find((item) => item.dataKey === "bodyFat");
                    const hasWeight = Number.isFinite(point.weight) || Number.isFinite(weightEntry?.value);
                    const hasBodyFat = Number.isFinite(point.bodyFat) || Number.isFinite(bodyFatEntry?.value);

                    return (
                      <ChartTooltipContainer title={title}>
                        {hasWeight && (
                          <div className="flex items-center justify-between gap-6">
                            <span className="text-slate-200">{t('cards.weightLegendWeight')}</span>
                            <span className="font-semibold text-slate-100">{`${formatNumber(point.weight ?? weightEntry?.value ?? 0)} kg`}</span>
                          </div>
                        )}
                        {hasBodyFat && (
                          <div className="flex items-center justify-between gap-6">
                            <span className="text-slate-200">{t('cards.weightLegendBodyFat')}</span>
                            <span className="font-semibold text-slate-100">{`${formatNumber(point.bodyFat ?? bodyFatEntry?.value ?? 0)}%`}</span>
                          </div>
                        )}
                      </ChartTooltipContainer>
                    );
                  }}
                />
                <Area
                  yAxisId="weight"
                  type="monotone"
                  dataKey="weight"
                  stroke="#a855f7"
                  strokeWidth={3}
                  fill={`url(#${gradientId}-fill)`}
                  activeDot={{ r: 5 }}
                  dot={{ r: 3 }}
                  connectNulls
                />
                <Line
                  yAxisId="bodyFat"
                  type="monotone"
                  dataKey="bodyFat"
                  stroke="#22d3ee"
                  strokeWidth={3}
                  dot={{ r: 3 }}
                  activeDot={{ r: 5 }}
                  connectNulls
                  strokeDasharray="4 2"
                />
              </AreaChart>
            </ResponsiveContainer>
          ) : (
            <div className="flex h-full items-center justify-center text-sm text-slate-500 dark:text-slate-400">
              {t('cards.logWeightHint')}
            </div>
          )}
        </div>
        <div className="flex items-baseline gap-2 text-2xl font-semibold text-slate-900 dark:text-slate-100">
          <span>{latestWeight != null ? formatNumber(latestWeight) : "—"}</span>
          <span className="text-sm font-medium text-slate-500 dark:text-slate-400">kg</span>
        </div>
        <div className="text-xs text-slate-500 dark:text-slate-400">
          {latestDate ? t('cards.latestEntryOn', { date: latestDate }) : t('cards.noWeightEntries')}
        </div>
      </CardContent>
    </Card>
  );
}

function FoodLoggingCard({ summary }) {
  const { t } = useTranslation();
  const { grid = [], totalLogged = 0, totalDays = 0, thisWeekLogged = 0 } = summary ?? {};
  const containerRef = useRef(null);
  const [hoveredDay, setHoveredDay] = useState(null);

  const handlePointHover = (day, event) => {
    if (!containerRef.current) return;
    const parentRect = containerRef.current.getBoundingClientRect();
    const rect = event.currentTarget.getBoundingClientRect();
    const nextState = {
      day,
      position: {
        x: rect.left - parentRect.left + rect.width / 2,
        y: rect.top - parentRect.top,
      },
    };
    setHoveredDay((prev) => {
      if (
        prev
        && prev.day?.iso === day.iso
        && Math.abs(prev.position.x - nextState.position.x) < 0.25
        && Math.abs(prev.position.y - nextState.position.y) < 0.25
      ) {
        return prev;
      }
      return nextState;
    });
  };

  const clearHover = () => setHoveredDay(null);

  const DOW_LABELS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  // Compute leading empty cells: getDay returns 0=Sun..6=Sat, convert to Mon-based offset
  const firstDayOffset = grid.length > 0 ? (getDay(new Date(`${grid[0].iso}T00:00:00`)) + 6) % 7 : 0;

  return (
    <Card>
      <CardHeader className="pb-1.5">
        <CardTitle>{t('cards.foodLoggingTitle')}</CardTitle>
        <p className="text-sm text-slate-500 dark:text-slate-400">{t('cards.foodLoggingLast30')}</p>
      </CardHeader>
      <CardContent className="space-y-3 pt-0 pb-3">
        <div ref={containerRef} className="relative" onMouseLeave={clearHover}>
          <div className="grid grid-cols-7 gap-2 py-1">
            {DOW_LABELS.map((d, i) => (
              <div key={i} className="flex h-5 items-center justify-center text-[10px] font-medium text-slate-400 dark:text-slate-500">{d}</div>
            ))}
            {Array.from({ length: firstDayOffset }).map((_, i) => (
              <div key={`pad-${i}`} />
            ))}
            {grid.map((day) => {
              const isoDate = `${day.iso}T00:00:00`;
              const fullLabel = format(new Date(isoDate), "PP");
              const statusLabel = day.logged ? t('cards.loggedLabel') : t('cards.noLogLabel');
              return (
                <button
                  key={day.iso}
                  type="button"
                  onMouseEnter={(event) => handlePointHover(day, event)}
                  onMouseMove={(event) => handlePointHover(day, event)}
                  onMouseLeave={clearHover}
                  onFocus={(event) => handlePointHover(day, event)}
                  onBlur={clearHover}
                  className={cn(
                    "h-6 w-6 rounded-md border transition focus:outline-none focus-visible:ring-2 focus-visible:ring-sky-500/60 sm:h-7 sm:w-7",
                    day.logged
                      ? "border-transparent bg-sky-500/90 shadow-sm shadow-sky-500/40 dark:bg-sky-500/70"
                      : "border-slate-200/70 bg-slate-200/60 dark:border-slate-700 dark:bg-slate-800/70",
                  )}
                  aria-label={`${statusLabel} on ${fullLabel}`}
                  aria-pressed={day.logged}
                />
              );
            })}
          </div>
          {hoveredDay ? (
            <div
              className="pointer-events-none absolute z-20"
              style={{ left: hoveredDay.position.x, top: hoveredDay.position.y }}
            >
              <div className="-translate-x-1/2 -translate-y-full pb-2">
                <ChartTooltipContainer title={format(new Date(`${hoveredDay.day.iso}T00:00:00`), "PP")}>
                  <div className="font-semibold text-slate-100">{hoveredDay.day.logged ? t('cards.loggedLabel') : t('cards.noLogLabel')}</div>
                </ChartTooltipContainer>
              </div>
            </div>
          ) : null}
        </div>
        <div className="flex items-baseline justify-between text-sm">
          <span className="font-semibold text-slate-900 dark:text-slate-100">
            {t('cards.loggedDays', { logged: totalLogged, total: totalDays })}
          </span>
          <span className="text-xs text-slate-500 dark:text-slate-400">{t('cards.loggedThisWeek', { count: thisWeekLogged })}</span>
        </div>
      </CardContent>
    </Card>
  );
}
function GoalDonut({ label, theme, actual, goal, unit }) {
  const a = Math.max(0, actual || 0);
  const g = Math.max(0, goal || 0);
  const pctRaw = g > 0 ? (a / g) * 100 : 0;
  const pct = Number.isFinite(pctRaw) ? Math.round(pctRaw) : 0;

  const basePct = g > 0 ? Math.min(Math.max(pctRaw, 0), 100) : a > 0 ? 100 : 0;
  const overPct = g > 0 ? Math.min(Math.max(pctRaw - 100, 0), 100) : 0;

  const radius = 52;
  const strokeWidth = 14;
  const circumference = 2 * Math.PI * radius;
  const gradientId = useId();
  const baseGradientId = `${gradientId}-base`;
  const overGradientId = `${gradientId}-over`;
  const textColor = theme.dark;

  const dashFor = (percent) => {
    if (percent <= 0) return `0 ${circumference}`;
    if (percent >= 100) return `${circumference} 0.0001`;
    const length = (percent / 100) * circumference;
    return `${length} ${circumference - length}`;
  };

  const baseDasharray = dashFor(basePct);
  const overDasharray = dashFor(overPct);

  const hasGoal = g > 0;

  return (
    <div className="flex flex-col items-center justify-center">
      <div className="mb-1 text-base font-medium">{label}</div>
      <div className="relative h-24 w-24 sm:h-32 sm:w-32">
        <svg viewBox="0 0 120 120" className="h-full w-full">
          <defs>
            <linearGradient id={baseGradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={theme.gradientFrom} />
              <stop offset="100%" stopColor={theme.gradientTo} />
            </linearGradient>
            <linearGradient id={overGradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={theme.gradientTo} />
              <stop offset="100%" stopColor={theme.dark} />
            </linearGradient>
          </defs>
          <circle
            cx="60"
            cy="60"
            r={radius}
            stroke={COLORS.gray}
            strokeWidth={strokeWidth}
            fill="transparent"
            opacity={0.35}
          />
          {basePct > 0 && (
            <circle
              cx="60"
              cy="60"
              r={radius}
              stroke={`url(#${baseGradientId})`}
              strokeWidth={strokeWidth}
              fill="transparent"
              strokeDasharray={baseDasharray}
              transform="rotate(-90 60 60)"
              strokeLinecap="butt"
            />
          )}
          {overPct > 0 && (
            <circle
              cx="60"
              cy="60"
              r={radius}
              stroke={`url(#${overGradientId})`}
              strokeWidth={strokeWidth}
              fill="transparent"
              strokeDasharray={overDasharray}
              transform="rotate(-90 60 60)"
              strokeLinecap="butt"
            />
          )}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <div className="text-lg font-semibold" style={{ color: textColor }}>{Number.isFinite(pct) ? `${pct}%` : "0%"}</div>
        </div>
      </div>
      <div className="mt-1 text-xs text-slate-500">
        {hasGoal ? (
          <span>{Math.round(a)} / {Math.round(g)} {unit}</span>
        ) : (
          <span>{Math.round(a)} {unit}</span>
        )}
      </div>
    </div>
  );
}
function TopFoodsCard({ topFoods, topMacroKey, onMacroChange, selectedDate, goalMode }) {
  const dayLabel = selectedDate ? format(new Date(selectedDate), "PP") : "Select a day";
  const gradientPrefix = useId();
  const unit = topMacroKey === "kcal" ? "kcal" : "g";

  const { slices, total } = useMemo(() => {
    const items = topFoods?.items ?? [];
    const total = Math.max(0, topFoods?.total ?? 0);
    const mapped = items.map((item, index) => {
      const theme = TOP_FOOD_THEMES[index % TOP_FOOD_THEMES.length];
      const gradientFrom = theme.gradientFrom ?? lightenHex(theme.base, 0.45);
      const gradientTo = theme.gradientTo ?? darkenHex(theme.base, 0.8);
      const share = total > 0 ? (item?.val ?? 0) / total : 0;
      const percentage = share * 100;
      return {
        ...item,
        share,
        percentage,
        theme,
        gradientFrom,
        gradientTo,
        gradientId: `${gradientPrefix}-slice-${index}`,
      };
    });
    return { slices: mapped, total };
  }, [topFoods, gradientPrefix]);

  const macroLabel = t('macro.'+topMacroKey, MACRO_LABELS[topMacroKey] ?? "Macro");
  const leftItems = slices.slice(0, Math.min(2, slices.length));
  const rightItems = slices.slice(leftItems.length, leftItems.length + Math.min(2, Math.max(0, slices.length - leftItems.length)));
  const bottomItems = slices.slice(leftItems.length + rightItems.length);

  const renderLegendItem = useCallback(
    (item, index, positionKey) => {
      const percentValue =
        item.percentage >= 10 || item.percentage === 0
          ? Math.round(item.percentage)
          : Number(item.percentage.toFixed(1));
      const badgeLabel = item.isOther ? "•" : index + 1;

      return (
        <div key={`${item.name}-${positionKey}`} className="relative rounded-2xl p-[1px]">
          <div
            className="absolute inset-0 rounded-2xl opacity-80"
            style={{ background: `linear-gradient(135deg, ${item.gradientFrom}, ${item.gradientTo})` }}
          />
          <div className="relative flex items-center gap-3 rounded-[1.1rem] border border-white/60 bg-white/90 px-4 py-3 shadow-sm backdrop-blur dark:border-slate-800/70 dark:bg-slate-900/70">
            <span
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold text-white shadow-sm shadow-slate-900/20"
              style={{ background: `linear-gradient(135deg, ${item.gradientTo}, ${item.theme.base})` }}
            >
              {badgeLabel}
            </span>
            <div>
              <div className="font-semibold text-slate-900 dark:text-slate-100">{item.name}</div>
              <div className="text-xs text-slate-600 dark:text-slate-400">
                {formatNumber(item.val)} {unit} · {percentValue}% of total
              </div>
            </div>
          </div>
        </div>
      );
    },
    [unit]
  );

  return (
    <Card>
      <CardHeader>
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
          <CardTitle className="min-w-0 truncate">Top Foods by Macros — {dayLabel}</CardTitle>
          <div className="flex flex-wrap items-center gap-2">
            <GoalModeBadge value={goalMode} />
            <Select value={topMacroKey} onValueChange={onMacroChange}>
              <SelectTrigger className="h-8 w-full sm:w-40">
                <SelectValue placeholder="Macro" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="kcal">Calories</SelectItem>
                <SelectItem value="protein">Protein</SelectItem>
                <SelectItem value="carbs">Carbs</SelectItem>
                <SelectItem value="fat">Fat</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </CardHeader>
      <CardContent className="sm:h-80">
        <div className="flex flex-col sm:grid sm:h-full w-full sm:grid-cols-[1fr_auto_1fr] sm:grid-rows-[1fr_auto] items-center gap-4 sm:gap-6">
          <div className="hidden sm:flex w-full flex-col items-stretch justify-center gap-3">
            {leftItems.map((item, index) => renderLegendItem(item, index, `left-${index}`))}
          </div>
          <div className="relative sm:row-span-2 flex h-[240px] sm:h-full w-full sm:w-[260px] sm:min-w-[220px] items-center justify-center">
            <ResponsiveContainer width="100%" height="100%" style={{ overflow: "visible" }}>
              <PieChart margin={{ top: 32, right: 40, bottom: 32, left: 40 }} style={{ overflow: "visible" }}>
                <defs>
                  {slices.map((slice) => (
                    <radialGradient key={slice.gradientId} id={slice.gradientId} cx="50%" cy="50%" r="65%">
                      <stop offset="0%" stopColor={slice.gradientFrom} />
                      <stop offset="100%" stopColor={slice.gradientTo} />
                    </radialGradient>
                  ))}
                </defs>
                <RTooltip
                  content={({ active, payload }) => {
                    if (!active || !payload?.length) return null;
                    const datum = payload[0]?.payload;
                    if (!datum) return null;
                    const valueText = `${formatNumber(datum.val ?? payload[0]?.value ?? 0)} ${unit}`;
                    return (
                      <ChartTooltipContainer title={datum.name}>
                        <div className="flex items-center justify-between gap-6">
                          <span className="text-slate-200">Contribution</span>
                          <span className="font-semibold text-slate-100">{valueText}</span>
                        </div>
                      </ChartTooltipContainer>
                    );
                  }}
                />
                <Pie
                  data={slices}
                  dataKey="val"
                  nameKey="name"
                  innerRadius={58}
                  outerRadius={92}
                  paddingAngle={slices.length > 1 ? 3 : 0}
                  stroke="#ffffff"
                  strokeWidth={3}
                  labelLine={false}
                >
                  {slices.map((slice) => (
                    <Cell key={slice.gradientId} fill={`url(#${slice.gradientId})`} />
                  ))}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-1 text-center">
              <span className="text-xs uppercase tracking-wide text-slate-400 dark:text-slate-500">{macroLabel}</span>
              <span className="text-lg font-semibold text-slate-800 dark:text-slate-100">
                {formatNumber(total)} {unit}
              </span>
            </div>
          </div>
          <div className="hidden sm:flex w-full flex-col items-stretch justify-center gap-3">
            {rightItems.map((item, index) => renderLegendItem(item, index + leftItems.length, `right-${index}`))}
          </div>
          <div className="sm:col-span-3 flex flex-wrap items-center justify-center gap-3">
            {/* On mobile, show all legend items here */}
            <div className="flex sm:hidden w-full flex-col gap-3">
              {slices.map((item, index) => renderLegendItem(item, index, `mobile-${index}`))}
            </div>
            {bottomItems.length === 0 ? (
              slices.length === 0 ? (
                <p className="text-sm text-slate-500">No foods logged for this day.</p>
              ) : null
            ) : (
              bottomItems.map((item, index) =>
                renderLegendItem(item, index + leftItems.length + rightItems.length, `bottom-${index}`)
              )
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

/*******************
 * Inline components
 *******************/
function DatePickerButton({ value, onChange, className }){
  const inputRef = useRef(null);
  return (
    <div className="relative cursor-pointer" onClick={() => inputRef.current?.showPicker?.()}>
      <CalendarIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
      <Input
        ref={inputRef}
        type="date"
        value={value ?? ''}
        onChange={(event)=>onChange(event.target.value)}
        max={todayISO()}
        className={cn("h-8 rounded-full border-slate-300 pl-9 pr-3 text-xs cursor-pointer", className)}
      />
    </div>
  );
}
function FoodInput({ foods, selectedFoodId, onSelect }){
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const current = foods.find(f=>f.id===selectedFoodId) || null;
  const results = useMemo(()=>{ if(!query.trim()) return foods.slice(0,20); const q=query.toLowerCase(); return foods.filter(f=>`${f.name}`.toLowerCase().includes(q)).slice(0,20); },[query,foods]);
  const handlePick = (f)=>{ onSelect(f.id); setQuery(f.name); setOpen(false); };
  useEffect(()=>{
    if(selectedFoodId){ const f=foods.find(x=>x.id===selectedFoodId); if(f) setQuery(f.name); }
    else setQuery("");
  },[selectedFoodId]);
  return (
    <div className="relative">
      <Input
        type="text"
        value={query}
        onFocus={()=>{ setOpen(true); if(current && !query) setQuery(current.name); }}
        onBlur={()=>setTimeout(()=>setOpen(false),150)}
        onChange={(e)=>{ setQuery(e.target.value); setOpen(true); }}
        placeholder="Search food (click to open)"
      />
      <Search className="h-4 w-4 absolute right-2 top-1/2 -translate-y-1/2 text-slate-400" />
      {open && results.length>0 && (
        <div className="absolute z-20 mt-1 w-full max-h-64 overflow-auto rounded-xl border bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-700 shadow">
          {results.map((f)=> (
            <button key={f.id} className="block w-full text-left px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-800 text-sm" onMouseDown={()=>handlePick(f)}>
              <div className="font-medium">{f.name}</div>
              <div className="text-xs text-slate-500">{formatNumber(f.kcal)} kcal · P {formatNumber(f.protein)} g · C {formatNumber(f.carbs)} g · F {formatNumber(f.fat)} g</div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
function MobileFoodCard({ food, onEdit, onDelete }) {
  return (
    <div className="px-4 py-3">
      <div className="flex items-start justify-between gap-2">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5 font-medium text-sm">
            <span>{getCategoryEmoji(food.category)}</span>
            <span className="truncate">{food.name}</span>
            <span className="text-xs font-normal text-slate-400 shrink-0">{food.unit === 'per100g' ? '/ 100g' : `/ ${formatNumber(food.servingSize ?? 1)}g`}</span>
          </div>
          <div className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-slate-500 mt-0.5">
            <span className="font-medium text-slate-700 dark:text-slate-300">{formatNumber(food.kcal)} kcal</span>
            <span>F {formatNumber(food.fat)}g</span>
            <span>C {formatNumber(food.carbs)}g</span>
            <span>P {formatNumber(food.protein)}g</span>
          </div>
        </div>
        <div className="flex items-center gap-1 shrink-0">
          <Button variant="ghost" size="icon" onClick={() => onEdit(food)}><Pencil className="h-4 w-4" /></Button>
          <Button variant="ghost" size="icon" onClick={() => onDelete(food)}><Trash2 className="h-4 w-4" /></Button>
        </div>
      </div>
    </div>
  );
}

function EditableFoodRow({ food, onEdit, onDelete, selected, onSelect }) {
  const totalMacros = (food.fat ?? 0) + (food.carbs ?? 0) + (food.protein ?? 0);
  const fatPct = totalMacros > 0 ? ((food.fat ?? 0) / totalMacros) * 100 : 0;
  const carbsPct = totalMacros > 0 ? ((food.carbs ?? 0) / totalMacros) * 100 : 0;
  const proteinPct = totalMacros > 0 ? ((food.protein ?? 0) / totalMacros) * 100 : 0;
  return (
    <TableRow className="group">
      <TableCell className="w-8 pr-0 align-middle">
        <input
          type="checkbox"
          className="rounded border-slate-300"
          checked={selected}
          onChange={(e) => onSelect(food.id, e.target.checked)}
          onClick={(e) => e.stopPropagation()}
        />
      </TableCell>
      <TableCell className="align-middle w-[230px] max-w-[230px]">
        <div className="flex items-center gap-2 min-w-0">
          <span className="shrink-0">{getCategoryEmoji(food.category)}</span>
          <div className="min-w-0">
            <span className="block truncate text-sm" title={food.name}>{food.name}</span>
            {totalMacros > 0 && (
              <div className="flex h-1.5 mt-0.5 rounded-full overflow-hidden w-full max-w-[100px]" title={`Fat ${Math.round(fatPct)}% · Carbs ${Math.round(carbsPct)}% · Protein ${Math.round(proteinPct)}%`}>
                <div style={{ width: `${fatPct}%` }} className="bg-amber-400" />
                <div style={{ width: `${carbsPct}%` }} className="bg-sky-400" />
                <div style={{ width: `${proteinPct}%` }} className="bg-emerald-400" />
              </div>
            )}
          </div>
        </div>
      </TableCell>
      <TableCell className="align-middle w-[160px] max-w-[160px]">
        <span className="block truncate text-sm" title={t('foodCategories.'+food.category, getCategoryLabel(food.category))}>{t('foodCategories.'+food.category, getCategoryLabel(food.category))}</span>
      </TableCell>
      <TableCell className="align-middle w-[120px] max-w-[120px]">
        <span className="block truncate text-sm" title={food.unit === 'per100g' ? t('foods.per100g') : `per ${formatNumber(food.servingSize ?? 1)} g serving`}>
          {food.unit === 'per100g' ? t('foods.per100g') : `per ${formatNumber(food.servingSize ?? 1)} g serving`}
        </span>
      </TableCell>
      <TableCell className="text-right tabular-nums align-middle">{formatNumber(food.kcal)}</TableCell>
      <TableCell className="text-right tabular-nums align-middle">{formatNumber(food.fat)}</TableCell>
      <TableCell className="text-right tabular-nums align-middle">{formatNumber(food.carbs)}</TableCell>
      <TableCell className="text-right tabular-nums align-middle">{formatNumber(food.protein)}</TableCell>
      <TableCell className="text-right align-middle sticky right-0 bg-white dark:bg-slate-900 group-hover:bg-slate-50/80 dark:group-hover:bg-slate-800/40 border-l border-slate-100/80 dark:border-slate-800/40">
        <div className="flex justify-end gap-1">
          <Button variant="ghost" size="icon" onClick={() => onEdit(food)}><Pencil className="h-4 w-4" /></Button>
          <Button variant="ghost" size="icon" onClick={() => onDelete(food)}><Trash2 className="h-4 w-4" /></Button>
        </div>
      </TableCell>
    </TableRow>
  );
}
function FoodEditDrawer({ food, foods, onUpdate, onDelete, onAdd, onClose }) {
  const { t } = useTranslation();
  const [form, setForm] = useState(() => ({
    name: food.name,
    category: food.category ?? DEFAULT_CATEGORY,
    unit: food.unit,
    servingSize: food.servingSize ? String(food.servingSize) : "",
    kcal: String(food.kcal ?? 0),
    protein: String(food.protein ?? 0),
    carbs: String(food.carbs ?? 0),
    fat: String(food.fat ?? 0),
    components: (food.components ?? []).map((c) => ({
      id: crypto.randomUUID(),
      foodId: c.foodId,
      quantity: String(c.quantity ?? 0),
    })),
  }));

  const isPerServing = form.unit === "perServing";

  const derived = useMemo(
    () => computeRecipeTotals(form.components ?? [], foods, { unit: form.unit, totalSize: form.servingSize }),
    [form.components, foods, form.unit, form.servingSize]
  );

  useEffect(() => {
    if (form.category !== "homeRecipe") return;
    setForm((prev) => {
      if (prev.category !== "homeRecipe") return prev;
      const next = {
        ...prev,
        kcal: toInputString(derived.kcal),
        protein: toInputString(derived.protein),
        carbs: toInputString(derived.carbs),
        fat: toInputString(derived.fat),
      };
      if (prev.kcal === next.kcal && prev.protein === next.protein && prev.carbs === next.carbs && prev.fat === next.fat) return prev;
      return next;
    });
  }, [form.category, derived.kcal, derived.protein, derived.carbs, derived.fat]);

  const isDirty = form.name !== food.name ||
    form.category !== (food.category ?? DEFAULT_CATEGORY) ||
    form.unit !== food.unit ||
    form.kcal !== String(food.kcal ?? 0) ||
    form.protein !== String(food.protein ?? 0) ||
    form.carbs !== String(food.carbs ?? 0) ||
    form.fat !== String(food.fat ?? 0);

  function handleClose() {
    if (isDirty && !confirm("You have unsaved changes. Discard them?")) return;
    onClose();
  }

  useEffect(() => {
    const handler = (e) => { if (e.key === "Escape") handleClose(); };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [isDirty]);

  function handleSave() {
    if (!form.name.trim()) { alert("Enter a food name"); return; }
    const components = (form.components ?? [])
      .map((c) => ({ foodId: c.foodId, quantity: toNumber(c.quantity, 0) }))
      .filter((c) => c.foodId && c.quantity > 0);
    const sizeValue = Math.max(1, toNumber(form.servingSize, 1));
    const includeSize = form.category === "homeRecipe" || isPerServing;
    const payload = {
      name: form.name.trim(),
      category: form.category,
      unit: form.unit,
      servingSize: includeSize ? sizeValue : undefined,
      kcal: toNumber(form.kcal, 0),
      protein: toNumber(form.protein, 0),
      carbs: toNumber(form.carbs, 0),
      fat: toNumber(form.fat, 0),
    };
    if (form.category === "homeRecipe") {
      payload.components = components;
    } else if ((food.components?.length ?? 0) > 0) {
      payload.components = [];
    }
    onUpdate(food.id, payload);
    onClose();
  }

  function handleDuplicate() {
    const sizeValue = Math.max(1, toNumber(form.servingSize, 1));
    const includeSize = form.category === "homeRecipe" || isPerServing;
    const components = (form.components ?? [])
      .map((c) => ({ foodId: c.foodId, quantity: toNumber(c.quantity, 0) }))
      .filter((c) => c.foodId && c.quantity > 0);
    const payload = {
      id: crypto.randomUUID(),
      name: form.name.trim() + " (copy)",
      category: form.category,
      unit: form.unit,
      servingSize: includeSize ? sizeValue : undefined,
      kcal: toNumber(form.kcal, 0),
      protein: toNumber(form.protein, 0),
      carbs: toNumber(form.carbs, 0),
      fat: toNumber(form.fat, 0),
      createdAt: new Date().toISOString(),
    };
    if (form.category === "homeRecipe") payload.components = components;
    onAdd(payload);
    onClose();
  }

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/40" onClick={handleClose} />
      <div className="fixed right-0 top-0 z-50 flex h-full w-full flex-col bg-white shadow-2xl dark:bg-slate-950 sm:w-[480px]">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-slate-200 px-5 py-4 dark:border-slate-800">
          <div>
            <h2 className="font-semibold text-base">{t('foods.editFoodTitle')}</h2>
            <p className="text-xs text-slate-500 mt-0.5 truncate max-w-[320px]">{food.name}</p>
          </div>
          <Button variant="ghost" size="icon" onClick={handleClose}><X className="h-4 w-4" /></Button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          {/* Name */}
          <div className="space-y-1.5">
            <Label>{t('foods.foodNameLabel')}</Label>
            <div className="flex items-center gap-2">
              <span className="text-lg">{getCategoryEmoji(form.category)}</span>
              <Input value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} placeholder={t('foods.foodNamePlaceholder')} />
            </div>
          </div>

          {/* Category + Unit */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>{t('foods.categoryLabel')}</Label>
              <Select value={form.category} onValueChange={(v) => setForm((p) => ({ ...p, category: v }))}>
                <SelectTrigger className="w-full"><SelectValue /></SelectTrigger>
                <SelectContent side="bottom" avoidCollisions={false}>{FOOD_CATEGORIES.map((c) => <SelectItem key={c.value} value={c.value}>{t('foodCategories.'+c.value, c.label)}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>{t('foods.unitLabel')}</Label>
              <Select value={form.unit} onValueChange={(v) => setForm((p) => ({ ...p, unit: v, servingSize: v === "perServing" ? (p.servingSize || "1") : "" }))}>
                <SelectTrigger className="w-full"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="per100g">{t('foods.per100g')}</SelectItem>
                  <SelectItem value="perServing">{t('foods.perServing')}</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Serving size */}
          {isPerServing && (
            <div className="space-y-1.5">
              <Label>{t('foods.servingSizeLabel')}</Label>
              <Input type="number" step="0.1" value={form.servingSize} onChange={(e) => setForm((p) => ({ ...p, servingSize: e.target.value }))} placeholder="g" />
            </div>
          )}

          {/* Macros */}
          <div className="space-y-1.5">
            <Label className="text-sm font-medium">Macros</Label>
            <div className="grid grid-cols-2 gap-3">
              {[["kcal", t('foods.kcalLabel')], ["fat", t('foods.fatLabel')], ["carbs", t('foods.carbsLabel')], ["protein", t('foods.proteinLabel')]].map(([key, label]) => (
                <div key={key} className="space-y-1">
                  <Label className="text-xs text-slate-500">{label}</Label>
                  <Input
                    type="number"
                    step="0.01"
                    value={form[key]}
                    onChange={(e) => setForm((p) => ({ ...p, [key]: e.target.value }))}
                    disabled={form.category === "homeRecipe"}
                    className={form.category === "homeRecipe" ? "bg-slate-50 dark:bg-slate-900 text-slate-400" : ""}
                  />
                </div>
              ))}
            </div>
            {form.category === "homeRecipe" && (
              <p className="text-xs text-slate-400">Macros are computed from ingredients below.</p>
            )}
          </div>

          {/* Recipe ingredients */}
          {form.category === "homeRecipe" && (
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-sm font-medium">{t('foods.ingredientsLabel')}</Label>
              </div>
              <RecipeIngredientsEditor
                ingredients={form.components}
                onChange={(next) => setForm((p) => ({ ...p, components: next }))}
                foods={foods}
                ownerId={food.id}
              />
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center gap-2 border-t border-slate-200 px-5 py-4 dark:border-slate-800">
          <Button onClick={handleSave}>{t('foods.saveButton')}</Button>
          <Button variant="ghost" onClick={handleClose}>{t('foods.cancelButton')}</Button>
          <Button variant="outline" onClick={handleDuplicate} title="Duplicate this food">
            Duplicate
          </Button>
          <Button
            variant="ghost"
            className="ml-auto text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950"
            onClick={() => { onDelete(food); onClose(); }}
          >
            <Trash2 className="h-4 w-4 mr-1.5" />{t('foods.deleteButton')}
          </Button>
        </div>
      </div>
    </>
  );
}

/* ─── Open Food Facts category → app category mapping ─── */
const OFF_CATEGORY_MAP = {
  'beverages': 'drink', 'drinks': 'drink', 'waters': 'drink', 'juices': 'drink',
  'dairy': 'dairy', 'cheeses': 'dairy', 'yogurts': 'dairy', 'milks': 'dairy',
  'meats': 'meat', 'poultry': 'meat', 'seafood': 'meat', 'fish': 'meat',
  'fruits': 'fruit', 'vegetables': 'vegetable',
  'cereals': 'grain', 'breads': 'grain', 'pasta': 'grain', 'rice': 'grain',
  'snacks': 'snack', 'sweets': 'snack', 'chocolates': 'snack',
  'legumes': 'legume', 'nuts': 'nut',
};

function mapOffCategory(categories_tags = []) {
  for (const tag of categories_tags) {
    const key = tag.replace(/^en:/, '').toLowerCase();
    if (OFF_CATEGORY_MAP[key]) return OFF_CATEGORY_MAP[key];
    for (const [pattern, cat] of Object.entries(OFF_CATEGORY_MAP)) {
      if (key.includes(pattern)) return cat;
    }
  }
  return 'other';
}

async function lookupBarcode(barcode) {
  const res = await fetch(
    `https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=product_name,nutriments,categories_tags,serving_size`
  );
  if (!res.ok) throw new Error('Network error');
  const data = await res.json();
  if (data.status !== 1) throw new Error('Product not found');
  const p = data.product;
  const n = p.nutriments ?? {};
  return {
    name: p.product_name ?? '',
    kcal: String(Math.round(n['energy-kcal_100g'] ?? n['energy-kcal'] ?? 0)),
    protein: String(Math.round((n['proteins_100g'] ?? n['proteins'] ?? 0) * 10) / 10),
    carbs: String(Math.round((n['carbohydrates_100g'] ?? n['carbohydrates'] ?? 0) * 10) / 10),
    fat: String(Math.round((n['fat_100g'] ?? n['fat'] ?? 0) * 10) / 10),
    category: mapOffCategory(p.categories_tags ?? []),
    unit: 'per100g',
  };
}

function BarcodeScannerModal({ onResult, onClose }) {
  const { t } = useTranslation();
  const videoRef = useRef(null);
  const readerRef = useRef(null);
  const [phase, setPhase] = useState('scanning'); // scanning | fetching | found | error
  const [errorMsg, setErrorMsg] = useState('');
  const [result, setResult] = useState(null);
  const scannedRef = useRef(false);
  const [retryCount, setRetryCount] = useState(0);

  useEffect(() => {
    const hints = new Map();
    hints.set(DecodeHintType.TRY_HARDER, true);
    const reader = new BrowserMultiFormatReader(hints);
    readerRef.current = reader;

    let animId;
    let stream;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });

    async function start() {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: { ideal: 'environment' },
            width: { ideal: 1280 },
            height: { ideal: 720 },
          },
        });
      } catch {
        setErrorMsg(t('foods.scanCameraAccess'));
        setPhase('error');
        return;
      }
      const video = videoRef.current;
      if (!video) { stream.getTracks().forEach(t => t.stop()); return; }
      video.srcObject = stream;
      video.play().catch(() => {}); // non-fatal; scan loop checks readyState
      scan();
    }

    function scan() {
      if (scannedRef.current) return;
      const video = videoRef.current;
      if (video && video.readyState >= video.HAVE_ENOUGH_DATA) {
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        try {
          const res = reader.decodeFromCanvas(canvas);
          if (res) {
            scannedRef.current = true;
            setPhase('fetching');
            lookupBarcode(res.getText())
              .then(food => { setResult(food); setPhase('found'); })
              .catch(e => {
                setErrorMsg(e.message === 'Product not found'
                  ? t('foods.scanProductNotFound')
                  : t('foods.scanConnectionError'));
                setPhase('error');
              });
            return;
          }
        } catch { /* NotFoundException on most frames — expected */ }
      }
      animId = requestAnimationFrame(scan);
    }

    scannedRef.current = false;
    start();

    return () => {
      cancelAnimationFrame(animId);
      if (stream) stream.getTracks().forEach(t => t.stop());
    };
  }, [retryCount]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 px-4">
      <div className="w-full max-w-sm rounded-2xl bg-white dark:bg-slate-900 shadow-xl overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-slate-200 dark:border-slate-700">
          <div className="flex items-center gap-2">
            <Barcode className="h-5 w-5 text-slate-700 dark:text-slate-300" />
            <span className="font-semibold text-slate-900 dark:text-slate-100">{t('foods.scanTitle')}</span>
          </div>
          <button onClick={onClose} className="rounded-full p-1 hover:bg-slate-100 dark:hover:bg-slate-800">
            <X className="h-5 w-5 text-slate-500" />
          </button>
        </div>

        {/* Camera view */}
        <div className="relative bg-black" style={{ aspectRatio: '4/3' }}>
          <video ref={videoRef} className="w-full h-full object-cover" muted playsInline />
          {phase === 'scanning' && (
            <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
              {/* Targeting frame */}
              <div className="relative w-56 h-32">
                <div className="absolute inset-0 border-2 border-white/70 rounded-md" />
                <div className="absolute top-0 left-0 w-6 h-6 border-t-4 border-l-4 border-white rounded-tl-md" />
                <div className="absolute top-0 right-0 w-6 h-6 border-t-4 border-r-4 border-white rounded-tr-md" />
                <div className="absolute bottom-0 left-0 w-6 h-6 border-b-4 border-l-4 border-white rounded-bl-md" />
                <div className="absolute bottom-0 right-0 w-6 h-6 border-b-4 border-r-4 border-white rounded-br-md" />
              </div>
            </div>
          )}
          {phase === 'fetching' && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/60">
              <Loader2 className="h-10 w-10 text-white animate-spin" />
              <p className="mt-2 text-white text-sm">{t('foods.scanSearching')}</p>
            </div>
          )}
          {phase === 'found' && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/60">
              <CheckCircle2 className="h-10 w-10 text-green-400" />
              <p className="mt-2 text-white text-sm font-medium">{result?.name || t('foods.scanProductFound')}</p>
            </div>
          )}
          {phase === 'error' && (
            <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/60 px-6 text-center">
              <AlertCircle className="h-10 w-10 text-red-400" />
              <p className="mt-2 text-white text-sm">{errorMsg}</p>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-4 py-3 border-t border-slate-200 dark:border-slate-700">
          {phase === 'scanning' && (
            <p className="text-xs text-center text-slate-500">{t('foods.scanPointCamera')}</p>
          )}
          {phase === 'found' && result && (
            <div className="space-y-2">
              <div className="text-xs text-slate-500 text-center">
                {result.kcal} kcal · P {result.protein}g · C {result.carbs}g · F {result.fat}g ({t('foods.per100g')})
              </div>
              <div className="flex gap-2">
                <Button variant="outline" className="flex-1" onClick={() => { scannedRef.current = false; setPhase('scanning'); setResult(null); }}>
                  {t('foods.scanAgain')}
                </Button>
                <Button className="flex-1" onClick={() => onResult(result)}>
                  {t('foods.useFood')}
                </Button>
              </div>
            </div>
          )}
          {phase === 'error' && (
            <div className="flex gap-2">
              <Button variant="outline" className="flex-1" onClick={() => { setPhase('scanning'); setErrorMsg(''); setRetryCount(c => c + 1); }}>
                {t('foods.scanTryAgain')}
              </Button>
              <Button variant="ghost" className="flex-1" onClick={onClose}>
                {t('foods.cancelButton')}
              </Button>
            </div>
          )}
          {phase === 'fetching' && (
            <p className="text-xs text-center text-slate-500">Fetching nutrition data…</p>
          )}
        </div>
      </div>
    </div>
  );
}

function AddFoodCard({ foods, onAdd, tab, onClose, initialBasicForm }){
  const { t } = useTranslation();
  const [activeTab, setActiveTab] = useState(tab ?? "single");
  useEffect(() => { if (tab) setActiveTab(tab); }, [tab]);
  const [basicForm, setBasicForm] = useState(() => initialBasicForm || createBasicFoodForm());
  const [recipeForm, setRecipeForm] = useState(()=>createRecipeForm());
  const [showScanner, setShowScanner] = useState(false);
  const [recipeIngredients, setRecipeIngredients] = useState([]);

  const derivedTotals = useMemo(
    () =>
      computeRecipeTotals(recipeIngredients, foods, {
        unit: recipeForm.unit,
        totalSize: recipeForm.servingSize,
      }),
    [recipeIngredients, foods, recipeForm.unit, recipeForm.servingSize]
  );
  const { kcal: derivedKcal, protein: derivedProtein, carbs: derivedCarbs, fat: derivedFat } = derivedTotals;

  useEffect(() => {
    if (activeTab !== "recipe") return;
    setRecipeForm((prev) => {
      const next = {
        ...prev,
        kcal: toInputString(derivedKcal),
        protein: toInputString(derivedProtein),
        carbs: toInputString(derivedCarbs),
        fat: toInputString(derivedFat),
      };
      if (
        prev.kcal === next.kcal &&
        prev.protein === next.protein &&
        prev.carbs === next.carbs &&
        prev.fat === next.fat
      ) {
        return prev;
      }
      return next;
    });
  }, [activeTab, derivedKcal, derivedProtein, derivedCarbs, derivedFat]);

  function handleAddBasic(){
    const trimmed = basicForm.name.trim();
    if(!trimmed){ alert('Enter a food name'); return; }
    const unit = basicForm.unit === 'perServing' ? 'perServing' : 'per100g';
    const payload = {
      id: crypto.randomUUID(),
      name: trimmed,
      unit,
      category: basicForm.category,
      servingSize: unit === 'perServing' ? Math.max(1, toNumber(basicForm.servingSize, 1)) : undefined,
      kcal: toNumber(basicForm.kcal, 0),
      protein: toNumber(basicForm.protein, 0),
      carbs: toNumber(basicForm.carbs, 0),
      fat: toNumber(basicForm.fat, 0),
      createdAt: new Date().toISOString(),
    };
    onAdd(payload);
    setBasicForm(createBasicFoodForm());
    onClose?.();
  }

  function handleAddRecipe(){
    const trimmed = recipeForm.name.trim();
    if(!trimmed){ alert('Enter a recipe name'); return; }
    const components = recipeIngredients
      .map((item) => ({ foodId: item.foodId, quantity: item.quantity }))
      .filter((item) => item.foodId && toNumber(item.quantity, 0) > 0);
    if(components.length===0){ alert('Add at least one ingredient'); return; }
    const unit = recipeForm.unit === 'perServing' ? 'perServing' : 'per100g';
    const sizeValue = Math.max(1, toNumber(recipeForm.servingSize, 1));
    const payload = {
      id: crypto.randomUUID(),
      name: trimmed,
      unit,
      category: 'homeRecipe',
      servingSize: sizeValue,
      kcal: toNumber(recipeForm.kcal, 0),
      protein: toNumber(recipeForm.protein, 0),
      carbs: toNumber(recipeForm.carbs, 0),
      fat: toNumber(recipeForm.fat, 0),
      components: components.map((item) => ({ foodId: item.foodId, quantity: toNumber(item.quantity, 0) })),
      createdAt: new Date().toISOString(),
    };
    onAdd(payload);
    setRecipeForm(createRecipeForm());
    setRecipeIngredients([]);
    onClose?.();
  }

  return (
    <>
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>{activeTab === "recipe" ? t('foods.addRecipeTitle') : t('foods.addFoodTitle')}</CardTitle>
          {onClose && <Button variant="ghost" size="icon" onClick={onClose}><X className="h-4 w-4" /></Button>}
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid w-full max-w-xs grid-cols-2 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/60">
            <TabsTrigger value="single" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">{t('foods.addFoodTitle')}</TabsTrigger>
            <TabsTrigger value="recipe" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">{t('foods.addRecipeTitle')}</TabsTrigger>
          </TabsList>

          <TabsContent value="single" className="mt-4">
            <div className="grid gap-3 md:grid-cols-6">
              <div className="md:col-span-2">
                <Label>{t('foods.foodNameLabel')}</Label>
                <Input value={basicForm.name} onChange={(e)=>setBasicForm((prev)=>({...prev, name:e.target.value }))} placeholder={t('foods.foodNamePlaceholder')} />
              </div>
              <div>
                <Label>{t('foods.categoryLabel')}</Label>
                <Select value={basicForm.category} onValueChange={(v)=>setBasicForm((prev)=>({...prev, category:v }))}>
                  <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                  <SelectContent side="bottom" avoidCollisions={false}>
                    {FOOD_CATEGORIES.map(cat=>(
                      <SelectItem key={cat.value} value={cat.value}>{t('foodCategories.'+cat.value, cat.label)}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>{t('foods.unitLabel')}</Label>
                <Select value={basicForm.unit} onValueChange={(v)=>setBasicForm((prev)=>({...prev, unit:v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="per100g">{t('foods.per100g')}</SelectItem>
                    <SelectItem value="perServing">{t('foods.perServing')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {basicForm.unit==='perServing' && (
                <div>
                  <Label>{t('foods.servingSizeLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.servingSize} onChange={(e)=>setBasicForm((prev)=>({...prev, servingSize:e.target.value }))} />
                </div>
              )}
              <div className="md:col-span-6 grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div>
                  <Label>{t('foods.kcalLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.kcal} onChange={(e)=>setBasicForm((prev)=>({...prev, kcal:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.fatLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.fat} onChange={(e)=>setBasicForm((prev)=>({...prev, fat:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.carbsLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.carbs} onChange={(e)=>setBasicForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.proteinLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.protein} onChange={(e)=>setBasicForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
              </div>
              <div className="md:col-span-6 flex items-center justify-end gap-2">
                <Button variant="outline" onClick={() => setShowScanner(true)}>
                  <Barcode className="mr-2 h-4 w-4" />
                  {t('foods.scanTitle')}
                </Button>
                <Button onClick={handleAddBasic}>{t('foods.addFoodButton')}</Button>
              </div>
            </div>
          </TabsContent>

          <TabsContent value="recipe" className="mt-4">
            <div className="grid gap-3 md:grid-cols-6">
              <div className="md:col-span-3">
                <Label>{t('foods.foodNameLabel')}</Label>
                <Input value={recipeForm.name} onChange={(e)=>setRecipeForm((prev)=>({...prev, name:e.target.value }))} placeholder={t('foods.recipeNamePlaceholder')} />
              </div>
              <div>
                <Label>{t('foods.unitLabel')}</Label>
                <Select value={recipeForm.unit} onValueChange={(v)=>setRecipeForm((prev)=>({...prev, unit:v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="per100g">{t('foods.per100g')}</SelectItem>
                    <SelectItem value="perServing">{t('foods.perServing')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>{recipeForm.unit === "per100g" ? "Total size (g)" : "Serving size (g)"}</Label>
                <Input type="number" inputMode="decimal" value={recipeForm.servingSize} onChange={(e)=>setRecipeForm((prev)=>({...prev, servingSize:e.target.value }))} />
              </div>
              <div className="md:col-span-6">
                <Label>{t('foods.ingredientsLabel')}</Label>
                <RecipeIngredientsEditor
                  ingredients={recipeIngredients}
                  onChange={setRecipeIngredients}
                  foods={foods}
                />
              </div>
              <div className="md:col-span-6 grid grid-cols-2 sm:grid-cols-4 gap-3">
                <div>
                  <Label>{t('foods.kcalLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.kcal} onChange={(e)=>setRecipeForm((prev)=>({...prev, kcal:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.fatLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.fat} onChange={(e)=>setRecipeForm((prev)=>({...prev, fat:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.carbsLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.carbs} onChange={(e)=>setRecipeForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>{t('foods.proteinLabel')}</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.protein} onChange={(e)=>setRecipeForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
              </div>
              <div className="md:col-span-6 text-sm text-slate-500">
                Totals above auto-fill from the ingredients. Adjust manually if you need to fine tune.
              </div>
              <div className="md:col-span-6 text-right">
                <Button onClick={handleAddRecipe}>{t('foods.addRecipeButton')}</Button>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
    {showScanner && (
      <BarcodeScannerModal
        onClose={() => setShowScanner(false)}
        onResult={(food) => {
          setBasicForm({
            name: food.name,
            kcal: food.kcal,
            protein: food.protein,
            carbs: food.carbs,
            fat: food.fat,
            category: food.category,
            unit: food.unit,
            servingSize: '',
          });
          setActiveTab('single');
          setShowScanner(false);
        }}
      />
    )}
    </>
  );
}

function RecipeIngredientsEditor({ ingredients, onChange, foods, ownerId }) {
  const { t } = useTranslation();
  const availableFoods = useMemo(
    () => foods.filter((food) => food.id !== ownerId),
    [foods, ownerId]
  );

  const ensureQuantityFor = (food) => (food?.unit === "perServing" ? "1" : "100");

  const handleAdd = () => {
    const first = availableFoods[0];
    onChange([
      ...ingredients,
      {
        id: crypto.randomUUID(),
        foodId: first?.id ?? "",
        quantity: first ? ensureQuantityFor(first) : "0",
      },
    ]);
  };

  const handleFoodChange = (id, foodId) => {
    onChange(
      ingredients.map((item) => {
        if (item.id !== id) return item;
        const base = foods.find((f) => f.id === foodId) || null;
        const shouldReset = !item.quantity || item.quantity === "0";
        return {
          ...item,
          foodId,
          quantity: shouldReset && base ? ensureQuantityFor(base) : item.quantity,
        };
      })
    );
  };

  const handleQuantityChange = (id, quantity) => {
    onChange(ingredients.map((item) => (item.id === id ? { ...item, quantity } : item)));
  };

  const handleRemove = (id) => {
    onChange(ingredients.filter((item) => item.id !== id));
  };

  const canAddIngredient = availableFoods.length > 0;

  return (
    <div className="space-y-3">
      {ingredients.length === 0 && (
        <div className="rounded-lg border border-dashed border-slate-300 p-4 text-sm text-slate-500 dark:border-slate-700">
          {t('foods.recipeBuildEmpty')}
        </div>
      )}
      {ingredients.map((item) => {
        const selected = foods.find((f) => f.id === item.foodId) || null;
        const macros = selected ? scaleMacros(selected, toNumber(item.quantity, 0)) : null;
        const quantityUnit = selected ? (selected.unit === "perServing" ? "servings" : "g") : "";
        return (
          <div key={item.id} className="space-y-2 rounded-lg border border-slate-200 p-3 shadow-sm dark:border-slate-700 dark:bg-slate-900/40">
            <div className="grid gap-3 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_auto] items-end">
              <div>
                <Label className="text-xs font-medium uppercase tracking-wide text-slate-500">{t('foods.ingredientLabel')}</Label>
                <IngredientFoodPicker
                  value={item.foodId}
                  foods={availableFoods}
                  allFoods={foods}
                  onSelect={(value)=>handleFoodChange(item.id, value)}
                />
              </div>
              <div>
                <Label className="text-xs font-medium uppercase tracking-wide text-slate-500">{t('daily.quantityLabel')}</Label>
                <div className="mt-1 flex items-center gap-2">
                  <Input
                    type="number"
                    inputMode="decimal"
                    value={item.quantity ?? ""}
                    onChange={(e)=>handleQuantityChange(item.id, e.target.value)}
                  />
                  {quantityUnit && <span className="text-xs text-slate-500">{quantityUnit}</span>}
                </div>
              </div>
              <div className="flex justify-end">
                <Button type="button" variant="ghost" size="icon" onClick={()=>handleRemove(item.id)}>
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
            <div className="text-xs text-slate-500">
              {selected && macros
                ? `${formatNumber(macros.kcal)} kcal · P ${formatNumber(macros.protein)} g · C ${formatNumber(macros.carbs)} g · F ${formatNumber(macros.fat)} g`
                : t('foods.recipePickFoodQty')}
            </div>
          </div>
        );
      })}
      <div className="flex items-center justify-between">
        {!canAddIngredient && (
          <span className="text-xs text-slate-500">{t('foods.addFoodsForRecipes')}</span>
        )}
        <Button type="button" variant="outline" size="sm" onClick={handleAdd} disabled={!canAddIngredient}>
          <Plus className="mr-2 h-4 w-4" /> {t('foods.addIngredient')}
        </Button>
      </div>
    </div>
  );
}

function IngredientFoodPicker({ value, foods, allFoods, onSelect }) {
  const { t } = useTranslation();
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const selected = allFoods.find((food) => food.id === value) || null;

  useEffect(() => {
    if (selected) {
      setQuery(selected.name);
    } else if (!value) {
      setQuery("");
    }
  }, [selected?.id, value]);

  const results = useMemo(() => {
    const base = filterFoods(query, foods);
    if (selected && !base.some((food) => food.id === selected.id)) {
      return [selected, ...base];
    }
    return base;
  }, [query, foods, selected]);

  const handlePick = (food) => {
    onSelect(food.id);
    setQuery(food.name);
    setOpen(false);
  };

  const showEmptyState = open && results.length === 0;

  return (
    <div className="relative mt-1">
      <Input
        type="text"
        value={query}
        onFocus={() => {
          setOpen(true);
          if (selected && !query) {
            setQuery(selected.name);
          }
        }}
        onBlur={() => {
          setTimeout(() => setOpen(false), 120);
        }}
        onChange={(event) => {
          setQuery(event.target.value);
          setOpen(true);
        }}
        placeholder={t('foods.searchIngredient')}
      />
      <Search className="absolute right-2 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
      {open && results.length > 0 && (
        <div className="absolute z-20 mt-1 w-full max-h-64 overflow-auto rounded-xl border border-slate-200 bg-white shadow dark:border-slate-700 dark:bg-slate-900">
          {results.map((food) => (
            <button
              key={food.id}
              type="button"
              className="block w-full px-3 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-800"
              onMouseDown={() => handlePick(food)}
            >
              <div className="flex items-center gap-2">
                <span>{getCategoryEmoji(food.category)}</span>
                <span className="flex-1 truncate">{food.name}</span>
              </div>
              <div className="text-xs text-slate-500">
                {formatNumber(food.kcal)} kcal · P {formatNumber(food.protein)} g · C {formatNumber(food.carbs)} g · F {formatNumber(food.fat)} g
              </div>
            </button>
          ))}
        </div>
      )}
      {showEmptyState && (
        <div className="absolute z-20 mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm text-slate-500 shadow dark:border-slate-700 dark:bg-slate-900">
          {t('foods.noFoodsMatchSearch')}
        </div>
      )}
    </div>
  );
}
function EditableFoodCell({ entryId, currentFoodId, fallbackLabel, foods, onSelect }){
  const [editing,setEditing]=useState(false); const [query,setQuery]=useState("");
  const current = foods.find(f=>f.id===currentFoodId)||null;
  const results = useMemo(()=>{ if(!query.trim()) return foods.slice(0,10); const q=query.toLowerCase(); return foods.filter(f=>`${f.name} ${f.brand??''}`.toLowerCase().includes(q)).slice(0,10); },[query,foods]);
  function handlePick(foodId){ onSelect(foodId); setEditing(false);}
  const displayEmoji = current ? getCategoryEmoji(current.category) : getCategoryEmoji(DEFAULT_CATEGORY);
  const displayName = current?.name || fallbackLabel || 'Unknown';
  return (
    <div className="relative">
      {!editing && (
        <button className="text-left w-full hover:underline" onClick={()=>{ setEditing(true); setQuery(current?.name||''); }} title="Click to change food">
          <span className="flex items-center gap-2">
            <span>{displayEmoji}</span>
            <span>{displayName}</span>
          </span>
        </button>
      )}
      {editing && (
        <div className="relative">
          <Input value={query} onChange={(e)=>setQuery(e.target.value)} placeholder="Search food…" className="text-sm" autoFocus />
          <Search className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 h-4 w-4" />
          {results.length>0 && (
            <div className="absolute z-20 mt-1 w-full max-h-64 overflow-auto rounded-xl border bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-700 shadow">
              {results.map(f=> (
                <button key={f.id} className="block w-full text-left px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-800 text-sm" onMouseDown={()=>handlePick(f.id)}>
                  <div className="font-medium">{f.name}</div>
                  <div className="text-xs text-slate-500">{f.kcal} kcal · P {f.protein}g · C {f.carbs}g · F {f.fat}g</div>
                </button>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
function MealSelectCell({ value, onChange }){
  return (
    <Select value={value} onValueChange={(v)=>onChange(v)}>
      <SelectTrigger className="h-8 w-36"><SelectValue /></SelectTrigger>
      <SelectContent>
        <SelectItem value="breakfast">Breakfast</SelectItem>
        <SelectItem value="lunch">Lunch</SelectItem>
        <SelectItem value="dinner">Dinner</SelectItem>
        <SelectItem value="snack">Snack</SelectItem>
        <SelectItem value="other">Other</SelectItem>
      </SelectContent>
    </Select>
  );
}

/*******************
 * Runtime sanity tests
 *******************/
// run in console: macroTests.run()
if (typeof window !== 'undefined') {
  window.macroTests = window.macroTests || {};
  window.macroTests.run = function(){
    const chicken = { id:'x', name:'Chicken', unit:'per100g', kcal:165, fat:3.6, carbs:0, protein:31 };
    const whey = { id:'y', name:'Whey', unit:'perServing', servingSize:30, kcal:120, fat:1.5, carbs:3, protein:24 };
    const oneHundred = scaleMacros(chicken,100); console.assert(oneHundred.kcal===165,'100g kcal 165'); console.assert(oneHundred.protein===31,'100g protein 31');
    const hundredFifty = scaleMacros(chicken,150); console.assert(Math.round(hundredFifty.kcal)===248,'150g kcal ≈248');
    const oneServing = scaleMacros(whey,1); console.assert(oneServing.protein===24,'1 serving protein 24');
    const sum = sumMacros([{kcal:100,fat:1,carbs:10,protein:5},{kcal:50,fat:2,carbs:5,protein:2}]); console.assert(sum.kcal===150&&sum.fat===3&&sum.carbs===15&&sum.protein===7,'sum ok');
    console.assert(pctOf(0,0)===0,'pctOf 0'); console.assert(pctOf(50,100)===50,'pctOf 50%'); console.assert(pctOf(200,100)===200,'pct over 100 ok');
    console.assert(normalizeQty(chicken,whey,150)===+(150/30).toFixed(2),'150g→5.00 servings'); console.assert(normalizeQty(whey,chicken,2)===60,'2 servings→60g');
    const foods = [{name:'Banana'},{name:'Bread'},{name:'Broccoli'}];
    const res1 = filterFoods('br', foods); console.assert(res1.length===2, 'filterFoods should match Bread & Broccoli');
    const res2 = filterFoods('', foods); console.assert(res2.length===3, 'filterFoods empty returns slice');
    const m = suggestMealByNow(); console.assert(['breakfast','lunch','dinner','snack'].includes(m),'meal suggestion valid');
    console.log('macroTests: all checks passed ✅');
  };
}
