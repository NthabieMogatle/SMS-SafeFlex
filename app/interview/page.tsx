import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";
import InterviewClient from "./InterviewClient";

export const dynamic = "force-dynamic";

export default async function InterviewPage({
  searchParams,
}: {
  searchParams: { fresh?: string };
}) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("target_role, industry, experience_level")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!profile) redirect("/setup");

  return (
    <>
      <Nav />
      <InterviewClient profile={profile} startFresh={searchParams.fresh === "1"} />
    </>
  );
}
