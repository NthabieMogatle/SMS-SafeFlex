import type { Metadata, Viewport } from "next";
import "./globals.css";

function siteUrl(): URL {
  const raw = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  const candidate =
    raw && raw.length > 0 ? raw : "https://career-os-alpha.vercel.app";
  // Tolerate values entered without a protocol (e.g. "career-os.vercel.app")
  // — `new URL` would otherwise throw at build time and fail metadata gen.
  const withProtocol = /^https?:\/\//i.test(candidate)
    ? candidate
    : `https://${candidate}`;
  try {
    return new URL(withProtocol);
  } catch {
    return new URL("https://career-os-alpha.vercel.app");
  }
}

const SITE_URL = siteUrl();

export const metadata: Metadata = {
  metadataBase: SITE_URL,
  title: {
    default: "Career OS — AI mock interviews that actually help you improve",
    template: "%s · Career OS",
  },
  description:
    "Practice mock interviews with an AI coach. Get scored answers, targeted feedback, and rewritten responses calibrated to your role, industry, and experience.",
  applicationName: "Career OS",
  authors: [{ name: "Career OS" }],
  keywords: [
    "mock interview",
    "AI interview coach",
    "interview practice",
    "behavioral interview",
    "technical interview",
    "career preparation",
  ],
  openGraph: {
    type: "website",
    siteName: "Career OS",
    title: "Career OS — AI mock interviews that actually help you improve",
    description:
      "AI mock interviews calibrated to your role, industry, and experience. Scored feedback, rewritten answers, and progress tracking.",
    url: SITE_URL.toString(),
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Career OS — AI mock interviews that actually help you improve",
    description:
      "AI mock interviews calibrated to your role, industry, and experience.",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0e1a",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  );
}
