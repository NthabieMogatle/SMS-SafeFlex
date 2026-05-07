export default function FeedbackPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">Your feedback report</h1>
      <p className="mb-6 text-sm text-foreground/60">
        TODO: render per-question score, strengths, weaknesses, and a rewritten
        better answer (response from <code>/api/interview/feedback</code>).
      </p>
    </main>
  );
}
