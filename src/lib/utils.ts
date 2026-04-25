import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/** Combines class names conditionally. Keeps Tailwind utilities merged cleanly. */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

/** Formats numbers safely (used in dashboard KPIs). */
export function formatNumber(value: number, decimals: number = 0): string {
  if (isNaN(value)) return "0";
  return Number(value).toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

/** Returns today's date as an ISO string (YYYY-MM-DD) in local time. */
export function todayISO(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}
