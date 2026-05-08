import { NextResponse } from "next/server";
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";

// AppSumo webhook payload (subset — fields vary by event type).
// See: https://help.appsumo.com/article/1690-vendor-faq-licensing-api
type AppSumoPayload = {
  event?: string; // "purchase" | "upgrade" | "downgrade" | "refund"
  license_key?: string;
  prev_license_key?: string;
  activation_email?: string;
  email?: string;
  plan?: { name?: string; tier?: number };
  test?: boolean;
};

function verifySignature(rawBody: string, signature: string | null, secret: string) {
  if (!signature) return false;
  const expected = crypto
    .createHmac("sha256", secret)
    .update(rawBody)
    .digest("hex");
  try {
    const a = Buffer.from(expected, "utf8");
    const b = Buffer.from(signature, "utf8");
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

function generateCode(prefix = "APPSUMO"): string {
  const part = (n: number) =>
    crypto.randomBytes(n).toString("hex").toUpperCase().slice(0, n);
  return `${prefix}-${part(5)}-${part(5)}`;
}

function admin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error("Supabase service role not configured");
  }
  return createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function POST(req: Request) {
  const secret = process.env.APPSUMO_WEBHOOK_SECRET;
  if (!secret) {
    return NextResponse.json(
      { error: "Webhook not configured" },
      { status: 503 },
    );
  }

  const rawBody = await req.text();
  const signature =
    req.headers.get("x-appsumo-signature") ??
    req.headers.get("x-signature") ??
    null;
  const signatureOk = verifySignature(rawBody, signature, secret);

  let payload: AppSumoPayload = {};
  try {
    payload = JSON.parse(rawBody) as AppSumoPayload;
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  // Always log the event before deciding what to do, so we have an audit
  // trail even for malformed or unverified requests.
  let supabase;
  try {
    supabase = admin();
    await supabase.from("appsumo_webhook_events").insert({
      event_type: payload.event ?? "unknown",
      license_key: payload.license_key ?? null,
      email: payload.activation_email ?? payload.email ?? null,
      payload,
      signature_ok: signatureOk,
    });
  } catch (e) {
    return NextResponse.json(
      { error: "Internal logging error" },
      { status: 500 },
    );
  }

  if (!signatureOk) {
    return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
  }

  const event = payload.event ?? "";
  const licenseKey = payload.license_key?.trim();

  // For purchase / upgrade: mint a redemption code keyed to the license.
  // The code uses the license key itself when one is supplied so the user
  // can paste either the license or the code. This makes manual recovery
  // simple even if AppSumo's redirect to the redemption UI fails.
  if ((event === "purchase" || event === "upgrade") && licenseKey) {
    const code = licenseKey.toUpperCase();
    const { error: insertError } = await supabase
      .from("redemption_codes")
      .insert({
        code,
        plan_tier: "lifetime",
        source: `appsumo-webhook-${event}`,
      });

    // Ignore unique_violation — a duplicate webhook for the same license is
    // safe to no-op; the original code is still valid.
    if (insertError && !insertError.message?.toLowerCase().includes("duplicate")) {
      return NextResponse.json(
        { error: "Failed to record license" },
        { status: 500 },
      );
    }

    return NextResponse.json({ ok: true, code });
  }

  // Refund: revoke the lifetime tier from whoever redeemed this code.
  if (event === "refund" && licenseKey) {
    const code = licenseKey.toUpperCase();
    const { data: codeRow } = await supabase
      .from("redemption_codes")
      .select("redeemed_by")
      .eq("code", code)
      .maybeSingle();

    if (codeRow?.redeemed_by) {
      await supabase
        .from("profiles")
        .update({ plan_tier: "free" })
        .eq("user_id", codeRow.redeemed_by);
    }

    // Mark the code unusable by clearing redeemed_by would let it be
    // re-redeemed; instead, delete it entirely so it can never be used again.
    await supabase.from("redemption_codes").delete().eq("code", code);
    return NextResponse.json({ ok: true, revoked: true });
  }

  // Other events (downgrade, test pings) — acknowledge without action.
  return NextResponse.json({ ok: true, ignored: event });
}
