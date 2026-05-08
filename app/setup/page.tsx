import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import Nav from "@/components/Nav";
import SetupForm from "./SetupForm";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Set up your interview",
  description:
    "Tell Career OS your target role, industry, and experience so we can tailor your interview.",
};

export default async function SetupPage() {
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

  return (
    <>
      <Nav />
      <SetupForm initial={profile} />
    </>
  );
}
