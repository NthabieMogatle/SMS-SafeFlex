import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

const RequestSchema = z.object({
  code: z.string().min(3).max(64),
});

export async function POST(req: Request) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const parsed = RequestSchema.safeParse(await req.json());
  if (!parsed.success) {
    return NextResponse.json(
      { error: "That doesn't look like a valid code." },
      { status: 400 },
    );
  }

  const { data: tier, error } = await supabase.rpc("redeem_code", {
    p_code: parsed.data.code,
  });

  if (error) {
    const msg =
      error.message?.toLowerCase().includes("invalid_or_used_code")
        ? "That code is invalid or has already been used."
        : "We couldn't redeem that code right now. Please try again.";
    return NextResponse.json({ error: msg }, { status: 400 });
  }

  return NextResponse.json({ tier });
}
