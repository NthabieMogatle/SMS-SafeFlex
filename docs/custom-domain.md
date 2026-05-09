# Custom domain setup — elevra.app

This walkthrough assumes the domain `elevra.app` was bought directly through
Vercel (their built-in registrar). When you buy through Vercel the DNS is
auto-configured and SSL is provisioned automatically — most of the work
happens for you.

If you ever need to switch to a domain bought elsewhere (Cloudflare,
Namecheap, Porkbun), the manual DNS steps are at the end.

## 1. Attach `elevra.app` to your Vercel project

1. Open the Vercel dashboard → **elevra** project → **Settings** → **Domains**.
2. If `elevra.app` already appears in the list (because you bought it
   through Vercel), click **Add to project** next to it.
3. If it doesn't appear, type `elevra.app` into the input and click **Add**.
4. Vercel will provision the SSL certificate automatically. The status
   moves from **Configuring** → **Valid Configuration** in 30–90 seconds.

## 2. Also add `www.elevra.app` and redirect it

1. In the same **Domains** screen, click **Add Domain** again.
2. Type `www.elevra.app` and click **Add**.
3. Vercel will detect both an apex and a www variant and ask which is the
   "primary" — choose **`elevra.app`** as primary.
4. Vercel automatically sets up a 308 redirect from `www.elevra.app` to
   `elevra.app`. No DNS work required.

## 3. Verify SSL / HTTPS

1. Wait until both domains show **Valid Configuration** with a green check.
2. Open `https://elevra.app` in a fresh browser tab.
3. Tap the lock icon in the address bar — you should see "Connection is
   secure" and a valid Let's Encrypt certificate. The browser shows the
   green padlock.
4. Try `https://www.elevra.app` too — it should immediately redirect to
   the apex.

If the cert is still pending, give it 5 more minutes and retry. SSL via
Let's Encrypt almost always finishes within 1–2 minutes when DNS is
already correct (which it is for Vercel-purchased domains).

## 4. Set elevra.app as Production Domain

This makes Vercel route the latest production deployment to `elevra.app`
and 301-redirect the old `*.vercel.app` URLs to the custom domain.

1. **Settings** → **Domains** → click **⋯** next to `elevra.app` → **Set
   as Production Domain**.
2. Confirm.

## 5. Update Supabase Auth URLs (don't skip)

Supabase rejects auth redirects to URLs that aren't in its allowlist.
Without this step, the magic-link confirmation email will fail when users
click the link from `elevra.app`.

1. Open the Supabase dashboard → your project → **Authentication** →
   **URL Configuration**.
2. Set **Site URL** to: `https://elevra.app`
3. In **Redirect URLs**, add (one per line):
   - `https://elevra.app/**`
   - `https://www.elevra.app/**`
   - Keep `https://career-os-alpha.vercel.app/**` and the auto-generated
     Vercel preview URLs in the list during the transition — they'll let
     existing in-flight emails still work.
4. Click **Save**.

## 6. Update environment variables in Vercel

1. Vercel → elevra project → **Settings** → **Environment Variables**.
2. Edit `NEXT_PUBLIC_SITE_URL` → set value to:
   ```
   https://elevra.app
   ```
   Make sure to include `https://`. The code tolerates either form, but a
   clean canonical URL is what shows up in OG previews and metadata.
3. Save. Then go to **Deployments** → ⋯ on the latest → **Redeploy**
   (uncheck cache) so the metadata picks up the new value.

## 7. Smoke test the live domain

Walk through the full flow once on `https://elevra.app`:

1. Open the homepage. Verify the Elevra wordmark in the nav, hero
   tagline ("The interview, elevated"), and pricing tier reading
   "Lifetime / One-time".
2. Sign up with a fresh test email. Click the confirmation link from
   your inbox — it should redirect to `elevra.app/setup`, not the old
   Vercel URL.
3. Fill in role / industry / experience, run an interview, submit.
4. Verify `/dashboard` and `/account` render correctly with the new
   branding.
5. In Safari/Chrome, view source on the homepage and check the
   `<meta property="og:image">` tag points at `elevra.app/opengraph-image`.
6. Share `https://elevra.app` to iMessage / WhatsApp / X / LinkedIn —
   the preview should show "Elevra — The interview, elevated." with
   the dark-navy + cyan OG image.

## 8. Optional polish

- **Lock down `*.vercel.app` URLs**: in Vercel → Settings → Domains, you
  can disable the auto-generated preview hostnames if you don't want them
  publicly accessible. The custom domain is enough for production.
- **Email branding**: paste `docs/supabase-email-confirm.html` into
  Supabase → Authentication → Email Templates → Confirm signup → Save.
- **DNS health**: Vercel's domain page shows DNS records — confirm A and
  AAAA records resolve from a tool like `dig elevra.app` or
  https://dnschecker.org.

---

## Appendix: domain bought outside Vercel

If you ever migrate to a domain from another registrar (Cloudflare,
Namecheap, Porkbun, etc.), set these DNS records at the registrar:

```
Type: A          Name: @     Value: 76.76.21.21
Type: CNAME      Name: www   Value: cname.vercel-dns.com
```

Vercel auto-detects when DNS resolves correctly and provisions SSL the
same way.
