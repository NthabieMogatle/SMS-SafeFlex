import Link from "next/link";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 px-6 py-12 text-center">
      <h1 className="text-xl font-semibold">Page not found</h1>
      <p className="text-sm text-foreground/60">
        That page doesn&apos;t exist. It may have been moved or removed.
      </p>
      <Link
        href="/"
        className="rounded-md bg-foreground px-4 py-2 text-sm font-medium text-background hover:opacity-90"
      >
        Go home
      </Link>
    </main>
  );
}
