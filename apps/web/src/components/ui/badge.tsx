import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-3 py-1 text-xs font-medium transition-colors",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-primary/10 text-primary backdrop-blur",
        secondary:
          "border-transparent bg-secondary text-secondary-foreground",
        outline: "text-foreground border-border",
        success:
          "border-transparent bg-emerald-500/10 text-emerald-600 dark:text-emerald-400",
        warn: "border-transparent bg-amber-500/10 text-amber-600 dark:text-amber-400",
      },
    },
    defaultVariants: { variant: "default" },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };
