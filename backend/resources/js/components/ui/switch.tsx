import * as React from "react"
import { Switch as SwitchPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"

function Switch({
  className,
  size = "default",
  ...props
}: React.ComponentProps<typeof SwitchPrimitive.Root> & {
  size?: "sm" | "default" | "lg"
}) {
  const track =
    size === "sm" ? "h-5 w-9" : size === "lg" ? "h-7 w-12" : "h-6 w-11"
  const thumb =
    size === "sm" ? "size-4" : size === "lg" ? "size-6" : "size-5"
  const thumbOn =
    size === "sm"
      ? "group-data-[state=checked]:translate-x-4"
      : "group-data-[state=checked]:translate-x-5"

  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      className={cn(
        "group inline-flex shrink-0 cursor-pointer items-center rounded-full border border-transparent p-0.5 shadow-xs transition-colors outline-none",
        "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50",
        "disabled:cursor-not-allowed disabled:opacity-50",
        "data-[state=checked]:bg-primary data-[state=unchecked]:bg-input",
        "dark:data-[state=unchecked]:bg-input/80",
        track,
        className
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        data-slot="switch-thumb"
        className={cn(
          "pointer-events-none block rounded-full bg-background shadow-sm ring-0 transition-transform duration-200 ease-in-out",
          "translate-x-0",
          thumb,
          thumbOn,
          "dark:group-data-[state=checked]:bg-primary-foreground",
          "dark:group-data-[state=unchecked]:bg-foreground"
        )}
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }
