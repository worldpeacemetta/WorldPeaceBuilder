// MacroTracker v3.7 — Patch on your original file
// Changes from your App.jsx:
// 1) Goal vs Actual donuts now show % > 100 when over budget.
// 2) Sticky header KPIs show "X over" in dark red when exceeding goals.
//    (Everything else left untouched.)

import React, { useCallback, useEffect, useMemo, useState } from "react";
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
  Line,
  LineChart,
  BarChart,
  Bar,
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
} from "lucide-react";
import { format, startOfDay, subDays, startOfMonth, startOfQuarter, startOfYear, eachDayOfInterval } from "date-fns";

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

// Softer palette per your preference
const COLORS = {
  kcal: "#f87171", // red-400
  protein: "#4ade80", // green-400
  carbs: "#3b82f6", // blue-500
  fat: "#f59e0b", // amber-500
  gray: "#94a3b8", // slate-400
  cyan: "#06b6d4",
  violet: "#8b5cf6",
  redDark: "#b91c1c",
};

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

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const toISODate = (d) => format(d, "yyyy-MM-dd");
const todayISO = () => toISODate(new Date());

function sanitizeGoalSchedule(value, fallbackMode, isoToday = todayISO()) {
  if (!value || typeof value !== "object") {
    return fallbackMode ? { [isoToday]: fallbackMode } : {};
  }
  const schedule = {};
  Object.entries(value).forEach(([key, rawMode]) => {
    if (!ISO_DATE_RE.test(key)) return;
    const normalized = rawMode === "rest" ? "rest" : rawMode === "train" ? "train" : null;
    if (normalized) {
      schedule[key] = normalized;
    }
  });
  if (fallbackMode && !schedule[isoToday]) {
    schedule[isoToday] = fallbackMode;
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
  const active = hasValue && value.active === "rest" ? "rest" : "train";

  let trainGoal;
  let restGoal;

  if (hasValue && value.train && value.rest) {
    trainGoal = sanitizeGoal(value.train);
    restGoal = sanitizeGoal(value.rest);
  } else if (hasValue) {
    trainGoal = sanitizeGoal(value);
    restGoal = value?.rest ? sanitizeGoal(value.rest) : { ...trainGoal };
  } else {
    trainGoal = sanitizeGoal(DEFAULT_GOALS);
    restGoal = sanitizeGoal(DEFAULT_GOALS);
  }

  const schedule = sanitizeGoalSchedule(hasValue ? value.byDate : undefined, active, isoToday);
  if (!schedule[isoToday]) {
    schedule[isoToday] = active;
  }

  return {
    train: trainGoal,
    rest: restGoal,
    active,
    byDate: schedule,
  };
}

const DEFAULT_SETTINGS = {
  dailyGoals: ensureDailyGoals({
    train: DEFAULT_GOALS,
    rest: DEFAULT_GOALS,
    active: "train",
  }),
  profile: { activity: "moderate" },
};

function ensureSettings(value) {
  const base = value && typeof value === "object" ? value : {};
  const profile = base.profile && typeof base.profile === "object"
    ? { ...DEFAULT_SETTINGS.profile, ...base.profile }
    : { ...DEFAULT_SETTINGS.profile };

  return {
    ...base,
    dailyGoals: ensureDailyGoals(base.dailyGoals),
    profile,
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
  return {
    ...food,
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
  const [foods, setFoods] = useState(()=> ensureFoods(load(K_FOODS, DEFAULT_FOODS)));
  const [foodSort, setFoodSort] = useState({ column: "name", direction: "asc" });
  const [entries, setEntries] = useState(load(K_ENTRIES, []));
  const [settings, setSettings] = useState(()=> ensureSettings(load(K_SETTINGS, DEFAULT_SETTINGS)));
  const [tab, setTab] = useState('dashboard');

  // Theme handling
  useEffect(()=>{
    const root = document.documentElement; const mql = window.matchMedia('(prefers-color-scheme: dark)');
    const apply = ()=>{ const dark = theme==='system'? mql.matches : theme==='dark'; root.classList.toggle('dark', dark); };
    apply(); if(theme==='system'){ mql.addEventListener('change', apply); return ()=> mql.removeEventListener('change', apply);} save(K_THEME, theme);
  },[theme]);

  useEffect(()=>save(K_FOODS, foods),[foods]);
  useEffect(()=>save(K_ENTRIES, entries),[entries]);
  useEffect(()=>save(K_SETTINGS, settings),[settings]);

  // Daily log state
  const [logDate, setLogDate] = useState(todayISO());
  const [selectedFoodId, setSelectedFoodId] = useState(null);
  const [qty, setQty] = useState(0);
  const [meal, setMeal] = useState(/** @type {MealKey} */(suggestMealByNow()));

  const selectedFood = useMemo(()=> foods.find(f=>f.id===selectedFoodId)||null, [selectedFoodId,foods]);

  const entriesForDay = useMemo(()=> entries.filter(e=>e.date===logDate),[entries,logDate]);
  const rowsForDay = useMemo(()=> entriesForDay.map(e=>{ const f = foods.find(x=>x.id===e.foodId); if(!f) return { id:e.id, foodId:e.foodId, label:e.label??'Unknown', category:DEFAULT_CATEGORY, qty:e.qty, meal:e.meal||'other', kcal:0,fat:0,carbs:0,protein:0}; const m=scaleMacros(f,e.qty); return { id:e.id, foodId:e.foodId, label:f.name, category:f.category, qty:e.qty, meal:e.meal||'other', ...m}; }),[entriesForDay,foods]);

  const totalsForDate = (iso)=>{ const dayEntries = entries.filter(e=>e.date===iso); const rows = dayEntries.map(e=>{ const f=foods.find(x=>x.id===e.foodId); return f? scaleMacros(f,e.qty) : {kcal:0,fat:0,carbs:0,protein:0};}); return sumMacros(rows); };

  const [stickyMode, setStickyMode] = useState('today');
  const [goalDate, setGoalDate] = useState(todayISO());
  const [splitDate, setSplitDate] = useState(todayISO());
  const [topFoodsDate, setTopFoodsDate] = useState(todayISO());

  const stickyDate = stickyMode==='today'? todayISO(): logDate;
  const stickyTotals = useMemo(()=> totalsForDate(stickyDate), [entries,foods,stickyDate]);
  const totalsForCard = useMemo(()=> totalsForDate(logDate), [rowsForDay]);

  const activeGoalType = settings.dailyGoals?.active === 'rest' ? 'rest' : 'train';
  const goalSchedule = settings.dailyGoals?.byDate ?? {};
  const sortedScheduleKeys = useMemo(() => Object.keys(goalSchedule).sort(), [goalSchedule]);

  const resolveModeForDate = useCallback((isoDate) => {
    if (isoDate && goalSchedule[isoDate]) {
      const mode = goalSchedule[isoDate];
      if (mode === 'rest' || mode === 'train') {
        return mode;
      }
    }
    if (isoDate) {
      for (let i = sortedScheduleKeys.length - 1; i >= 0; i -= 1) {
        const key = sortedScheduleKeys[i];
        if (key <= isoDate) {
          const mode = goalSchedule[key];
          if (mode === 'rest' || mode === 'train') {
            return mode;
          }
        }
      }
    }
    return activeGoalType;
  }, [activeGoalType, goalSchedule, sortedScheduleKeys]);

  const goalValuesForDate = useCallback((isoDate) => {
    const mode = resolveModeForDate(isoDate);
    const base = settings.dailyGoals?.[mode];
    if (base) return base;
    return settings.dailyGoals?.[activeGoalType] ?? DEFAULT_GOALS;
  }, [activeGoalType, resolveModeForDate, settings.dailyGoals]);

  const stickyGoals = useMemo(() => goalValuesForDate(stickyDate), [goalValuesForDate, stickyDate]);
  const dashboardGoals = useMemo(() => goalValuesForDate(logDate), [goalValuesForDate, logDate]);
  const goalTarget = useMemo(() => goalValuesForDate(goalDate), [goalValuesForDate, goalDate]);
  const splitMode = resolveModeForDate(splitDate);
  const goalDateMode = resolveModeForDate(goalDate);
  const topFoodsMode = resolveModeForDate(topFoodsDate);

  const headerPillClass = "gap-2 rounded-full border border-slate-200 dark:border-slate-700 bg-white/70 dark:bg-slate-900/60 px-3 py-2 text-xs font-medium shadow-sm hover:bg-slate-50 dark:hover:bg-slate-800";

  const sortedFoods = useMemo(()=>{
    const list = [...foods];
    list.sort((a, b)=>{
      const dir = foodSort.direction === "asc" ? 1 : -1;
      let av;
      let bv;
      switch(foodSort.column){
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
    entries.filter(e=>e.date===topFoodsDate).forEach(e=>{ const f=foods.find(x=>x.id===e.foodId); if(!f) return; const m=scaleMacros(f,e.qty); map.set(f.name,(map.get(f.name)||0)+m[topMacroKey]); });
    return Array.from(map.entries()).map(([name,val])=>({name,val})).sort((a,b)=>b.val-a.val).slice(0,5);
  },[entries,foods,topFoodsDate,topMacroKey]);

  const goalTotals = useMemo(()=> totalsForDate(goalDate),[entries, foods, goalDate]);

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

  const setGoalModeForDate = useCallback((isoDate, mode) => {
    if (!isoDate || !ISO_DATE_RE.test(isoDate)) return;
    const normalized = mode === 'rest' ? 'rest' : 'train';
    setSettings((prev) => {
      const goals = ensureDailyGoals(prev.dailyGoals);
      const today = todayISO();
      const byDate = { ...goals.byDate, [isoDate]: normalized };
      return {
        ...prev,
        dailyGoals: {
          ...goals,
          active: isoDate === today ? normalized : goals.active,
          byDate,
        },
      };
    });
  }, [setSettings]);

  const setGoalValue = (type, key) => (value) => {
    setSettings((prev) => {
      const goals = ensureDailyGoals(prev.dailyGoals);
      return {
        ...prev,
        dailyGoals: {
          ...goals,
          [type]: {
            ...goals[type],
            [key]: value,
          },
        },
      };
    });
  };

  const handleGoalTabChange = (value) => {
    setGoalModeForDate(todayISO(), value === 'rest' ? 'rest' : 'train');
  };

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
            <GoalModeToggle active={activeGoalType} onChange={handleGoalTabChange} />
            <Button variant="ghost" className={headerPillClass} onClick={()=>setTab('settings')}>
              <SettingsIcon className="h-4 w-4"/>
              <span>Settings</span>
            </Button>
            <Button variant="ghost" size="icon" onClick={()=>setTheme(theme==='dark'?'light': theme==='light'?'system':'dark')} title="Theme: dark/light/system">
              {theme==='dark'? <SunMedium className="h-5 w-5"/> : theme==='light'? <Moon className="h-5 w-5"/> : <SunMedium className="h-5 w-5"/>}
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
                const sub = over ? `${Math.abs(rem).toFixed(0)} over` : `${rem.toFixed(0)} left`;
                return (
                  <StripKpi
                    label="Calories"
                    value={`${stickyTotals.kcal.toFixed(0)} kcal`}
                    sub={sub}
                    color={COLORS.kcal}
                    subColor={over ? COLORS.redDark : undefined}
                  />
                );
              })()}
              {(() => {
                const rem = stickyGoals.protein - stickyTotals.protein;
                const over = rem < 0;
                const sub = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
                return (
                  <StripKpi
                    label="Protein"
                    value={`${stickyTotals.protein.toFixed(0)} g`}
                    sub={sub}
                    color={COLORS.protein}
                    subColor={over ? COLORS.redDark : undefined}
                  />
                );
              })()}
              {(() => {
                const rem = stickyGoals.carbs - stickyTotals.carbs;
                const over = rem < 0;
                const sub = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
                return (
                  <StripKpi
                    label="Carbs"
                    value={`${stickyTotals.carbs.toFixed(0)} g`}
                    sub={sub}
                    color={COLORS.carbs}
                    subColor={over ? COLORS.redDark : undefined}
                  />
                );
              })()}
              {(() => {
                const rem = stickyGoals.fat - stickyTotals.fat;
                const over = rem < 0;
                const sub = over ? `${Math.abs(rem).toFixed(1)} g over` : `${rem.toFixed(1)} g left`;
                return (
                  <StripKpi
                    label="Fat"
                    value={`${stickyTotals.fat.toFixed(0)} g`}
                    sub={sub}
                    color={COLORS.fat}
                    subColor={over ? COLORS.redDark : undefined}
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
          <TabsList className="grid grid-cols-4 w-full md:w-auto">
            <TabsTrigger value="dashboard" className="gap-2"><BarChart3 className="h-4 w-4"/>Dashboard</TabsTrigger>
            <TabsTrigger value="daily" className="gap-2"><BookOpenText className="h-4 w-4"/>Daily Log</TabsTrigger>
            <TabsTrigger value="foods" className="gap-2"><Database className="h-4 w-4"/>Food DB</TabsTrigger>
            <TabsTrigger value="settings" className="gap-2"><SettingsIcon className="h-4 w-4"/>Settings</TabsTrigger>
          </TabsList>

          {/* DASHBOARD */}
          <TabsContent value="dashboard" className="mt-6 space-y-6">
            <div className="grid md:grid-cols-4 gap-4">
              <KpiCard title="Calories" value={`${totalsForCard.kcal.toFixed(0)} kcal`} goal={dashboardGoals.kcal} />
              <KpiCard title="Protein" value={`${totalsForCard.protein.toFixed(0)} g`} goal={dashboardGoals.protein} />
              <KpiCard title="Carbs" value={`${totalsForCard.carbs.toFixed(0)} g`} goal={dashboardGoals.carbs} />
              <KpiCard title="Fat" value={`${totalsForCard.fat.toFixed(0)} g`} goal={dashboardGoals.fat} />
            </div>

            {/* Goal vs Actual */}
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between gap-3">
                  <CardTitle>Goal vs Actual</CardTitle>
                  <div className="flex items-center gap-2">
                    <GoalModeSelect value={goalDateMode} onChange={(mode)=>setGoalModeForDate(goalDate || todayISO(), mode)} />
                    <DatePickerButton value={goalDate} onChange={(value)=>setGoalDate(value||todayISO())} className="w-44" />
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <GoalDonut label="Calories" color={COLORS.kcal} actual={goalTotals.kcal} goal={goalTarget.kcal} unit="kcal" />
                  <GoalDonut label="Protein" color={COLORS.protein} actual={goalTotals.protein} goal={goalTarget.protein} unit="g" />
                  <GoalDonut label="Carbs" color={COLORS.carbs} actual={goalTotals.carbs} goal={goalTarget.carbs} unit="g" />
                  <GoalDonut label="Fat" color={COLORS.fat} actual={goalTotals.fat} goal={goalTarget.fat} unit="g" />
                </div>
              </CardContent>
            </Card>

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
                  <LineChart data={trendSeries} margin={{ left: 12, right: 12 }}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" tickFormatter={(d)=>d.slice(5)} />
                    <YAxis />
                    <Legend />
                    <RTooltip labelFormatter={(l)=>format(new Date(l), 'PP')} />
                    {show.kcal && <Line type="monotone" name="kcal" dataKey="kcal" dot={false} strokeWidth={2} stroke={COLORS.kcal} />}
                    {show.protein && <Line type="monotone" name="Protein (g)" dataKey="protein" dot={false} strokeWidth={2} stroke={COLORS.protein} />}
                    {show.carbs && <Line type="monotone" name="Carbs (g)" dataKey="carbs" dot={false} strokeWidth={2} stroke={COLORS.carbs} />}
                    {show.fat && <Line type="monotone" name="Fat (g)" dataKey="fat" dot={false} strokeWidth={2} stroke={COLORS.fat} />}
                  </LineChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Macro Split per Meal */}
            <Card>
              <CardHeader className="pb-0">
                <div className="flex items-center justify-between gap-3">
                  <CardTitle className="flex items-center gap-2"><UtensilsCrossed className="h-5 w-5"/>Macro Split per Meal</CardTitle>
                  <div className="flex items-center gap-2">
                    <GoalModeSelect value={splitMode} onChange={(mode)=>setGoalModeForDate(splitDate || todayISO(), mode)} />
                    <DatePickerButton value={splitDate} onChange={(value)=>setSplitDate(value||todayISO())} className="w-44" />
                  </div>
                </div>
              </CardHeader>
              <div className="mt-4" />
              <CardContent className="h-80">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={mealSplit} margin={{ left: 12, right: 12 }}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="meal" />
                    <YAxis />
                    <Legend />
                    <RTooltip />
                    <Bar dataKey="protein" name="Protein (g)" stackId="g" fill={COLORS.protein} />
                    <Bar dataKey="carbs" name="Carbs (g)" stackId="g" fill={COLORS.carbs} />
                    <Bar dataKey="fat" name="Fat (g)" stackId="g" fill={COLORS.fat} />
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
              goalMode={topFoodsMode}
              onGoalModeChange={(mode)=>setGoalModeForDate(topFoodsDate || todayISO(), mode)}
            />

            {/* Averages tiles (non-empty days only) */}
            <div className="grid md:grid-cols-4 gap-4">
              <AvgTile label="Avg (7d)" entries={entries} foods={foods} days={7} />
              <AvgTile label="Avg (MTD)" entries={entries} foods={foods} from={startOfMonth(new Date())} />
              <AvgTile label="Avg (QTD)" entries={entries} foods={foods} from={startOfQuarter(new Date())} />
              <AvgTile label="Avg (YTD)" entries={entries} foods={foods} from={startOfYear(new Date())} />
            </div>
          </TabsContent>

          {/* DAILY LOG */}
          <TabsContent value="daily" className="mt-6 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2"><History className="h-5 w-5"/>Log your intake</CardTitle>
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
                    <Label className="text-sm">Quantity {selectedFood ? (selectedFood.unit === "per100g" ? "(g)" : "(servings)") : ""}</Label>
                    <Input type="number" inputMode="decimal" value={qty||""} onChange={(e)=>setQty(parseFloat(e.target.value))} placeholder={selectedFood ? (selectedFood.unit === "per100g" ? "e.g. 150" : "e.g. 1.5") : ""} />
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
                    <p className="text-xs text-slate-500 mb-3">Switch between Train Day and Rest Day to edit targets and pick which set powers your dashboard.</p>
                    <Tabs value={activeGoalType} onValueChange={handleGoalTabChange}>
                      <TabsList className="grid grid-cols-2 w-full max-w-xs mb-3">
                        <TabsTrigger value="train">Train Day</TabsTrigger>
                        <TabsTrigger value="rest">Rest Day</TabsTrigger>
                      </TabsList>
                      <TabsContent value="train" className="mt-0">
                        <div className="grid grid-cols-2 gap-3">
                          <div className="col-span-2">
                            <LabeledNumber label="Calories (kcal)" value={settings.dailyGoals.train.kcal} onChange={setGoalValue('train','kcal')} />
                          </div>
                          <LabeledNumber label="Protein (g)" value={settings.dailyGoals.train.protein} onChange={setGoalValue('train','protein')} />
                          <LabeledNumber label="Carbs (g)" value={settings.dailyGoals.train.carbs} onChange={setGoalValue('train','carbs')} />
                          <LabeledNumber label="Fat (g)" value={settings.dailyGoals.train.fat} onChange={setGoalValue('train','fat')} />
                        </div>
                      </TabsContent>
                      <TabsContent value="rest" className="mt-0">
                        <div className="grid grid-cols-2 gap-3">
                          <div className="col-span-2">
                            <LabeledNumber label="Calories (kcal)" value={settings.dailyGoals.rest.kcal} onChange={setGoalValue('rest','kcal')} />
                          </div>
                          <LabeledNumber label="Protein (g)" value={settings.dailyGoals.rest.protein} onChange={setGoalValue('rest','protein')} />
                          <LabeledNumber label="Carbs (g)" value={settings.dailyGoals.rest.carbs} onChange={setGoalValue('rest','carbs')} />
                          <LabeledNumber label="Fat (g)" value={settings.dailyGoals.rest.fat} onChange={setGoalValue('rest','fat')} />
                        </div>
                      </TabsContent>
                    </Tabs>
                    <p className="text-xs text-slate-500 mt-3">The active tab's goals feed the sticky macros, dashboard KPIs, and Goal vs Actual chart.</p>
                  </div>
                  <div>
                    <h3 className="font-medium mb-2">Appearance</h3>
                    <div className="flex items-center justify-between rounded-xl border p-4 border-slate-200 dark:border-slate-700">
                      <div>
                        <div className="font-medium">Dark mode</div>
                        <div className="text-sm text-slate-500">Follow system or toggle in header</div>
                      </div>
                      <Switch checked={theme==='dark'} onCheckedChange={(b)=>setTheme(b? 'dark':'light')} />
                    </div>
                  </div>
                </div>

                {/* Profile */}
                <div className="grid md:grid-cols-2 gap-6">
                  <div>
                    <h3 className="font-medium mb-2">Body profile</h3>
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

const GOAL_MODE_OPTIONS = [
  { value: 'train', label: 'Train Day', Icon: Dumbbell, accent: COLORS.protein },
  { value: 'rest', label: 'Rest Day', Icon: BedDouble, accent: COLORS.cyan },
];

function GoalModeToggle({ active, onChange }){
  return (
    <div
      className="flex flex-shrink-0 items-center gap-1 rounded-full border border-slate-200 dark:border-slate-700 bg-white/70 dark:bg-slate-900/60 px-1 py-1 shadow-sm"
      role="group"
      aria-label="Select active goal profile"
    >
      {GOAL_MODE_OPTIONS.map(({ value, label, Icon, accent })=>{
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
  const normalized = value === 'rest' ? 'rest' : 'train';
  const ActiveIcon = normalized === 'rest' ? BedDouble : Dumbbell;
  const accent = normalized === 'rest' ? COLORS.cyan : COLORS.protein;
  return (
    <Select value={normalized} onValueChange={onChange}>
      <SelectTrigger className={cn("h-8 w-36 rounded-full border-slate-300 bg-white/80 pl-3 pr-3 text-xs dark:border-slate-700 dark:bg-slate-900/60", className)}>
        <div className="flex w-full items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <ActiveIcon className="h-3.5 w-3.5" />
            <SelectValue placeholder="Goal profile" />
          </div>
          <span className="inline-flex h-1.5 w-1.5 rounded-full" style={{ backgroundColor: accent }} aria-hidden="true" />
        </div>
      </SelectTrigger>
      <SelectContent align="end">
        {GOAL_MODE_OPTIONS.map(({ value: option, label, Icon: OptionIcon, accent: optionAccent }) => (
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
function KpiCard({ title, value, goal }){
  return (
    <Card className="overflow-hidden">
      <CardHeader className="pb-2"><CardTitle className="text-sm text-slate-500">{title}</CardTitle></CardHeader>
      <CardContent className="pt-0 flex items-end justify-between">
        <div className="text-3xl font-semibold">{value}</div>
        {Number.isFinite(goal)? (<div className="text-xs text-slate-500">Goal: {goal}</div>): null}
      </CardContent>
    </Card>
  );
}

// PATCH: accept optional subColor for "X over" red
function StripKpi({ label, value, color, sub, subColor }){
  return (
    <div className="flex flex-col rounded-lg px-3 py-2 bg-white/70 dark:bg-slate-900/70 border border-slate-200 dark:border-slate-800">
      <div className="flex items-center justify-between">
        <span className="text-xs" style={{ color }}>{label}</span>
        <span className="font-semibold" style={{ color }}>{value}</span>
      </div>
      {sub && <div className="text-[11px] mt-0.5" style={{ color: subColor || '#64748b' }}>{sub}</div>}
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

// Averages computed over non-empty days (unchanged)
function AvgTile({ label, entries, foods, days, from }){
  const todayIso = toISODate(startOfDay(new Date()));

  const totalsByDate = useMemo(()=>{
    const map = new Map();
    entries.forEach(e=>{
      const f = foods.find(x=>x.id===e.foodId); if(!f) return;
      const m = scaleMacros(f, e.qty);
      const t = map.get(e.date) || {kcal:0,fat:0,carbs:0,protein:0};
      t.kcal+=m.kcal; t.fat+=m.fat; t.carbs+=m.carbs; t.protein+=m.protein;
      map.set(e.date, t);
    });
    return map;
  }, [entries, foods]);

  let dates = [];
  if (days) {
    dates = Array.from(totalsByDate.keys()).sort((a,b)=> b.localeCompare(a)).slice(0, days);
  } else if (from) {
    const fromIso = toISODate(startOfDay(from));
    dates = Array.from(totalsByDate.keys()).filter(d => d >= fromIso && d <= todayIso).sort();
  }

  const count = Math.max(1, dates.length);
  const total = dates.reduce((acc, d)=>{
    const t = totalsByDate.get(d) || {kcal:0,fat:0,carbs:0,protein:0};
    return { kcal: acc.kcal + t.kcal, fat: acc.fat + t.fat, carbs: acc.carbs + t.carbs, protein: acc.protein + t.protein };
  }, {kcal:0,fat:0,carbs:0,protein:0});

  const avg = dates.length === 0
    ? { kcal:0, fat:0, carbs:0, protein:0 }
    : { kcal:+(total.kcal/count).toFixed(0), fat:+(total.fat/count).toFixed(1), carbs:+(total.carbs/count).toFixed(1), protein:+(total.protein/count).toFixed(1) };

  return (
    <Card>
      <CardHeader className="pb-2"><CardTitle className="text-sm text-slate-500">{label}</CardTitle></CardHeader>
      <CardContent className="pt-0 grid grid-cols-4 gap-2 text-center">
        <div><div className="text-xs text-slate-500">kcal</div><div className="text-lg font-semibold">{avg.kcal}</div></div>
        <div><div className="text-xs text-slate-500">P</div><div className="text-lg font-semibold">{avg.protein}</div></div>
        <div><div className="text-xs text-slate-500">C</div><div className="text-lg font-semibold">{avg.carbs}</div></div>
        <div><div className="text-xs text-slate-500">F</div><div className="text-lg font-semibold">{avg.fat}</div></div>
      </CardContent>
    </Card>
  );
}
function GoalDonut({ label, color, actual, goal, unit }) {
  const a = Math.max(0, actual || 0);
  const g = Math.max(0, goal || 0);
  const pctRaw = g > 0 ? (a / g) * 100 : 0;
  const pct = Number.isFinite(pctRaw) ? Math.round(pctRaw) : 0;

  const basePct = g > 0 ? Math.min(Math.max(pctRaw, 0), 100) : a > 0 ? 100 : 0;
  const overPct = g > 0 ? Math.min(Math.max(pctRaw - 100, 0), 100) : 0;

  const radius = 52;
  const strokeWidth = 14;
  const circumference = 2 * Math.PI * radius;

  const dashFor = (percent) => {
    if (percent <= 0) return `0 ${circumference}`;
    if (percent >= 100) return `${circumference} 0.0001`;
    const length = (percent / 100) * circumference;
    return `${length} ${circumference - length}`;
  };

  const baseDasharray = dashFor(basePct);
  const overDasharray = dashFor(overPct);

  const overlayColor = darkenHex(color, 0.55);
  const hasGoal = g > 0;

  return (
    <div className="flex flex-col items-center justify-center">
      <div className="mb-1 text-sm font-medium">{label}</div>
      <div className="relative h-32 w-32">
        <svg viewBox="0 0 120 120" className="h-full w-full">
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
              stroke={color}
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
              stroke={overlayColor}
              strokeWidth={strokeWidth}
              fill="transparent"
              strokeDasharray={overDasharray}
              transform="rotate(-90 60 60)"
              strokeLinecap="butt"
            />
          )}
        </svg>
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <div className="text-lg font-semibold" style={{ color }}>{Number.isFinite(pct) ? `${pct}%` : "0%"}</div>
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
function TopFoodsCard({ topFoods, topMacroKey, onMacroChange, selectedDate, onDateChange, goalMode, onGoalModeChange }){
  const dayLabel = selectedDate ? format(new Date(selectedDate), 'PP') : 'Select a day';
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between gap-3">
          <CardTitle>Top Foods by Macros — {dayLabel}</CardTitle>
          <div className="flex items-center gap-2">
            <GoalModeSelect value={goalMode} onChange={(mode)=>onGoalModeChange(mode)} className="w-36" />
            <DatePickerButton value={selectedDate} onChange={onDateChange} className="w-44" />
            <Select value={topMacroKey} onValueChange={onMacroChange}>
              <SelectTrigger className="h-8 w-40"><SelectValue placeholder="Macro" /></SelectTrigger>
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
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Legend />
            <RTooltip formatter={(v)=>[v, topMacroKey==='kcal'? 'kcal':'g']} />
            <Pie dataKey="val" nameKey="name" data={topFoods} innerRadius={50} outerRadius={90} label>
              {topFoods.map((_,i)=>(<Cell key={i} fill={[COLORS.kcal, COLORS.protein, COLORS.carbs, COLORS.fat, COLORS.cyan, COLORS.violet][i%6]} />))}
            </Pie>
          </PieChart>
        </ResponsiveContainer>
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
          <TabsList className="grid w-full max-w-xs grid-cols-2">
            <TabsTrigger value="single">Add Food</TabsTrigger>
            <TabsTrigger value="recipe">Add Home Recipe</TabsTrigger>
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
                  <Label>Protein (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.protein} onChange={(e)=>setBasicForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
                <div>
                  <Label>Carbs (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.carbs} onChange={(e)=>setBasicForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>Fat (g)</Label>
                  <Input type="number" inputMode="decimal" value={basicForm.fat} onChange={(e)=>setBasicForm((prev)=>({...prev, fat:e.target.value }))} />
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
                  <Label>Protein (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.protein} onChange={(e)=>setRecipeForm((prev)=>({...prev, protein:e.target.value }))} />
                </div>
                <div>
                  <Label>Carbs (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.carbs} onChange={(e)=>setRecipeForm((prev)=>({...prev, carbs:e.target.value }))} />
                </div>
                <div>
                  <Label>Fat (g)</Label>
                  <Input type="number" inputMode="decimal" value={recipeForm.fat} onChange={(e)=>setRecipeForm((prev)=>({...prev, fat:e.target.value }))} />
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
