export default function SetupPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">Tell us about your goal</h1>
      <p className="mb-6 text-sm text-foreground/60">
        We&apos;ll tailor your practice interview based on these.
      </p>
      <p className="text-sm text-foreground/60">
        TODO: collect target role, industry, experience level. Persist to a{" "}
        <code>profiles</code> table in Supabase, then redirect to{" "}
        <code>/interview</code>.
      </p>
    </main>
  );
}
