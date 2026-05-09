import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Elevra — The interview, elevated.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          background:
            "linear-gradient(135deg, #060911 0%, #0a0e1a 50%, #0f1730 100%)",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          padding: 96,
          color: "white",
          fontFamily: "system-ui, -apple-system, sans-serif",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            marginBottom: 40,
          }}
        >
          {/* Power-button glyph */}
          <svg width="56" height="56" viewBox="0 0 64 64" fill="none">
            <g
              transform="translate(32 33)"
              stroke="#22D3EE"
              strokeWidth="4"
              strokeLinecap="round"
              fill="none"
            >
              <path d="M -8 -10 A 14 14 0 1 0 8 -10" />
              <line x1="0" y1="-16" x2="0" y2="0" />
            </g>
          </svg>
          <div
            style={{
              fontSize: 28,
              color: "rgb(255 255 255 / 0.7)",
              letterSpacing: 4,
              textTransform: "uppercase",
              fontWeight: 600,
            }}
          >
            Elevra
          </div>
        </div>
        <div
          style={{
            fontSize: 110,
            fontWeight: 700,
            lineHeight: 1.05,
            letterSpacing: -3,
            maxWidth: 1000,
          }}
        >
          The interview,{" "}
          <span style={{ color: "#22D3EE" }}>elevated.</span>
        </div>
        <div
          style={{
            fontSize: 28,
            opacity: 0.7,
            marginTop: 36,
            maxWidth: 920,
            lineHeight: 1.4,
          }}
        >
          Practice mock interviews with an AI coach. Scored answers,
          targeted feedback, rewritten responses that win interviews.
        </div>
      </div>
    ),
    { ...size },
  );
}
