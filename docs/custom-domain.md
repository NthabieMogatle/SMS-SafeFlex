# Custom domain setup

Step-by-step to move Career OS from `career-os-alpha.vercel.app` to a custom
domain like `careeros.app` or `careerosapp.com`.

## 1. Buy the domain

Recommended registrars:

- **Cloudflare Registrar** — at-cost pricing, no upsells, fast
- **Namecheap** — friendly UI, lower-cost first-year, works fine
- **Porkbun** — at-cost, clean UI

Buying tips:

- Prefer `.app` or `.com`. Avoid country-code TLDs unless you're regional.
- Check the name on Twitter / X, LinkedIn, Instagram, and as a Gmail handle
  before buying — domain-only branding is fragile.
- Enable WHOIS privacy at checkout. Most registrars include it free.

## 2. Add the domain to Vercel

1. Open the Vercel dashboard → **career-os** project → **Settings** → **Domains**
2. Type your new domain (e.g. `careeros.app`) and click **Add**
3. Add the apex (`careeros.app`) AND the `www` subdomain together so both
   resolve. Vercel will redirect one to the other automatically.
4. Vercel will show you DNS records to add.

## 3. Set the DNS records at your registrar

You'll see one of two patterns depending on the registrar:

**Apex domain (e.g. `careeros.app`)**

```
Type: A
Name: @
Value: 76.76.21.21
```

**`www` subdomain**

```
Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

Some registrars (like Cloudflare) recommend "ALIAS" or "CNAME flattening"
on the apex — Vercel works with that too.

## 4. Wait for SSL

Vercel automatically provisions a Let's Encrypt SSL certificate within
~1–5 minutes after DNS resolves. Refresh the Domains page; it goes from
"Configuring" to "Valid Configuration" with a green check.

## 5. Update Supabase Auth redirect URLs

Critical step — Supabase will reject auth redirects to unknown URLs.

1. Open the Supabase dashboard → **Authentication** → **URL Configuration**
2. Set **Site URL** to your new custom domain (e.g. `https://careeros.app`)
3. Add it to **Redirect URLs** as well: `https://careeros.app/**`
4. Keep `https://career-os-alpha.vercel.app/**` in the list temporarily
   so existing magic-link emails still work during the transition.

## 6. Update environment variables

In Vercel → Settings → Environment Variables, edit:

```
NEXT_PUBLIC_SITE_URL = https://careeros.app
```

Make sure to include the `https://` prefix. Then redeploy:

- Deployments → ⋯ on latest → Redeploy → uncheck cache → Redeploy

## 7. Verify

Open `https://careeros.app/`. You should see the Career OS landing page.

Test the full flow once: sign up with a fresh test email, click the
confirmation link, get redirected to `careeros.app/setup`, complete an
interview. If the confirmation link redirects to the old domain, double-check
step 5.

## 8. Optional polish

- **301 redirect** from the old `career-os-alpha.vercel.app` to the new
  domain. Vercel does this automatically once you set the new domain as
  primary in Settings → Domains → ⋯ → Set as Production Domain.
- **Update OG image domain reference** if you have any hardcoded URLs in
  social previews (we don't — OG image is generated from `metadataBase`
  which reads `NEXT_PUBLIC_SITE_URL`).
- **Email templates** in Supabase still reference the old logo path? They
  shouldn't since the email template uses inline SVG. If you switch to a
  hosted image later, update the `<img src>` to point at the new domain.
- **AppSumo deal listing** — when you submit, use the custom domain in
  the listing URL.
