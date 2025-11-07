"use client"

import * as React from "react"
import * as SelectPrimitive from "@radix-ui/react-select"
import { Check, ChevronDown } from "lucide-react"
import { cn } from "@/lib/utils"

export const Select = SelectPrimitive.Root
export const SelectGroup = SelectPrimitive.Group
export const SelectValue = SelectPrimitive.Value

export const SelectTrigger = React.forwardRef(
  ({ className, children, ...props }, ref) => (
    <SelectPrimitive.Trigger
      ref={ref}
      className={cn(
        // solid background + border so it’s readable in light/dark
        "flex h-9 w-[180px] items-center justify-between rounded-md border border-slate-200 bg-white px-3 py-2 text-sm " +
          "focus:outline-none focus:ring-2 focus:ring-slate-400 disabled:cursor-not-allowed disabled:opacity-50 " +
          "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100 dark:focus:ring-slate-700",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDown className="h-4 w-4 opacity-60" />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
)
SelectTrigger.displayName = SelectPrimitive.Trigger.displayName

export const SelectContent = React.forwardRef(
  ({ className, children, ...props }, ref) => (
    // Portal to body avoids clipping by any parent overflow/transform
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        ref={ref}
        position="popper"
        sideOffset={6}
        // HUGE z-index + explicit bg/border so it’s not transparent
        className={cn(
          "z-[99999] min-w-[8rem] overflow-hidden rounded-md border border-slate-200 bg-white text-slate-900 shadow-lg " +
            "dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100",
          className
        )}
        {...props}
      >
        <SelectPrimitive.Viewport className="p-1">
          {children}
        </SelectPrimitive.Viewport>
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
)
SelectContent.displayName = SelectPrimitive.Content.displayName

export const SelectItem = React.forwardRef(
  ({ className, children, ...props }, ref) => (
    <SelectPrimitive.Item
      ref={ref}
      className={cn(
        // solid row bg on focus/hover; readable text colors
        "relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm " +
          "outline-none hover:bg-slate-50 focus:bg-slate-100 " +
          "data-[disabled]:pointer-events-none data-[disabled]:opacity-50 " +
          "dark:hover:bg-slate-800 dark:focus:bg-slate-800",
        className
      )}
      {...props}
    >
      <span className="absolute left-2 flex h-3.5 w-3.5 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <Check className="h-4 w-4" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
)
SelectItem.displayName = SelectPrimitive.Item.displayName
