import * as React from "react";
import { cn } from "@/lib/utils";

export const Table = ({ className, ...props }) => (
  <div className="relative w-full overflow-auto">
    <table className={cn("w-full caption-bottom text-sm", className)} {...props} />
  </div>
);

export const TableHeader = ({ className, ...props }) => (
  <thead className={cn("[&_tr]:border-b", className)} {...props} />
);

export const TableBody = ({ className, ...props }) => (
  <tbody className={cn("[&_tr:last-child]:border-0", className)} {...props} />
);

export const TableFooter = ({ className, ...props }) => (
  <tfoot className={cn("bg-slate-100 font-medium text-slate-900 dark:bg-slate-800 dark:text-slate-50", className)} {...props} />
);

export const TableRow = ({ className, ...props }) => (
  <tr className={cn("border-b transition-colors hover:bg-slate-50 dark:hover:bg-slate-800/50", className)} {...props} />
);

export const TableHead = ({ className, ...props }) => (
  <th className={cn("h-10 px-2 text-left align-middle font-medium text-slate-500 dark:text-slate-400", className)} {...props} />
);

export const TableCell = ({ className, ...props }) => (
  <td className={cn("p-2 align-middle", className)} {...props} />
);
