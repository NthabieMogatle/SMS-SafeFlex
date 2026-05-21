import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "nodejs";

// The Gumroad product permalink that, together with seller_id, scopes
// which incoming pings this route accepts. Hardcoded because it's a
// public, stable, product-identifying value (not a secret).
const GUMROAD_PRODUCT_PERMALINK = "fftsf";

// Gumroad license-verification endpoint. Documented at
// https://app.gumroad.com/api#licenses-verify.
const GUMROAD_VERIFY_URL = "https://api.gumroad.com/v2/licenses/verify";

type GumroadVerifyResponse = {
  success: boolean;
  uses?: number;
  purchase?: {
    test?: boolean;
    refunded?: boolean;
    chargebacked?: boolean;
    disputed?: boolean;
    license_disabled?: boolean;
    email?: string;
    sale_id?: string;
    [k: string]: unknown;
  };
  message?: string;
};

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

async function verifyLicense(
  productId: string,
  licenseKey: string,
): Promise<GumroadVerifyResponse | null> {
  try {
    const body = new URLSearchParams({
      product_id: productId,
      license_key: licenseKey,
      increment_uses_count: "false",
    });
    const res = await fetch(GUMROAD_VERIFY_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      console.warn("[gumroad-webhook] verify HTTP", res.status, text);
      return null;
    }
    return (await res.json()) as GumroadVerifyResponse;
  } catch (e) {
    console.warn("[gumroad-webhook] verify threw", e);
    return null;
  }
}

// Unlike the AppSumo route — which returns 4xx/5xx on bad signature or
// state — this handler ALWAYS returns 200. Gumroad retries non-2xx
// responses aggressively, and we'd rather log a missing config than
// trigger a retry storm. The outer try/catch is the last line of
// defense for that invariant.
export async function POST(req: Request) {
  try {
    // STEP 1 — log the full payload before trusting any individual
    // field. Gumroad's exact field names have drifted across versions
    // and we want a recorded baseline before code paths gate on them.
    const rawBody = await req.text();
    const params = new URLSearchParams(rawBody);
    const fields: Record<string, string> = {};
    for (const [k, v] of params.entries()) fields[k] = v;
    console.log("[gumroad-webhook] received ping", {
      contentType: req.headers.get("content-type"),
      fieldKeys: Object.keys(fields),
      fields,
    });

    const sellerId = fields["seller_id"];
    const productPermalink = fields["product_permalink"];
    const licenseKey = (fields["license_key"] || "").trim();
    const isTest = fields["test"] === "true";

    // Refund detection. Gumroad's Resource Subscriptions ship a refund
    // ping with resource_name=refund; some setups also re-deliver the
    // original sale ping with refunded=true. Treat either as refund.
    // TODO Verify against a real refund test ping that the indicator
    // is actually one of these field names AND that license_key is
    // present on the refund payload. If Gumroad only sends sale_id on
    // refunds, we'd need to persist sale_id at mint time (new column
    // on redemption_codes) to enable lookup — flag at first refund.
    const isRefund =
      fields["resource_name"] === "refund" ||
      fields["refunded"] === "true";

    // STEP 2(a) — cheap gate: seller_id + product_permalink.
    const expectedSeller = process.env.GUMROAD_SELLER_ID;
    if (!expectedSeller) {
      console.warn(
        "[gumroad-webhook] GUMROAD_SELLER_ID not configured; ignoring ping",
      );
      return NextResponse.json({ ok: true, ignored: "unconfigured" });
    }
    if (sellerId !== expectedSeller) {
      console.warn("[gumroad-webhook] seller_id mismatch", {
        got: sellerId,
        expected: expectedSeller,
      });
      return NextResponse.json({ ok: true, ignored: "seller_mismatch" });
    }
    if (productPermalink !== GUMROAD_PRODUCT_PERMALINK) {
      console.warn("[gumroad-webhook] product_permalink mismatch", {
        got: productPermalink,
        expected: GUMROAD_PRODUCT_PERMALINK,
      });
      return NextResponse.json({ ok: true, ignored: "permalink_mismatch" });
    }

    // STEP 4 — refund branch. Mirrors the AppSumo refund logic:
    // downgrade the user that redeemed this code (if any) and delete
    // the row so it can't be re-redeemed.
    if (isRefund) {
      if (!licenseKey) {
        console.warn(
          "[gumroad-webhook] refund ping had no license_key; cannot identify code",
          { fields },
        );
        return NextResponse.json({
          ok: true,
          refund_unhandled: "missing_license_key",
        });
      }
      const code = licenseKey.toUpperCase();
      const supabase = admin();
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
      await supabase.from("redemption_codes").delete().eq("code", code);
      console.log("[gumroad-webhook] revoked", { code });
      return NextResponse.json({ ok: true, revoked: true });
    }

    // STEP 2(b) — strong gate: Gumroad license-verify API.
    if (!licenseKey) {
      console.warn("[gumroad-webhook] sale ping missing license_key", {
        fields,
      });
      return NextResponse.json({ ok: true, ignored: "no_license_key" });
    }
    const productId = process.env.GUMROAD_PRODUCT_ID;
    if (!productId) {
      console.warn(
        "[gumroad-webhook] GUMROAD_PRODUCT_ID not configured; cannot verify",
      );
      return NextResponse.json({ ok: true, ignored: "unconfigured" });
    }
    const verify = await verifyLicense(productId, licenseKey);
    if (!verify || verify.success !== true) {
      console.warn("[gumroad-webhook] license verify failed", { verify });
      return NextResponse.json({ ok: true, ignored: "verify_failed" });
    }
    if (
      verify.purchase?.refunded ||
      verify.purchase?.chargebacked ||
      verify.purchase?.disputed
    ) {
      console.warn(
        "[gumroad-webhook] verified license is refunded/chargebacked/disputed; not minting",
        { purchase: verify.purchase },
      );
      return NextResponse.json({ ok: true, ignored: "refunded_purchase" });
    }
    if (isTest || verify.purchase?.test === true) {
      console.log(
        "[gumroad-webhook] test purchase — skipping mint so it cannot pollute real lifetime grants",
        { licenseKey, purchase: verify.purchase },
      );
      return NextResponse.json({ ok: true, ignored: "test_purchase" });
    }

    // STEP 3 — mint the redemption code. Identical shape to the
    // AppSumo route: code = license_key uppercased, plan_tier =
    // lifetime, source = 'gumroad'. Duplicate inserts are no-ops
    // because Gumroad may re-deliver pings.
    const code = licenseKey.toUpperCase();
    const supabase = admin();
    const { error: insertError } = await supabase
      .from("redemption_codes")
      .insert({
        code,
        plan_tier: "lifetime",
        source: "gumroad",
      });
    if (
      insertError &&
      !insertError.message?.toLowerCase().includes("duplicate")
    ) {
      console.error(
        "[gumroad-webhook] failed to record license",
        insertError,
      );
      return NextResponse.json({ ok: true, error: "record_failed" });
    }
    console.log("[gumroad-webhook] minted", { code });
    return NextResponse.json({ ok: true, code });
  } catch (e) {
    // Last-resort guard. Never let an exception escape as a non-200.
    console.error("[gumroad-webhook] unhandled error", e);
    return NextResponse.json({ ok: true, error: "handler_threw" });
  }
}
