import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import ApiTestClient from "./ApiTestClient";

export const dynamic = "force-dynamic";

export default async function ApiTestPage({
  searchParams,
}: {
  searchParams: { key?: string };
}) {
  const expected = process.env.ADMIN_SECRET;
  if (!expected || searchParams.key !== expected) {
    notFound();
  }

  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return <ApiTestClient signedIn={Boolean(user)} userEmail={user?.email ?? null} />;
}
