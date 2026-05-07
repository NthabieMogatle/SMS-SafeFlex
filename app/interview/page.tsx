export default function InterviewPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">Mock interview</h1>
      <p className="mb-6 text-sm text-foreground/60">
        TODO: fetch 5 questions from <code>/api/interview/questions</code>{" "}
        (Claude Sonnet), present one at a time, collect typed answers, then
        POST to <code>/api/interview/feedback</code> and route to{" "}
        <code>/feedback</code>.
      </p>
    </main>
  );
}
