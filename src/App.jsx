// MacroTracker v3.7 — Patch on your original file
// Changes from your App.jsx:
// 1) Goal vs Actual donuts now show % > 100 when over budget.
// 2) Sticky header KPIs show "X over" in dark red when exceeding goals.
//    (Everything else left untouched.)

import React, { Fragment, useCallback, useEffect, useMemo, useRef, useState, useId } from "react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import { Card, CardHeader, CardContent, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";
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
  Cell,
} from "recharts";
import {
  Calendar as CalendarIcon,
  Plus,
  Trash2,
  Settings as SettingsIcon,
  Upload,
  Download,
  Moon,
  SunMedium,
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
} from "lucide-react";
import { format, startOfDay, subDays, startOfMonth, startOfQuarter, startOfYear, eachDayOfInterval, startOfWeek, endOfWeek } from "date-fns";

/*******************
 * Types (for readability only)
 *******************/
/** @typedef {'breakfast'|'lunch'|'dinner'|'snack'|'other'} MealKey */
/** @typedef {{id:string,name:string,brand?:string,unit:'per100g'|'perServing',servingSize?:number,kcal:number,fat:number,carbs:number,protein:number,category:string,components?:Ingredient[]}} Food */
/** @typedef {{foodId:string,quantity:number}} Ingredient */
/** @typedef {{id:string,date:string,foodId?:string,label?:string,qty:number,meal:MealKey}} Entry */

/*******************
 * Constants & Utils
 *******************/
