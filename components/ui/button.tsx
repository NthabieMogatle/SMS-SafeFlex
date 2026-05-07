import { clsx } from "clsx";
import type { ButtonHTMLAttributes } from "react";

type Variant = "primary" | "secondary";

export function Button({
  variant = "primary",
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return (
    <button
      {...props}
      className={clsx(
        "rounded-md px-4 py-2 text-sm font-medium transition disabled:opacity-50",
        variant === "primary" &&
          "bg-foreground text-background hover:opacity-90",
        variant === "secondary" &&
          "border border-foreground/20 hover:bg-foreground/5",
        className
      )}
    />
  );
}
