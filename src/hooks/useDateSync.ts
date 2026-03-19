import { useState, useEffect } from 'react';
import { todayISO } from '@/lib/utils';

const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export interface DateSyncState {
  logDate: string;
  setLogDate: (date: string) => void;
  dashboardDate: string;
  setDashboardDate: (date: string) => void;
  weekNavDate: string;
  setWeekNavDate: (date: string) => void;
  stickyMode: string;
  setStickyMode: (mode: string) => void;
  effectiveStickyMode: string;
  stickyDate: string;
  today: string;
}

/**
 * Manages the three synchronized date values that drive the Daily Log,
 * Dashboard, and Weekly Nutrition chart, plus the sticky header mode.
 *
 * Sync rules:
 *   logDate changes → dashboardDate + weekNavDate follow automatically
 *   Dashboard date picker → call setDashboardDate + setWeekNavDate directly
 *   "Today" button → call setLogDate + setDashboardDate + setWeekNavDate
 *   Week prev/next arrows → call setWeekNavDate only (intentional independent browse)
 */
export function useDateSync(): DateSyncState {
  const [logDate, setLogDate] = useState<string>(todayISO);
  const [dashboardDate, setDashboardDate] = useState<string>(todayISO);
  const [weekNavDate, setWeekNavDate] = useState<string>(todayISO);
  const [stickyMode, setStickyMode] = useState<string>('today');

  // Sync dashboard and week-nav whenever the log date changes.
  useEffect(() => {
    const target = ISO_DATE_RE.test(logDate) ? logDate : todayISO();
    setDashboardDate(target);
    setWeekNavDate(target);
  }, [logDate]);

  const today = todayISO();

  // Derived — never store in state to avoid a second render that closes
  // native <input type="date"> pickers mid-interaction.
  const effectiveStickyMode =
    logDate !== today || dashboardDate !== today ? 'selected' : stickyMode;
  const stickyDate = effectiveStickyMode === 'today' ? today : dashboardDate;

  return {
    logDate,
    setLogDate,
    dashboardDate,
    setDashboardDate,
    weekNavDate,
    setWeekNavDate,
    stickyMode,
    setStickyMode,
    effectiveStickyMode,
    stickyDate,
    today,
  };
}
