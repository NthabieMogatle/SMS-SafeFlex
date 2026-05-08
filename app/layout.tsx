import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL ?? "https://career-os-alpha.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
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
    url: SITE_URL,
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
