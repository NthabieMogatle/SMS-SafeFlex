import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";
import SetupForm from "./SetupForm";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Set up your interview",
  description:
    "Tell us your target role, industry, and experience so we can tailor your interview.",
};

export default async function SetupPage({
  searchParams,
}: {
  searchParams: { new?: string };
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  // When the user reached /setup via ?new=1 (the "Start new interview"
  // entry point), render the form empty so the user actively picks the
  // target role / industry / experience for THIS new session — instead
  // of pre-filling with whatever was stored from their first signup.
  // Without this branch, returning users were silently locked into
  // their original role.
  const isNewSession = searchParams.new === "1";

  const { data: profile } = isNewSession
    ? { data: null as null }
    : await supabase
        .from("profiles")
        .select("target_role, industry, experience_level")
        .eq("user_id", user.id)
        .maybeSingle();

  return (
    <>
      <Nav />
      <SetupForm initial={profile} forceNew={isNewSession} />
    </>
  );
}
