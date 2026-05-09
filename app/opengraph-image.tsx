import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt =
  "AI Mock Interview Coach — Practice interviews with AI. Get hired faster.";
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
            fontSize: 30,
            color: "rgb(255 255 255 / 0.7)",
            letterSpacing: 4,
            textTransform: "uppercase",
            fontWeight: 600,
            marginBottom: 36,
            display: "flex",
            alignItems: "center",
            gap: 14,
          }}
        >
          <span style={{ color: "#22D3EE", fontWeight: 800 }}>AI</span>
          <span>Mock Interview Coach</span>
        </div>
        <div
          style={{
            fontSize: 96,
            fontWeight: 700,
            lineHeight: 1.05,
            letterSpacing: -3,
            maxWidth: 1000,
          }}
        >
          Practice interviews with{" "}
          <span style={{ color: "#22D3EE" }}>AI.</span>
        </div>
        <div
          style={{
            fontSize: 96,
            fontWeight: 700,
            lineHeight: 1.05,
            letterSpacing: -3,
            maxWidth: 1000,
          }}
        >
          Get <span style={{ color: "#22D3EE" }}>hired</span> faster.
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
          Scored answers, targeted feedback, and rewritten responses that
          win interviews.
        </div>
      </div>
    ),
    { ...size },
  );
}
