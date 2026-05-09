import type { Metadata, Viewport } from "next";
import "./globals.css";

function siteUrl(): URL {
  const raw = process.env.NEXT_PUBLIC_SITE_URL?.trim();
  const candidate =
    raw && raw.length > 0 ? raw : "https://elevra.app";
  // Tolerate values entered without a protocol (e.g. "elevra.app")
  // — `new URL` would otherwise throw at build time and fail metadata gen.
  const withProtocol = /^https?:\/\//i.test(candidate)
    ? candidate
    : `https://${candidate}`;
  try {
    return new URL(withProtocol);
  } catch {
    return new URL("https://elevra.app");
  }
}

const SITE_URL = siteUrl();

export const metadata: Metadata = {
  metadataBase: SITE_URL,
  title: {
    default: "Elevra — The interview, elevated.",
    template: "%s · Elevra",
  },
  description:
    "Practice mock interviews with an AI coach. Get scored answers, targeted feedback, and rewritten responses that win interviews.",
  applicationName: "Elevra",
  authors: [{ name: "Elevra" }],
  keywords: [
    "mock interview",
    "AI interview coach",
    "interview practice",
    "behavioral interview",
    "technical interview",
    "career preparation",
    "Elevra",
  ],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    siteName: "Elevra",
    title: "Elevra — The interview, elevated.",
    description:
      "Practice mock interviews with an AI coach. Get scored answers, targeted feedback, and rewritten responses that win interviews.",
    url: SITE_URL.toString(),
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Elevra — The interview, elevated.",
    description:
      "Practice mock interviews with an AI coach. Get scored answers, targeted feedback, and rewritten responses that win interviews.",
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
