export default function FeedbackLoading() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-12">
      <div className="mb-2 h-8 w-44 animate-pulse rounded bg-foreground/10" />
      <div className="mb-6 h-4 w-56 animate-pulse rounded bg-foreground/10" />
      <div className="mb-8 h-32 animate-pulse rounded-md border border-foreground/10 bg-foreground/5" />
      <div className="space-y-6">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="h-48 animate-pulse rounded-md border border-foreground/10 bg-foreground/5"
          />
        ))}
      </div>
    </main>
  );
}
