import type { Metadata } from "next";
import Link from "next/link";
import RedeemFlow from "./RedeemFlow";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Redeem your lifetime code",
  description:
    "Redeem your AppSumo lifetime code and unlock unlimited Elevra interviews.",
};

const CODE_PATTERN = /^[A-Z0-9-]{4,64}$/;

export default function RedeemPage({
  searchParams,
}: {
  searchParams: { code?: string | string[] };
}) {
  const raw = Array.isArray(searchParams.code)
    ? searchParams.code[0]
    : searchParams.code;
  const code = (raw ?? "").trim().toUpperCase();
  const valid = code.length > 0 && CODE_PATTERN.test(code);

  if (!valid) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
        <h1 className="mb-2 text-2xl font-semibold">
          Redemption link is missing or invalid
        </h1>
        <p className="mb-6 text-sm text-foreground/70">
          This redemption link doesn&apos;t have a valid code. If you bought
          on AppSumo, return there and click <strong>Redeem</strong> again so
          we get your code. Or paste the code manually on your account page.
        </p>
        <div className="flex flex-wrap gap-3">
          <Link
            href="/account"
            className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
          >
            Paste code manually
          </Link>
          <a
            href="mailto:hello@elevra.app"
            className="rounded-md border border-foreground/20 px-4 py-2 text-sm font-medium hover:bg-foreground/5"
          >
            Contact support
          </a>
        </div>
      </main>
    );
  }

  return <RedeemFlow code={code} />;
}
