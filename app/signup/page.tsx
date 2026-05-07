export default function SignupPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <h1 className="mb-6 text-2xl font-semibold">Create your account</h1>
      <p className="text-sm text-foreground/60">
        TODO: wire this form to Supabase auth (email + password).
      </p>
      {/* TODO: form -> supabase.auth.signUp, then redirect to /setup */}
    </main>
  );
}
