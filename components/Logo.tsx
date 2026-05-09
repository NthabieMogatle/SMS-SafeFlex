type Variant = "light" | "dark";

const PRODUCT_NAME = "AI Mock Interview Coach";

export function Wordmark({
  variant = "light",
  className,
}: {
  variant?: Variant;
  className?: string;
}) {
  const accent = variant === "light" ? "#22D3EE" : "#0891B2";
  const text = variant === "light" ? "#FFFFFF" : "#0F172A";

  return (
    <svg
      viewBox="0 0 320 36"
      role="img"
      aria-label={PRODUCT_NAME}
      className={className}
    >
      <title>{PRODUCT_NAME}</title>
      <text
        x="0"
        y="26"
        fontFamily="system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        fontSize="22"
        letterSpacing="-0.01em"
      >
        <tspan fontWeight="800" fill={accent}>
          AI
        </tspan>
        <tspan fontWeight="500" fill={text}>
          {" "}Mock Interview Coach
        </tspan>
      </text>
    </svg>
  );
}
