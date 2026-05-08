import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Career OS — AI mock interviews that actually help you improve";
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
            fontSize: 24,
            color: "rgb(52 211 153)",
            letterSpacing: 4,
            textTransform: "uppercase",
            fontWeight: 600,
            marginBottom: 24,
          }}
        >
          Career OS
        </div>
        <div
          style={{
            fontSize: 88,
            fontWeight: 700,
            lineHeight: 1.05,
            letterSpacing: -2,
            maxWidth: 980,
          }}
        >
          AI mock interviews that actually help you improve.
        </div>
        <div
          style={{
            fontSize: 28,
            opacity: 0.7,
            marginTop: 32,
            maxWidth: 880,
            lineHeight: 1.4,
          }}
        >
          Scored answers, targeted feedback, and rewritten responses
          calibrated to your role, industry, and experience.
        </div>
      </div>
    ),
    { ...size },
  );
}
