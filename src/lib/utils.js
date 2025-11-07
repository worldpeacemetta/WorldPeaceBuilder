import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

/**
 * Combines class names conditionally.
 * Keeps Tailwind utilities merged cleanly.
 */
export function cn(...inputs) {
  return twMerge(clsx(inputs))
}

/**
 * Formats numbers safely (used in dashboard KPIs)
 */
export function formatNumber(value, decimals = 0) {
  if (isNaN(value)) return "0"
  return Number(value).toLocaleString(undefined, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  })
}

/**
 * Utility to get today's date (used for default log date)
 */
export function todayISO() {
  return new Date().toISOString().split("T")[0]
}