const K_FOODS = "mt_foods";
const K_ENTRIES = "mt_entries";
const K_SETTINGS = "mt_settings";
const K_THEME = "mt_theme"; // 'system' | 'light' | 'dark'

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
  const servingSize = unit === "perServing" ? Math.max(1, toNumber(food.servingSize ?? 0, 1)) : undefined;
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
  sanitizeFood({ id: crypto.randomUUID(), name: "Chicken Breast (cooked)", unit: "per100g", category: "meat", kcal: 165, fat: 3.6, carbs: 0, protein: 31 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "White Rice (cooked)", unit: "per100g", category: "grains", kcal: 130, fat: 0.3, carbs: 28, protein: 2.7 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Olive Oil", unit: "perServing", servingSize: 10, category: "cookingOil", kcal: 88, fat: 10, carbs: 0, protein: 0 }),
  sanitizeFood({ id: crypto.randomUUID(), name: "Apple", unit: "per100g", category: "fruit", kcal: 52, fat: 0.2, carbs: 14, protein: 0.3 }),
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
function sumMacros(rows) {
  return rows.reduce((a, r) => ({
    kcal: a.kcal + r.kcal,
    fat: a.fat + r.fat,
    carbs: a.carbs + r.carbs,
    protein: a.protein + r.protein,
  }), { kcal: 0, fat: 0, carbs: 0, protein: 0 });
}

function computeRecipeTotals(components, foods) {
  if (!Array.isArray(components) || components.length === 0) {
    return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
  }
  const rows = components.map((component) => {
    const food = foods.find((f) => f.id === component.foodId);
    if (!food) return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
    const qty = toNumber(component.quantity, 0);
    if (!Number.isFinite(qty) || qty <= 0) {
      return { kcal: 0, fat: 0, carbs: 0, protein: 0 };
    }
    return scaleMacros(food, qty);
  });
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
  if(h>=16 && h<21) return 'dinner';
  return 'snack';
}

const MEAL_LABELS = { breakfast:'Breakfast', lunch:'Lunch', dinner:'Dinner', snack:'Snack', other:'Other' };
const MEAL_ORDER = ['breakfast','lunch','dinner','snack','other'];

/*******************
 * Main App
 *******************/
export default function MacroTrackerApp(){
  const [theme, setTheme] = useState(load(K_THEME, 'system'));
  const [systemPrefersDark, setSystemPrefersDark] = useState(() => {
    if (typeof window === "undefined") return false;
    return window.matchMedia("(prefers-color-scheme: dark)").matches;
  });
  const resolvedTheme = theme === 'system' ? (systemPrefersDark ? 'dark' : 'light') : theme;
  const [foods, setFoods] = useState(()=> ensureFoods(load(K_FOODS, DEFAULT_FOODS)));
  const [foodSort, setFoodSort] = useState({ column: "createdAt", direction: "desc" });
  const [entries, setEntries] = useState(load(K_ENTRIES, []));
  const [settings, setSettings] = useState(()=> ensureSettings(load(K_SETTINGS, DEFAULT_SETTINGS)));
  const [tab, setTab] = useState('dashboard');
  const isDarkMode = resolvedTheme === 'dark';
  const isFollowingSystem = theme === 'system';
  const toggleTheme = useCallback(() => {
    setTheme((current) => {
      const resolved = current === 'system' ? (systemPrefersDark ? 'dark' : 'light') : current;
      return resolved === 'dark' ? 'light' : 'dark';
    });
  }, [systemPrefersDark]);
  const followSystemTheme = useCallback(() => setTheme('system'), []);
  const themeTooltip = useMemo(() => {
    const label = isDarkMode ? 'Dark' : 'Light';
    const nextLabel = isDarkMode ? 'Light' : 'Dark';
    return isFollowingSystem
      ? `Following system (${label}). Click to switch to ${nextLabel} manually.`
      : `Manual ${label} mode — click to switch to ${nextLabel}.`;
  }, [isDarkMode, isFollowingSystem]);

  // Theme handling
  useEffect(() => {
    if (typeof window === "undefined") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const handleChange = (event) => setSystemPrefersDark(event.matches);
    setSystemPrefersDark(mql.matches);
    mql.addEventListener("change", handleChange);
    return () => mql.removeEventListener("change", handleChange);
  }, []);

  useEffect(() => {
    if (typeof document === "undefined") return;
    const root = document.documentElement;
    const dark = theme === 'system' ? systemPrefersDark : theme === 'dark';
    root.classList.toggle("dark", dark);
    save(K_THEME, theme);
  }, [theme, systemPrefersDark]);

  useEffect(()=>save(K_FOODS, foods),[foods]);
  useEffect(()=>save(K_ENTRIES, entries),[entries]);
  useEffect(()=>save(K_SETTINGS, settings),[settings]);

  // Daily log state
  const [logDate, setLogDate] = useState(todayISO());
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

  const [stickyMode, setStickyMode] = useState('today');
  const [goalDate, setGoalDate] = useState(todayISO());
  const [splitDate, setSplitDate] = useState(todayISO());
  const [topFoodsDate, setTopFoodsDate] = useState(todayISO());

  useEffect(() => {
    const targetDate = ISO_DATE_RE.test(logDate) ? logDate : todayISO();
    setGoalDate((prev) => (prev === targetDate ? prev : targetDate));
    setSplitDate((prev) => (prev === targetDate ? prev : targetDate));
    setTopFoodsDate((prev) => (prev === targetDate ? prev : targetDate));
  }, [logDate]);

  const stickyDate = stickyMode==='today'? todayISO(): logDate;
  const stickyTotals = useMemo(()=> totalsForDate(stickyDate), [entries,foods,stickyDate]);
  const totalsForCard = useMemo(()=> totalsForDate(logDate), [rowsForDay]);

  const profileHistory = useMemo(() => ensureBodyHistory(settings.profileHistory), [settings.profileHistory]);

  const weightTrendSummary = useMemo(() => {
    if (!profileHistory.length) {
      return { data: [], latestWeight: null, latestDate: null };
    }
    const today = startOfDay(new Date());
    const start = subDays(today, 29);
    const startIso = toISODate(start);
    const endIso = toISODate(today);
    const data = profileHistory
      .filter((entry) => entry.date >= startIso && entry.date <= endIso)
      .map((entry) => {
        const weightValue = Number.isFinite(entry.weightKg) ? +Number(entry.weightKg).toFixed(1) : null;
        const bodyFatValue = Number.isFinite(entry.bodyFatPct) ? +Number(entry.bodyFatPct).toFixed(1) : null;
        return {
          date: entry.date,
          label: format(new Date(`${entry.date}T00:00:00`), "MMM d"),
          weight: weightValue,
          bodyFat: bodyFatValue,
        };
      });
    const latest = profileHistory[profileHistory.length - 1];
    return {
      data,
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
      { key: "7d", label: "Average (7d)", averages: computeForDates(recentDates(7)) },
      { key: "mtd", label: "Average (MTD)", averages: computeForDates(rangeDates(startOfMonth(today))) },
      { key: "qtd", label: "Average (QTD)", averages: computeForDates(rangeDates(startOfQuarter(today))) },
      { key: "ytd", label: "Average (YTD)", averages: computeForDates(rangeDates(startOfYear(today))) },
    ];

    const macroKeys = ["kcal", "protein", "carbs", "fat"];
    const macroMaxima = macroKeys.reduce((acc, key) => {
      const maxValue = summaries.reduce((max, summary) => Math.max(max, summary.averages?.[key] ?? 0), 0);
      acc[key] = maxValue > 0 ? maxValue : 1;
      return acc;
    }, {});

    return summaries.map((summary) => ({ ...summary, scaleMax: macroMaxima }));
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

  const stickyEntry = useMemo(() => resolveModeEntry(stickyDate), [resolveModeEntry, stickyDate]);
  const stickyGoals = useMemo(() => getGoalsForEntry(stickyEntry), [getGoalsForEntry, stickyEntry]);
  const dashboardEntry = useMemo(() => resolveModeEntry(logDate), [resolveModeEntry, logDate]);
  const dashboardGoals = useMemo(() => getGoalsForEntry(dashboardEntry), [getGoalsForEntry, dashboardEntry]);
  const goalTargetEntry = useMemo(() => resolveModeEntry(goalDate), [resolveModeEntry, goalDate]);
  const goalTarget = useMemo(() => getGoalsForEntry(goalTargetEntry), [getGoalsForEntry, goalTargetEntry]);
  const logDateEntry = dashboardEntry;
  const splitEntry = useMemo(() => resolveModeEntry(splitDate), [resolveModeEntry, splitDate]);
  const goalDateEntry = goalTargetEntry;
  const topFoodsEntry = useMemo(() => resolveModeEntry(topFoodsDate), [resolveModeEntry, topFoodsDate]);

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
      .filter(e=>e.date===topFoodsDate)
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
  },[entries,foods,topFoodsDate,topMacroKey]);

  const goalTotals = useMemo(()=> totalsForDate(goalDate),[entries, foods, goalDate]);

  const weeklyNutrition = useMemo(() => {
    const targetISO = ISO_DATE_RE.test(goalDate) ? goalDate : todayISO();
    const baseDate = new Date(targetISO);
    const weekStartDate = startOfWeek(baseDate, { weekStartsOn: 1 });
    const weekEndDate = endOfWeek(baseDate, { weekStartsOn: 1 });
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
  }, [goalDate, entries, foods, goalValuesForDate]);

  const entriesForSplitDate = useMemo(()=> entries.filter((e)=>e.date===splitDate),[entries, splitDate]);

  // Meal-split dataset for dashboard (stacked bar)
  const mealSplit = useMemo(()=>{
    const byMeal = { breakfast:{kcal:0,protein:0,carbs:0,fat:0}, lunch:{kcal:0,protein:0,carbs:0,fat:0}, dinner:{kcal:0,protein:0,carbs:0,fat:0}, snack:{kcal:0,protein:0,carbs:0,fat:0}, other:{kcal:0,protein:0,carbs:0,fat:0} };
    entriesForSplitDate.forEach(e=>{ const f=foods.find(x=>x.id===e.foodId); if(!f) return; const m=scaleMacros(f,e.qty); const key = e.meal||'other'; byMeal[key].kcal+=m.kcal; byMeal[key].protein+=m.protein; byMeal[key].carbs+=m.carbs; byMeal[key].fat+=m.fat; });
    return MEAL_ORDER.map(k=>({ meal: MEAL_LABELS[k], ...byMeal[k] }));
  },[entriesForSplitDate,foods]);

  // Mutators
  function addEntry(){ if(!selectedFood||!qty||qty<=0) return; const e={id:crypto.randomUUID(),date:logDate,foodId:selectedFood.id,qty,meal}; setEntries(prev=>[e,...prev]); setQty(0); setSelectedFoodId(null); setMeal(suggestMealByNow()); }
  function removeEntry(id){ setEntries(prev=>prev.filter(e=>e.id!==id)); }
  function updateEntryQuantity(id,newQty){ if(!Number.isFinite(newQty)||newQty<=0) return; setEntries(prev=>prev.map(e=>e.id===id?{...e,qty:newQty}:e)); }
  function updateEntryFood(id,newFoodId){ setEntries(prev=>prev.map(e=>{ if(e.id!==id) return e; const oldFood=foods.find(f=>f.id===e.foodId); const newFood=foods.find(f=>f.id===newFoodId); const newQty=normalizeQty(oldFood,newFood,e.qty); return {...e,foodId:newFoodId,qty:newQty}; })); }
  function updateEntryMeal(id,newMeal){ setEntries(prev=>prev.map(e=>e.id===id?{...e,meal:newMeal}:e)); }
  function addFood(newFood){ setFoods(prev=>[sanitizeFood(newFood),...prev]); }
  function deleteFood(id){ setFoods(prev=>prev.filter(f=>f.id!==id)); }
  function updateFood(foodId, partial){
    setFoods(prev=>{
      const idx = prev.findIndex(f=>f.id===foodId);
      if(idx===-1) return prev;
      const oldFood = prev[idx];
      const updated = sanitizeFood({ ...oldFood, ...partial, id: oldFood.id });
      if(
        oldFood.unit !== updated.unit ||
        (oldFood.unit === "perServing" && updated.unit === "perServing" && oldFood.servingSize !== updated.servingSize)
      ){
        setEntries(prevEntries=>prevEntries.map(e=>{
          if(e.foodId!==foodId) return e;
          const newQty = normalizeQty(oldFood, updated, e.qty);
          return { ...e, qty: newQty };
        }));
      }
      const clone = [...prev];
      clone[idx] = updated;
      return clone;
    });
  }

  function exportJSON(){ const blob = new Blob([JSON.stringify({foods,entries,settings},null,2)],{type:'application/json'}); const url=URL.createObjectURL(blob); const a=document.createElement('a'); a.href=url; a.download=`macrotracker_backup_${todayISO()}.json`; a.click(); URL.revokeObjectURL(url); }
  function importJSON(file){ const reader=new FileReader(); reader.onload=()=>{ try{ const data=JSON.parse(String(reader.result)); if(data.foods) setFoods(ensureFoods(data.foods)); if(data.entries) setEntries(data.entries); if(data.settings) setSettings(ensureSettings(data.settings));}catch{ alert('Invalid JSON file'); } }; reader.readAsText(file); }

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
      return <ArrowUpDown className="h-3.5 w-3.5 opacity-50" />;
    }
    return foodSort.direction === "asc"
      ? <ArrowUp className="h-3.5 w-3.5" />
      : <ArrowDown className="h-3.5 w-3.5" />;
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

  const handleSaveBodyProfile = useCallback(() => {
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
      return {
        ...prev,
        profile: {
          ...profile,
          weightKg: weightValue,
          bodyFatPct: bodyFatValue,
        },
        profileHistory: nextHistory,
      };
    });
  }, [setSettings]);

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-50 to-slate-100 text-slate-900 dark:from-slate-900 dark:to-slate-950 dark:text-slate-100">
      <header className="sticky top-0 z-40 backdrop-blur border-b border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/60">
        <div className="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="h-9 w-9 rounded-2xl bg-slate-900 dark:bg-slate-100 flex items-center justify-center shadow-sm">
              <BarChart3 className="h-5 w-5 text-white dark:text-slate-900" />
            </div>
            <div>
              <h1 className="font-semibold text-lg leading-tight">MacroTracker</h1>
              <p className="text-xs text-slate-500">Track calories, fat, carbs & protein by meal</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Button variant="ghost" className={headerPillClass} onClick={exportJSON}>
              <Download className="h-4 w-4" />
              <span>Export</span>
            </Button>
            <label className={`inline-flex items-center ${headerPillClass} cursor-pointer`}>
              <Upload className="h-4 w-4" />
              <span>Import</span>
              <input type="file" accept="application/json" className="hidden" onChange={(e)=>e.target.files&&importJSON(e.target.files[0])} />
            </label>
            {activeSetup === "dual" ? (
              <GoalModeToggle active={activeDualProfile} onChange={handleDualProfileChange} />
            ) : (
              <GoalModeBadge value={{ setup: activeSetup }} className="h-9 px-4" />
            )}
            <Button variant="ghost" className={headerPillClass} onClick={()=>setTab('settings')}>
              <SettingsIcon className="h-4 w-4"/>
              <span>Settings</span>
            </Button>
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleTheme}
              title={themeTooltip}
              aria-label={isDarkMode ? "Switch to light mode" : "Switch to dark mode"}
              aria-pressed={isDarkMode}
            >
              {isDarkMode ? <Moon className="h-5 w-5" /> : <SunMedium className="h-5 w-5" />}
            </Button>
          </div>
        </div>

        {/* Sticky totals with remaining budgets (PATCHED for "X over" in red) */}
        <div className="border-t border-slate-200 dark:border-slate-800">
          <div className="max-w-6xl mx-auto px-4 py-2 flex items-center justify-between gap-3">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-sm flex-1">
              {(() => {
                const rem = stickyGoals.kcal - stickyTotals.kcal;
                const over = rem < 0;
                const remaining = over ? `${Math.abs(rem).toFixed(0)} over` : `${rem.toFixed(0)} left`;
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
                const remaining = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
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
                const remaining = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
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
                const remaining = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
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
            <div className="hidden sm:flex items-center gap-2 text-xs">
              <span className="text-slate-500">Totals for</span>
              <Select value={stickyMode} onValueChange={(v)=>setStickyMode(v)}>
                <SelectTrigger className="h-7 w-28"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="today">Today</SelectItem>
                  <SelectItem value="selected">Selected day</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-6">
        <Tabs value={tab} onValueChange={setTab}>
          <TabsList className="grid w-full grid-cols-4 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/70 md:w-auto">
            <TabsTrigger value="dashboard" className="gap-2 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><BarChart3 className="h-4 w-4"/>Dashboard</TabsTrigger>
            <TabsTrigger value="daily" className="gap-2 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><BookOpenText className="h-4 w-4"/>Daily Log</TabsTrigger>
            <TabsTrigger value="foods" className="gap-2 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><Database className="h-4 w-4"/>Food DB</TabsTrigger>
            <TabsTrigger value="settings" className="gap-2 rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900"><SettingsIcon className="h-4 w-4"/>Settings</TabsTrigger>
          </TabsList>

          {/* DASHBOARD */}
          <TabsContent value="dashboard" className="mt-6 space-y-6">
            <div className="grid lg:grid-cols-2 gap-4">
              <Card className="h-full min-h-[360px] flex flex-col">
                <CardHeader>
                  <div className="flex items-center justify-between gap-3">
                    <CardTitle>Goal vs Actual</CardTitle>
                    <div className="flex items-center gap-2">
                      <GoalModeBadge value={goalDateEntry} />
                      <DatePickerButton value={goalDate} onChange={(value)=>setGoalDate(value||todayISO())} className="w-44" />
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="flex-1">
                  <div className="flex h-full items-center justify-center">
                    <div className="grid h-full grid-cols-2 gap-4 content-center origin-center scale-90">
                      <GoalDonut label="Calories" theme={MACRO_THEME.kcal} actual={goalTotals.kcal} goal={goalTarget.kcal} unit="kcal" />
                      <GoalDonut label="Protein" theme={MACRO_THEME.protein} actual={goalTotals.protein} goal={goalTarget.protein} unit="g" />
                      <GoalDonut label="Carbs" theme={MACRO_THEME.carbs} actual={goalTotals.carbs} goal={goalTarget.carbs} unit="g" />
                      <GoalDonut label="Fat" theme={MACRO_THEME.fat} actual={goalTotals.fat} goal={goalTarget.fat} unit="g" />
                    </div>
                  </div>
                </CardContent>
              </Card>

              <WeeklyNutritionCard data={weeklyNutrition} />
            </div>

            {/* Macros Trend */}
            <Card>
              <CardHeader className="pb-0">
                <div className="flex items-center justify-between gap-3">
                  <CardTitle>Macros Trend</CardTitle>
                  <div className="flex items-center gap-2">
                    <Select value={trendRange} onValueChange={(v)=>setTrendRange(v)}>
                      <SelectTrigger className="h-8 w-36"><SelectValue placeholder="Range" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="7">Last 7 days</SelectItem>
                        <SelectItem value="14">Last 14 days</SelectItem>
                        <SelectItem value="30">Last 30 days</SelectItem>
                        <SelectItem value="90">Last 3 months</SelectItem>
                        <SelectItem value="365">Last 12 months</SelectItem>
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
                    <YAxis stroke="#94a3b8" tick={{ fill: '#64748b' }} axisLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} tickLine={{ stroke: '#cbd5f5', strokeOpacity: 0.4 }} />
                    <Legend iconType="circle" />
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
                              const macroLabel = item.name ?? MACRO_LABELS[key] ?? key;
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
                <div className="flex items-center justify-between gap-3">
                  <CardTitle className="flex items-center gap-2"><UtensilsCrossed className="h-5 w-5"/>Macro Split per Meal</CardTitle>
                  <div className="flex items-center gap-2">
                    <GoalModeBadge value={splitEntry} />
                    <DatePickerButton value={splitDate} onChange={(value)=>setSplitDate(value||todayISO())} className="w-44" />
                  </div>
                </div>
              </CardHeader>
              <div className="mt-4" />
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={mealSplit}
                    margin={{ left: 12, right: 12 }}
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
                    />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Top Foods by Macros (unchanged aside from existing top-5) */}
            <TopFoodsCard
              topFoods={topFoods}
              topMacroKey={topMacroKey}
              onMacroChange={setTopMacroKey}
              selectedDate={topFoodsDate}
              onDateChange={(value)=>setTopFoodsDate(value||todayISO())}
              goalMode={topFoodsEntry}
            />

            {/* Averages tiles (non-empty days only) */}
            <div className="grid md:grid-cols-4 gap-4">
              {averageSummaries.map((summary) => (
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
                data={weightTrendSummary.data}
                latestWeight={weightTrendSummary.latestWeight}
                latestDate={weightTrendSummary.latestDate}
              />
              <FoodLoggingCard summary={loggingSummary} />
            </div>
          </TabsContent>

          {/* DAILY LOG */}
          <TabsContent value="daily" className="mt-6 space-y-6">
            <Card>
              <CardHeader>
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <CardTitle className="flex items-center gap-2"><History className="h-5 w-5"/>Log your intake</CardTitle>
                  <GoalModeSelect value={logDateEntry} onChange={(entry)=>setModeEntryForDate(logDate || todayISO(), entry)} />
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid md:grid-cols-6 gap-3 items-end">
                  <div className="md:col-span-2">
                    <Label className="text-sm">Date</Label>
                    <div className="flex items-center gap-2">
                      <Input type="date" value={logDate} onChange={(e)=>setLogDate(e.target.value)} />
                      <Button variant="outline" onClick={()=>setLogDate(todayISO())}><CalendarIcon className="h-4 w-4"/></Button>
                    </div>
                  </div>
                  <div className="md:col-span-2">
                    <Label className="text-sm">Food</Label>
                    <FoodInput foods={foods} selectedFoodId={selectedFoodId} onSelect={(id)=>{ setSelectedFoodId(id); }} />
                  </div>
                  <div>
                    <Label className="text-sm">Meal</Label>
                    <Select value={meal} onValueChange={(v)=>setMeal(/** @type {MealKey} */(v))}>
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="breakfast">Breakfast</SelectItem>
                        <SelectItem value="lunch">Lunch</SelectItem>
                        <SelectItem value="dinner">Dinner</SelectItem>
                        <SelectItem value="snack">Snack</SelectItem>
                        <SelectItem value="other">Other</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <Label className="text-sm">Quantity {quantityLabelSuffix}</Label>
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
                    <Button className="w-full" onClick={addEntry} disabled={!selectedFood || !qty || qty <= 0}><Plus className="h-4 w-4"/> Add</Button>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader><CardTitle>Entries — {format(new Date(logDate), "PPPP")}</CardTitle></CardHeader>
              <CardContent>
                {MEAL_ORDER.map(mk=>{
                  const group = rowsForDay.filter(r=> (r.meal||'other')===mk);
                  if(group.length===0) return null;
                  const totals = sumMacros(group);
                  return (
                    <div key={mk} className="mb-6">
                      <div className="flex items-center gap-2 text-sm font-semibold mb-2"><UtensilsCrossed className="h-4 w-4"/>{MEAL_LABELS[mk]}</div>
                      <Table>
                        <TableHeader>
                          <TableRow>
                            <TableHead>Food</TableHead>
                            <TableHead className="text-right">Qty</TableHead>
                            <TableHead className="text-right">kcal</TableHead>
                            <TableHead className="text-right">Protein (g)</TableHead>
                            <TableHead className="text-right">Carbs (g)</TableHead>
                            <TableHead className="text-right">Fat (g)</TableHead>
                            <TableHead>Meal</TableHead>
                            <TableHead></TableHead>
                          </TableRow>
                        </TableHeader>
                        <TableBody>
                          {group.map((r)=> (
                            <TableRow key={r.id}>
                              <TableCell>
                                <EditableFoodCell entryId={r.id} currentFoodId={r.foodId||null} fallbackLabel={r.label} foods={foods} onSelect={(foodId)=>updateEntryFood(r.id, foodId)} />
                              </TableCell>
                              <TableCell className="text-right">
                                <input className="w-20 text-right bg-transparent border rounded px-2 py-1 border-slate-200 dark:border-slate-700" type="number" step="0.1" defaultValue={r.qty} onBlur={(e)=>updateEntryQuantity(r.id, parseFloat(e.target.value))} onKeyDown={(e)=>{ if(e.key==='Enter'){ e.target.blur(); } }} />
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
                          <TableRow>
                            <TableCell className="font-medium">Subtotal</TableCell>
                            <TableCell></TableCell>
                            <TableCell className="text-right font-medium">{totals.kcal.toFixed(0)}</TableCell>
                            <TableCell className="text-right font-medium">{totals.protein.toFixed(1)}</TableCell>
                            <TableCell className="text-right font-medium">{totals.carbs.toFixed(1)}</TableCell>
                            <TableCell className="text-right font-medium">{totals.fat.toFixed(1)}</TableCell>
                            <TableCell colSpan={2}></TableCell>
                          </TableRow>
                        </TableBody>
                      </Table>
                    </div>
                  );
                })}

                {rowsForDay.length===0 && (
                  <div className="text-center text-slate-500">No entries yet for this day.</div>
                )}

                <div className="grid md:grid-cols-4 gap-3 mt-4">
                  <Card className="bg-slate-50 dark:bg-slate-900/40"><CardHeader className="py-3"><CardTitle className="text-sm">Total kcal</CardTitle></CardHeader><CardContent className="pt-0 text-2xl font-semibold">{totalsForCard.kcal.toFixed(0)}</CardContent></Card>
                  <Card className="bg-slate-50 dark:bg-slate-900/40"><CardHeader className="py-3"><CardTitle className="text-sm">Protein (g)</CardTitle></CardHeader><CardContent className="pt-0 text-2xl font-semibold">{totalsForCard.protein.toFixed(1)}</CardContent></Card>
                  <Card className="bg-slate-50 dark:bg-slate-900/40"><CardHeader className="py-3"><CardTitle className="text-sm">Carbs (g)</CardTitle></CardHeader><CardContent className="pt-0 text-2xl font-semibold">{totalsForCard.carbs.toFixed(1)}</CardContent></Card>
                  <Card className="bg-slate-50 dark:bg-slate-900/40"><CardHeader className="py-3"><CardTitle className="text-sm">Fat (g)</CardTitle></CardHeader><CardContent className="pt-0 text-2xl font-semibold">{totalsForCard.fat.toFixed(1)}</CardContent></Card>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* FOOD DB */}
          <TabsContent value="foods" className="mt-6 space-y-6">
            <AddFoodCard foods={foods} onAdd={addFood} />
            <Card>
              <CardHeader><CardTitle>Database — {foods.length} items</CardTitle></CardHeader>
              <CardContent className="overflow-x-auto">
                <Table className="w-full table-fixed">
                  <TableHeader>
                    <TableRow>
                      <TableHead className="w-[26%]">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("name")}
                          className="flex w-full items-center gap-1 text-left text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Name</span>
                          {renderSortIcon("name")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[18%]">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("category")}
                          className="flex w-full items-center gap-1 text-left text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Category</span>
                          {renderSortIcon("category")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[16%]">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("unit")}
                          className="flex w-full items-center gap-1 text-left text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Unit</span>
                          {renderSortIcon("unit")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[7%] text-right">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("kcal")}
                          className="ml-auto flex items-center gap-1 text-right text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>kcal</span>
                          {renderSortIcon("kcal")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[7%] text-right">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("protein")}
                          className="ml-auto flex items-center gap-1 text-right text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Protein (g)</span>
                          {renderSortIcon("protein")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[7%] text-right">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("carbs")}
                          className="ml-auto flex items-center gap-1 text-right text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Carbs (g)</span>
                          {renderSortIcon("carbs")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[7%] text-right">
                        <button
                          type="button"
                          onClick={()=>toggleFoodSort("fat")}
                          className="ml-auto flex items-center gap-1 text-right text-sm font-medium text-slate-600 transition hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-50"
                        >
                          <span>Fat (g)</span>
                          {renderSortIcon("fat")}
                        </button>
                      </TableHead>
                      <TableHead className="w-[12%] text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {sortedFoods.map((f)=> (
                      <EditableFoodRow key={f.id} food={f} foods={foods} onUpdate={updateFood} onDelete={deleteFood} />
                    ))}
                    {sortedFoods.length===0 && (
                      <TableRow><TableCell colSpan={8} className="text-center text-slate-500">Your database is empty. Add foods above or import a backup.</TableCell></TableRow>
                    )}
                  </TableBody>
                </Table>
              </CardContent>
            </Card>
          </TabsContent>

          {/* SETTINGS */}
          <TabsContent value="settings" className="mt-6">
            <Card>
              <CardHeader><CardTitle>Preferences</CardTitle></CardHeader>
              <CardContent className="space-y-6">
                <div className="grid md:grid-cols-2 gap-6">
                  <div>
                    <h3 className="font-medium mb-2">Daily macro goals</h3>
                    <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
                      <p className="text-xs text-slate-500 max-w-xs sm:max-w-md">
                        Choose your approach and tune the macros for each profile. Days remember their assigned setup so history stays intact.
                      </p>
                      <div className="flex items-center gap-2">
                        <Label className="text-xs font-semibold uppercase tracking-wide text-slate-500">Setup</Label>
                        <Select value={activeSetup} onValueChange={handleSetupChange}>
                          <SelectTrigger className="h-8 w-44"><SelectValue placeholder="Setup" /></SelectTrigger>
                          <SelectContent>
                            {SETUP_MODES.map((mode) => (
                              <SelectItem key={mode} value={mode}>
                                {SETUP_LABELS[mode]}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                    </div>
                    {activeSetup === "dual" ? (
                      <>
                        <Tabs value={activeDualProfile} onValueChange={handleDualProfileChange}>
                          <TabsList className="mb-3 grid w-full max-w-xs grid-cols-2 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/60">
                            <TabsTrigger value="train" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">Train Day</TabsTrigger>
                            <TabsTrigger value="rest" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">Rest Day</TabsTrigger>
                          </TabsList>
                          <TabsContent value="train" className="mt-0">
                            <div className="grid grid-cols-2 gap-3">
                              <div className="col-span-2">
                                <LabeledNumber label="Calories (kcal)" value={dailyGoals.dual.train.kcal} onChange={updateMacroGoal('dual.train','kcal')} />
                              </div>
                              <LabeledNumber label="Protein (g)" value={dailyGoals.dual.train.protein} onChange={updateMacroGoal('dual.train','protein')} />
                              <LabeledNumber label="Carbs (g)" value={dailyGoals.dual.train.carbs} onChange={updateMacroGoal('dual.train','carbs')} />
                              <LabeledNumber label="Fat (g)" value={dailyGoals.dual.train.fat} onChange={updateMacroGoal('dual.train','fat')} />
                            </div>
                          </TabsContent>
                          <TabsContent value="rest" className="mt-0">
                            <div className="grid grid-cols-2 gap-3">
                              <div className="col-span-2">
                                <LabeledNumber label="Calories (kcal)" value={dailyGoals.dual.rest.kcal} onChange={updateMacroGoal('dual.rest','kcal')} />
                              </div>
                              <LabeledNumber label="Protein (g)" value={dailyGoals.dual.rest.protein} onChange={updateMacroGoal('dual.rest','protein')} />
                              <LabeledNumber label="Carbs (g)" value={dailyGoals.dual.rest.carbs} onChange={updateMacroGoal('dual.rest','carbs')} />
                              <LabeledNumber label="Fat (g)" value={dailyGoals.dual.rest.fat} onChange={updateMacroGoal('dual.rest','fat')} />
                            </div>
                          </TabsContent>
                        </Tabs>
                        <p className="text-xs text-slate-500 mt-3">The highlighted profile powers the sticky macros, dashboard KPIs, and Goal vs Actual chart.</p>
                      </>
                    ) : (
                      <div className="space-y-3">
                        <div className="grid grid-cols-2 gap-3">
                          <div className="col-span-2">
                            <LabeledNumber label="Calories (kcal)" value={dailyGoals[activeSetup]?.kcal ?? 0} onChange={updateMacroGoal(activeSetup,'kcal')} />
                          </div>
                          <LabeledNumber label="Protein (g)" value={dailyGoals[activeSetup]?.protein ?? 0} onChange={updateMacroGoal(activeSetup,'protein')} />
                          <LabeledNumber label="Carbs (g)" value={dailyGoals[activeSetup]?.carbs ?? 0} onChange={updateMacroGoal(activeSetup,'carbs')} />
                          <LabeledNumber label="Fat (g)" value={dailyGoals[activeSetup]?.fat ?? 0} onChange={updateMacroGoal(activeSetup,'fat')} />
                        </div>
                        <p className="text-xs text-slate-500">
                          {SETUP_LABELS[activeSetup]} powers the dashboard whenever this setup is active.
                        </p>
                      </div>
                    )}
                  </div>
                  <div>
                    <h3 className="font-medium mb-2">Appearance</h3>
                    <div className="flex items-center justify-between rounded-xl border p-4 border-slate-200 dark:border-slate-700">
                      <div>
                        <div className="font-medium">Dark mode</div>
                        <div className="text-sm text-slate-500 dark:text-slate-400">
                          {isFollowingSystem
                            ? `Following system preference (${isDarkMode ? 'Dark' : 'Light'})`
                            : `Manual ${isDarkMode ? 'Dark' : 'Light'} theme`}
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        <Switch
                          checked={isDarkMode}
                          onCheckedChange={(checked) => setTheme(checked ? 'dark' : 'light')}
                          aria-label="Toggle dark mode"
                        />
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={followSystemTheme}
                          disabled={isFollowingSystem}
                        >
                          Use system
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Profile */}
                <div className="grid md:grid-cols-2 gap-6">
                  <div>
                    <h3 className="font-medium mb-2">Profile</h3>
                    <div className="grid grid-cols-2 gap-3">
                      <LabeledNumber label="Age (years)" value={settings.profile?.age ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, age:v}})} />
                      <div>
                        <Label className="text-sm">Sex</Label>
                        <Select value={settings.profile?.sex ?? 'other'} onValueChange={(v)=>setSettings({...settings, profile:{...settings.profile, sex:v}})}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="male">Male</SelectItem>
                            <SelectItem value="female">Female</SelectItem>
                            <SelectItem value="other">Other</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <LabeledNumber label="Height (cm)" value={settings.profile?.heightCm ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, heightCm:v}})} />
                      <LabeledNumber label="Weight (kg)" value={settings.profile?.weightKg ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, weightKg:v}})} />
                      <LabeledNumber label="Body fat (%)" value={settings.profile?.bodyFatPct ?? 0} onChange={(v)=>setSettings({...settings, profile:{...settings.profile, bodyFatPct:v}})} />
                      <div>
                        <Label className="text-sm">Activity</Label>
                        <Select value={settings.profile?.activity ?? 'moderate'} onValueChange={(v)=>setSettings({...settings, profile:{...settings.profile, activity:v}})}>
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="sedentary">Sedentary</SelectItem>
                            <SelectItem value="light">Light</SelectItem>
                            <SelectItem value="moderate">Moderate</SelectItem>
                            <SelectItem value="active">Active</SelectItem>
                            <SelectItem value="athlete">Athlete</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="col-span-2 flex flex-col items-end gap-2 pt-1">
                        <Button onClick={handleSaveBodyProfile} className="self-end">Save</Button>
                        <span className="text-xs text-slate-500 dark:text-slate-400">
                          {weightTrendSummary.latestDate ? `Last saved ${weightTrendSummary.latestDate}` : 'No history recorded yet.'}
                        </span>
                      </div>
                    </div>
                  </div>
                  <div className="rounded-xl border p-4 border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/40">
                    <div className="font-medium mb-1">Notes</div>
                    <div className="text-sm text-slate-500">Profile is optional and local-only. Future: BMR/TDEE suggestions.</div>
                  </div>
                </div>

                <div className="flex flex-wrap gap-3">
                  <Button variant="destructive" onClick={()=>{ if(confirm('Reset all data?')){ setFoods(DEFAULT_FOODS); setEntries([]); } }}>Reset data</Button>
                  <Button variant="outline" onClick={()=>setTab('dashboard')}>Back to Dashboard</Button>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>

      <footer className="py-8 text-center text-xs text-slate-500">Built with ❤️ — Local-first, your data stays in your browser.</footer>
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

function GoalModeToggle({ active, onChange }){
  return (
    <div
      className="flex h-9 flex-shrink-0 items-center gap-1 rounded-full border border-slate-200 dark:border-slate-700 bg-white/70 dark:bg-slate-900/60 px-1 shadow-sm"
      role="group"
      aria-label="Select active goal profile"
    >
      {DUAL_PROFILE_OPTIONS.map(({ value, label, Icon, accent })=>{
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
            <span>{label}</span>
            <span className="ml-1 inline-flex h-1.5 w-1.5 rounded-full" style={{ backgroundColor: accent }} aria-hidden="true" />
          </button>
        );
      })}
    </div>
  );
}

