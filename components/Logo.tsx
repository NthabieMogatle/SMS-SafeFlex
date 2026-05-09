type Variant = "light" | "dark";

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
      viewBox="0 0 220 72"
      role="img"
      aria-label="Elevra"
      className={className}
    >
      <title>Elevra</title>
      <g
        transform="translate(8 16)"
        stroke={accent}
        strokeWidth="3.5"
        strokeLinecap="round"
        fill="none"
      >
        <path d="M 12 9 A 16 16 0 1 0 32 9" />
        <line x1="22" y1="2" x2="22" y2="22" />
      </g>
      <text
        x="64"
        y="48"
        fontFamily="system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif"
        fontSize="32"
        letterSpacing="-0.02em"
      >
        <tspan fontWeight="500" fill={text}>
          Elev
        </tspan>
        <tspan fontWeight="800" fill={accent}>
          ra
        </tspan>
      </text>
    </svg>
  );
}
