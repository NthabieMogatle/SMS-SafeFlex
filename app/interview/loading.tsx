export default function InterviewLoading() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center px-6 py-12">
      <div className="flex items-center gap-3 text-foreground/70">
        <span className="h-3 w-3 animate-pulse rounded-full bg-emerald-500" />
        <p className="text-sm">Loading…</p>
      </div>
    </main>
  );
}
