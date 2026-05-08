export default function DashboardLoading() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-10">
      <div className="mb-8 flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="h-7 w-40 animate-pulse rounded bg-foreground/10" />
          <div className="mt-2 h-4 w-32 animate-pulse rounded bg-foreground/10" />
        </div>
        <div className="h-9 w-44 animate-pulse rounded-md bg-foreground/10" />
      </div>

      <section className="mb-8 grid grid-cols-3 gap-3">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="h-20 animate-pulse rounded-md border border-foreground/10 bg-foreground/5"
          />
        ))}
      </section>

      <div className="mb-8 h-20 animate-pulse rounded-md border border-foreground/10 bg-foreground/5" />
      <div className="mb-8 h-36 animate-pulse rounded-md border border-foreground/10 bg-foreground/5" />

      <div className="space-y-2">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="h-16 animate-pulse rounded-md border border-foreground/10 bg-foreground/5"
          />
        ))}
      </div>
    </main>
  );
}