function GoalModeSelect({ value, onChange, className }) {
  const entry = coerceModeEntry(value);
  const optionKey = entry.setup === "dual" ? (entry.profile === "rest" ? "rest" : "train") : entry.setup;
  const activeOption = PROFILE_MODE_OPTIONS.find((option) => option.value === optionKey) || PROFILE_MODE_OPTIONS[0];
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
        aria-label={`Goal profile: ${activeOption.label}`}
      >
        <span className="sr-only">{activeOption.label}</span>
        <div className="flex w-full items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <activeOption.Icon className="h-3.5 w-3.5" aria-hidden="true" />
            <span>{activeOption.label}</span>
          </div>
          <span className="inline-flex h-1.5 w-1.5 rounded-full" style={{ backgroundColor: activeOption.accent }} aria-hidden="true" />
        </div>
      </SelectTrigger>
      <SelectContent align="end">
        {PROFILE_MODE_OPTIONS.map(({ value: option, label, Icon: OptionIcon, accent: optionAccent }) => (
          <SelectItem key={option} value={option}>
            <div className="flex items-center gap-2">
              <OptionIcon className="h-4 w-4" />
              <span>{label}</span>
              <span className="ml-auto inline-flex h-2 w-2 rounded-full" style={{ backgroundColor: optionAccent }} aria-hidden="true" />
            </div>
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}

function GoalModeBadge({ value, className }) {
  const entry = coerceModeEntry(value);
  const optionKey = entry.setup === "dual" ? (entry.profile === "rest" ? "rest" : "train") : entry.setup;
  const activeOption = PROFILE_MODE_OPTIONS.find((option) => option.value === optionKey) || PROFILE_MODE_OPTIONS[0];
  return (
    <div
      className={cn(
        "flex h-8 items-center justify-center gap-2 rounded-full border border-slate-300 bg-white/80 px-3 text-xs text-slate-600 dark:border-slate-700 dark:bg-slate-900/60 dark:text-slate-300 whitespace-nowrap",
        "pointer-events-none select-none",
        className,
      )}
      title={activeOption.label}
    >
      <span className="sr-only">{activeOption.label}</span>
      <activeOption.Icon className="h-3.5 w-3.5" aria-hidden="true" />
      <span className="font-medium">{activeOption.label}</span>
      <span
        className="inline-flex h-1.5 w-1.5 rounded-full"
        style={{ backgroundColor: activeOption.accent }}
        aria-hidden="true"
      />
    </div>
  );
}
// PATCH: accept optional subColor for "X over" red
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

function WeeklyNutritionCard({ data }) {
  const days = data?.days ?? [];
  const rows = data?.rows ?? [];
  const hasData = days.length > 0 && rows.length > 0;

  return (
    <Card className="h-full min-h-[360px] flex flex-col">
      <CardHeader>
        <div className="flex items-center justify-between gap-3">
          <CardTitle>Weekly Nutrition</CardTitle>
          {data?.weekLabel && <span className="text-xs text-slate-500">{data.weekLabel}</span>}
        </div>
      </CardHeader>
      <CardContent className="flex-1 pt-3 pb-4">
        {!hasData ? (
          <p className="text-sm text-slate-500">Log entries to see your weekly breakdown.</p>
        ) : (
          <div className="overflow-x-auto">
            <div className="min-w-max">
              <div className="grid grid-cols-[auto_repeat(7,minmax(0,1fr))_auto] items-end gap-x-3 gap-y-3 text-[13px] origin-top-left scale-90 mt-3">
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
                <div className="pr-1 text-right text-[11px] font-medium uppercase tracking-wide text-slate-500">Selected day</div>
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
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function WeeklyNutritionCell({ theme, unit, actual, goal, isToday, isSelected }) {
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
        title={tooltip}
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
  const data = [
    {
      key: "kcal",
      label: "Calories",
      unit: "kcal",
      value: averages?.kcal ?? 0,
      gradientFrom: MACRO_THEME.kcal.gradientFrom,
      gradientTo: MACRO_THEME.kcal.gradientTo,
    },
    {
      key: "protein",
      label: "Protein",
      unit: "g",
      value: averages?.protein ?? 0,
      gradientFrom: MACRO_THEME.protein.gradientFrom,
      gradientTo: MACRO_THEME.protein.gradientTo,
    },
    {
      key: "carbs",
      label: "Carbs",
      unit: "g",
      value: averages?.carbs ?? 0,
      gradientFrom: MACRO_THEME.carbs.gradientFrom,
      gradientTo: MACRO_THEME.carbs.gradientTo,
    },
    {
      key: "fat",
      label: "Fat",
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

function WeightTrendCard({ data, latestWeight, latestDate }) {
  const gradientId = useId();
  const hasData = Array.isArray(data) && data.some((point) => point.weight != null || point.bodyFat != null);

  return (
    <Card>
      <CardHeader className="pb-1.5">
        <CardTitle>Weight Trend</CardTitle>
        <p className="text-sm text-slate-500 dark:text-slate-400">Last Month</p>
      </CardHeader>
      <CardContent className="space-y-3 pt-0">
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
                />
                <YAxis
                  yAxisId="bodyFat"
                  orientation="right"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fill: "currentColor", fontSize: 12 }}
                  tickFormatter={(value) => `${formatNumber(value)}%`}
                  width={56}
                  hide={!data.some((point) => point.bodyFat != null)}
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
                            <span className="text-slate-200">Weight</span>
                            <span className="font-semibold text-slate-100">{`${formatNumber(point.weight ?? weightEntry?.value ?? 0)} kg`}</span>
                          </div>
                        )}
                        {hasBodyFat && (
                          <div className="flex items-center justify-between gap-6">
                            <span className="text-slate-200">Body Fat</span>
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
              Log a weight to see trends.
            </div>
          )}
        </div>
        <div className="flex items-baseline gap-2 text-2xl font-semibold text-slate-900 dark:text-slate-100">
          <span>{latestWeight != null ? formatNumber(latestWeight) : "—"}</span>
          <span className="text-sm font-medium text-slate-500 dark:text-slate-400">kg</span>
        </div>
        <div className="text-xs text-slate-500 dark:text-slate-400">
          {latestDate ? `Latest entry on ${latestDate}` : "No entries recorded yet."}
        </div>
      </CardContent>
    </Card>
  );
}

function FoodLoggingCard({ summary }) {
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

  return (
    <Card>
      <CardHeader className="pb-1.5">
        <CardTitle>Food Logging</CardTitle>
        <p className="text-sm text-slate-500 dark:text-slate-400">Last 30 Days</p>
      </CardHeader>
      <CardContent className="space-y-3 pt-0 pb-3">
        <div ref={containerRef} className="relative" onMouseLeave={clearHover}>
          <div className="grid grid-cols-6 gap-2 py-1">
            {grid.map((day) => {
              const isoDate = `${day.iso}T00:00:00`;
              const fullLabel = format(new Date(isoDate), "PP");
              const statusLabel = day.logged ? "Logged" : "No log";
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
                  <div className="font-semibold text-slate-100">{hoveredDay.day.logged ? "Logged" : "No log"}</div>
                </ChartTooltipContainer>
              </div>
            </div>
          ) : null}
        </div>
        <div className="flex items-baseline justify-between text-sm">
          <span className="font-semibold text-slate-900 dark:text-slate-100">
            {totalLogged}/{totalDays} days
          </span>
          <span className="text-xs text-slate-500 dark:text-slate-400">{thisWeekLogged}/7 this week</span>
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
      <div className="relative h-32 w-32">
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
function TopFoodsCard({ topFoods, topMacroKey, onMacroChange, selectedDate, onDateChange, goalMode }) {
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

  const macroLabel = MACRO_LABELS[topMacroKey] ?? "Macro";
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
        <div className="flex items-center justify-between gap-3">
          <CardTitle>Top Foods by Macros — {dayLabel}</CardTitle>
          <div className="flex items-center gap-2">
            <GoalModeBadge value={goalMode} />
            <DatePickerButton value={selectedDate} onChange={onDateChange} className="w-44" />
            <Select value={topMacroKey} onValueChange={onMacroChange}>
              <SelectTrigger className="h-8 w-40">
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
      <CardContent className="h-80">
        <div className="grid h-full w-full grid-cols-[1fr_auto_1fr] grid-rows-[1fr_auto] items-center gap-6">
          <div className="flex w-full flex-col items-stretch justify-center gap-3">
            {leftItems.map((item, index) => renderLegendItem(item, index, `left-${index}`))}
          </div>
          <div className="relative row-span-2 flex h-full w-[260px] min-w-[220px] items-center justify-center">
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
          <div className="flex w-full flex-col items-stretch justify-center gap-3">
            {rightItems.map((item, index) => renderLegendItem(item, index + leftItems.length, `right-${index}`))}
          </div>
          <div className="col-span-3 flex flex-wrap items-center justify-center gap-3">
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
  return (
    <div className="relative">
      <CalendarIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
      <Input
        type="date"
        value={value ?? ''}
        onChange={(event)=>onChange(event.target.value)}
        max={todayISO()}
        className={cn("h-8 rounded-full border-slate-300 pl-9 pr-3 text-xs", className)}
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
function EditableFoodRow({ food, foods, onUpdate, onDelete }){
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState(()=>({
    name: food.name,
    category: food.category ?? DEFAULT_CATEGORY,
    unit: food.unit,
    servingSize: food.servingSize ? String(food.servingSize) : "",
    kcal: String(food.kcal ?? 0),
    protein: String(food.protein ?? 0),
    carbs: String(food.carbs ?? 0),
    fat: String(food.fat ?? 0),
    components: (food.components ?? []).map((component) => ({
      id: crypto.randomUUID(),
      foodId: component.foodId,
      quantity: String(component.quantity ?? 0),
    })),
  }));

  useEffect(()=>{
    setForm({
      name: food.name,
      category: food.category ?? DEFAULT_CATEGORY,
      unit: food.unit,
      servingSize: food.servingSize ? String(food.servingSize) : "",
      kcal: String(food.kcal ?? 0),
      protein: String(food.protein ?? 0),
      carbs: String(food.carbs ?? 0),
      fat: String(food.fat ?? 0),
      components: (food.components ?? []).map((component) => ({
        id: crypto.randomUUID(),
        foodId: component.foodId,
        quantity: String(component.quantity ?? 0),
      })),
    });
  }, [food, editing]);

  const isPerServing = form.unit === "perServing";

  const derived = useMemo(() => computeRecipeTotals(form.components ?? [], foods), [form.components, foods]);
  const { kcal: derivedKcal, protein: derivedProtein, carbs: derivedCarbs, fat: derivedFat } = derived;

  useEffect(() => {
    if (!editing || form.category !== "homeRecipe") return;
    setForm((prev) => {
      if (prev.category !== "homeRecipe") {
        return prev;
      }
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
  }, [editing, form.category, derivedKcal, derivedProtein, derivedCarbs, derivedFat]);

  function handleSave(){
    if(!form.name.trim()){
      alert("Enter a food name");
      return;
    }
    const components = (form.components ?? [])
      .map((component) => ({ foodId: component.foodId, quantity: toNumber(component.quantity, 0) }))
      .filter((component) => component.foodId && component.quantity > 0);
    const payload = {
      name: form.name.trim(),
      category: form.category,
      unit: form.unit,
      servingSize: isPerServing ? toNumber(form.servingSize, 1) : undefined,
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
    setEditing(false);
  }

  function handleCancel(){
    setForm({
      name: food.name,
      category: food.category ?? DEFAULT_CATEGORY,
      unit: food.unit,
      servingSize: food.servingSize ? String(food.servingSize) : "",
      kcal: String(food.kcal ?? 0),
      protein: String(food.protein ?? 0),
      carbs: String(food.carbs ?? 0),
      fat: String(food.fat ?? 0),
      components: (food.components ?? []).map((component) => ({
        id: crypto.randomUUID(),
        foodId: component.foodId,
        quantity: String(component.quantity ?? 0),
      })),
    });
    setEditing(false);
  }

  return (
    <>
      <TableRow>
        <TableCell className="align-middle">
          {editing ? (
            <div className="flex items-center gap-2 min-w-0">
              <span>{getCategoryEmoji(form.category)}</span>
              <Input className="h-8 w-full" value={form.name} onChange={(e)=>setForm(prev=>({...prev, name:e.target.value }))} />
            </div>
          ) : (
            <div className="flex items-center gap-2 min-w-0">
              <span>{getCategoryEmoji(food.category)}</span>
              <span className="truncate" title={food.name}>{food.name}</span>
            </div>
          )}
        </TableCell>
        <TableCell className="align-middle">
          {editing ? (
            <Select value={form.category} onValueChange={(value)=>setForm(prev=>({...prev, category:value }))}>
              <SelectTrigger className="h-8 w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {FOOD_CATEGORIES.map(cat=>(
                  <SelectItem key={cat.value} value={cat.value}>{cat.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : (
            <span className="whitespace-nowrap text-sm">{getCategoryLabel(food.category)}</span>
          )}
        </TableCell>
        <TableCell className="align-middle">
          {editing ? (
            <div className="flex items-center gap-2">
              <Select value={form.unit} onValueChange={(value)=>setForm(prev=>({ ...prev, unit:value, servingSize: value==='perServing' ? (prev.servingSize || '1') : '' }))}>
                <SelectTrigger className="h-8 w-[120px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="per100g">per 100g</SelectItem>
                  <SelectItem value="perServing">per serving</SelectItem>
                </SelectContent>
              </Select>
              {isPerServing && (
                <Input className="h-8 w-[90px]" type="number" step="0.1" value={form.servingSize} onChange={(e)=>setForm(prev=>({...prev, servingSize:e.target.value }))} placeholder="g" />
              )}
            </div>
          ) : (
            <span className="whitespace-nowrap text-sm">
              {food.unit==='per100g'? 'per 100 g' : `per ${formatNumber(food.servingSize??1)} g serving`}
            </span>
          )}
        </TableCell>
        <TableCell className="text-right tabular-nums align-middle">
          {editing ? (
            <Input className="h-8 w-full text-right" type="number" step="0.01" value={form.kcal} onChange={(e)=>setForm(prev=>({...prev, kcal:e.target.value }))} />
          ) : (
            formatNumber(food.kcal)
          )}
        </TableCell>
        <TableCell className="text-right tabular-nums align-middle">
          {editing ? (
            <Input className="h-8 w-full text-right" type="number" step="0.01" value={form.protein} onChange={(e)=>setForm(prev=>({...prev, protein:e.target.value }))} />
          ) : (
            formatNumber(food.protein)
          )}
        </TableCell>
        <TableCell className="text-right tabular-nums align-middle">
          {editing ? (
            <Input className="h-8 w-full text-right" type="number" step="0.01" value={form.carbs} onChange={(e)=>setForm(prev=>({...prev, carbs:e.target.value }))} />
          ) : (
            formatNumber(food.carbs)
          )}
        </TableCell>
        <TableCell className="text-right tabular-nums align-middle">
          {editing ? (
            <Input className="h-8 w-full text-right" type="number" step="0.01" value={form.fat} onChange={(e)=>setForm(prev=>({...prev, fat:e.target.value }))} />
          ) : (
            formatNumber(food.fat)
          )}
        </TableCell>
        <TableCell className="text-right align-middle">
          {editing ? (
            <div className="flex justify-end gap-2">
              <Button size="sm" onClick={handleSave}>Save</Button>
              <Button variant="ghost" size="sm" onClick={handleCancel}>Cancel</Button>
              <Button variant="ghost" size="icon" onClick={()=>onDelete(food.id)}><Trash2 className="h-4 w-4" /></Button>
            </div>
          ) : (
            <div className="flex justify-end gap-1">
              <Button variant="ghost" size="icon" onClick={()=>setEditing(true)}><Pencil className="h-4 w-4" /></Button>
              <Button variant="ghost" size="icon" onClick={()=>onDelete(food.id)}><Trash2 className="h-4 w-4" /></Button>
            </div>
          )}
        </TableCell>
      </TableRow>
      {editing && form.category === "homeRecipe" && (
        <TableRow className="bg-slate-50/60 dark:bg-slate-900/40">
          <TableCell colSpan={8} className="p-4">
            <div className="space-y-3">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-sm font-medium">Home recipe ingredients</span>
                <span className="text-xs text-slate-500">Totals sync with the macro fields above.</span>
              </div>
              <RecipeIngredientsEditor
                ingredients={form.components}
                onChange={(next)=>setForm((prev)=>({...prev, components: next }))}
                foods={foods}
                ownerId={food.id}
              />
            </div>
          </TableCell>
        </TableRow>
      )}
    </>
  );
}
function AddFoodCard({ foods, onAdd }){
  const [activeTab, setActiveTab] = useState("single");
  const [basicForm, setBasicForm] = useState(()=>createBasicFoodForm());
  const [recipeForm, setRecipeForm] = useState(()=>createRecipeForm());
  const [recipeIngredients, setRecipeIngredients] = useState([]);

  const derivedTotals = useMemo(() => computeRecipeTotals(recipeIngredients, foods), [recipeIngredients, foods]);
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
  }

  function handleAddRecipe(){
    const trimmed = recipeForm.name.trim();
    if(!trimmed){ alert('Enter a recipe name'); return; }
    const components = recipeIngredients
      .map((item) => ({ foodId: item.foodId, quantity: item.quantity }))
      .filter((item) => item.foodId && toNumber(item.quantity, 0) > 0);
    if(components.length===0){ alert('Add at least one ingredient'); return; }
    const unit = recipeForm.unit === 'perServing' ? 'perServing' : 'per100g';
    const payload = {
      id: crypto.randomUUID(),
      name: trimmed,
      unit,
      category: 'homeRecipe',
      servingSize: unit === 'perServing' ? Math.max(1, toNumber(recipeForm.servingSize, 1)) : undefined,
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
  }

  return (
    <Card>
      <CardHeader><CardTitle>Add Food to Database</CardTitle></CardHeader>
      <CardContent className="space-y-4">
        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="grid w-full max-w-xs grid-cols-2 rounded-full border border-slate-200 bg-white/80 p-1 shadow-sm dark:border-slate-700 dark:bg-slate-900/60">
            <TabsTrigger value="single" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">Add Food</TabsTrigger>
            <TabsTrigger value="recipe" className="rounded-full data-[state=active]:bg-slate-900 data-[state=active]:text-white dark:data-[state=active]:bg-slate-100 dark:data-[state=active]:text-slate-900">Add Home Recipe</TabsTrigger>
          </TabsList>

          <TabsContent value="single" className="mt-4">
            <div className="grid gap-3 md:grid-cols-6">
              <div className="md:col-span-2">
                <Label>Name</Label>
                <Input value={basicForm.name} onChange={(e)=>setBasicForm((prev)=>({...prev, name:e.target.value }))} placeholder="e.g. Banana" />
              </div>
              <div>
                <Label>Category</Label>
                <Select value={basicForm.category} onValueChange={(v)=>setBasicForm((prev)=>({...prev, category:v }))}>
                  <SelectTrigger><SelectValue placeholder="Select category" /></SelectTrigger>
                  <SelectContent>
                    {FOOD_CATEGORIES.map(cat=>(
                      <SelectItem key={cat.value} value={cat.value}>{cat.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Unit</Label>
                <Select value={basicForm.unit} onValueChange={(v)=>setBasicForm((prev)=>({...prev, unit:v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="per100g">per 100g</SelectItem>
                    <SelectItem value="perServing">per serving</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {basicForm.unit==='perServing' && (
                <div>
                  <Label>Serving size (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.servingSize} onChange={(e)=>setBasicForm((prev)=>({...prev, servingSize:e.target.value }))} />
                </div>
              )}
              <div className="md:col-span-6 grid grid-cols-4 gap-3">
                <div>
                  <Label>kcal</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.kcal} onChange={(e)=>setBasicForm((prev)=>({...prev, kcal:e.target.value }))} />
                </div>
                <div>
                  <Label>Fat (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.fat} onChange={(e)=>setBasicForm((prev)=>({...prev, fat:e.target.value }))} />
                </div>
                <div>
                  <Label>Carbs (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.carbs} onChange={(e)=>setBasicForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>Protein (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.protein} onChange={(e)=>setBasicForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
              </div>
              <div className="md:col-span-6 text-right">
                <Button onClick={handleAddBasic}>Add Food</Button>
              </div>
            </div>
          </TabsContent>

          <TabsContent value="recipe" className="mt-4">
            <div className="grid gap-3 md:grid-cols-6">
              <div className="md:col-span-3">
                <Label>Recipe name</Label>
                <Input value={recipeForm.name} onChange={(e)=>setRecipeForm((prev)=>({...prev, name:e.target.value }))} placeholder="e.g. Vanilla Pancake" />
              </div>
              <div>
                <Label>Unit</Label>
                <Select value={recipeForm.unit} onValueChange={(v)=>setRecipeForm((prev)=>({...prev, unit:v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="per100g">per 100g</SelectItem>
                    <SelectItem value="perServing">per serving</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              {recipeForm.unit==='perServing' && (
                <div>
                  <Label>Serving size (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.servingSize} onChange={(e)=>setRecipeForm((prev)=>({...prev, servingSize:e.target.value }))} />
                </div>
              )}
              <div className="md:col-span-6">
                <Label>Ingredients</Label>
                <RecipeIngredientsEditor
                  ingredients={recipeIngredients}
                  onChange={setRecipeIngredients}
                  foods={foods}
                />
              </div>
              <div className="md:col-span-6 grid grid-cols-4 gap-3">
                <div>
                  <Label>kcal</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.kcal} onChange={(e)=>setRecipeForm((prev)=>({...prev, kcal:e.target.value }))} />
                </div>
                <div>
                  <Label>Fat (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.fat} onChange={(e)=>setRecipeForm((prev)=>({...prev, fat:e.target.value }))} />
                </div>
                <div>
                  <Label>Carbs (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.carbs} onChange={(e)=>setRecipeForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>Protein (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.protein} onChange={(e)=>setRecipeForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
              </div>
              <div className="md:col-span-6 text-sm text-slate-500">
                Totals above auto-fill from the ingredients. Adjust manually if you need to fine tune.
              </div>
              <div className="md:col-span-6 text-right">
                <Button onClick={handleAddRecipe}>Add Home Recipe</Button>
              </div>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
}

function RecipeIngredientsEditor({ ingredients, onChange, foods, ownerId }) {
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
          Add ingredients from your food database to build this recipe.
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
                <Label className="text-xs font-medium uppercase tracking-wide text-slate-500">Ingredient</Label>
                <IngredientFoodPicker
                  value={item.foodId}
                  foods={availableFoods}
                  allFoods={foods}
                  onSelect={(value)=>handleFoodChange(item.id, value)}
                />
              </div>
              <div>
                <Label className="text-xs font-medium uppercase tracking-wide text-slate-500">Quantity</Label>
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
                : "Pick a food and quantity to see the contribution."}
            </div>
          </div>
        );
      })}
      <div className="flex items-center justify-between">
        {!canAddIngredient && (
          <span className="text-xs text-slate-500">Add foods to your database to build recipes.</span>
        )}
        <Button type="button" variant="outline" size="sm" onClick={handleAdd} disabled={!canAddIngredient}>
          <Plus className="mr-2 h-4 w-4" /> Add ingredient
        </Button>
      </div>
    </div>
  );
}

function IngredientFoodPicker({ value, foods, allFoods, onSelect }) {
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
        placeholder="Search ingredient"
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
          No foods match that search.
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
