import * as React from "react";
import { cn } from "@/lib/utils";

export function Card({ className, ...props }) {
  return <div className={cn("rounded-xl border bg-white dark:bg-slate-900 text-slate-950 dark:text-slate-50 shadow-sm", className)} {...props} />;
}

export function CardHeader({ className, ...props }) {
  return <div className={cn("flex flex-col space-y-1.5 p-4", className)} {...props} />;
}

export function CardTitle({ className, ...props }) {
  return <h3 className={cn("text-lg font-semibold leading-none tracking-tight", className)} {...props} />;
}

export function CardContent({ className, ...props }) {
  return <div className={cn("p-4 pt-0", className)} {...props} />;
}
