# Remote Control — driving a local Claude Code session from your phone or browser

This walkthrough explains how to use [Claude Code Remote
Control](https://docs.claude.com/en/docs/claude-code/remote-control) to keep
working on this repo from a different device — your phone on the couch, a
tablet, or a borrowed laptop — while the session keeps running on your dev
machine.

Remote Control opens a window into a local `claude` process. Your filesystem,
`.env.local`, MCP servers, and `supabase` CLI all stay on the dev machine.
Nothing in this codebase is uploaded; only the conversation traffic is
relayed through Anthropic's API over TLS.

## When to reach for it

- You're mid-task on a `/feedback` rewrite, need to step away from the
  keyboard, and want to keep iterating from your phone.
- You're testing the live `elevra.app` site on a real mobile device and
  want Claude to fix the bug you just spotted without walking back to your
  desk.
- You want to glance at progress on a long-running job (a Supabase
  migration, a `npm install`, a batch of Anthropic API calls) from the
  Claude app while doing something else.

For tasks that don't need your local environment — a quick code question,
a one-off script, a PR review — prefer [Claude Code on the
web](https://docs.claude.com/en/docs/claude-code/claude-code-on-the-web)
instead. It runs in the cloud and doesn't tie up your laptop.

## 1. Confirm your setup

1. Check the Claude Code version on your dev machine:
   ```bash
   claude --version
   ```
   Remote Control needs **v2.1.51 or later**. Upgrade with
   `npm i -g @anthropic-ai/claude-code` if you're behind.
2. Make sure you're signed in via `claude.ai`, not an API key:
   ```bash
   claude /status
   ```
   The output should show "Logged in via claude.ai". If it shows an API
   key, run `claude /logout` then `claude /login` and pick the claude.ai
   option. Unset `ANTHROPIC_API_KEY` first if it's exported in your shell
   profile — that variable is for the app's `ANTHROPIC_API_KEY` runtime
   secret, not for Claude Code itself, and its presence will force Claude
   Code into inference-only mode.
3. Trust the workspace once by running `claude` inside the repo and
   accepting the trust dialog. Remote Control won't start in an untrusted
   directory.

## 2. Start a remote session

From the repo root on your dev machine:

```bash
cd ~/code/ai-mock-interview-coach   # or wherever you cloned it
claude remote-control --name "Mock Interview Coach"
```

The terminal prints a session URL and waits in server mode. Press
**spacebar** to show a QR code — handy when you want to jump straight from
the dev machine to your phone.

If you're already in an interactive session and don't want to lose your
conversation history, run `/remote-control "Mock Interview Coach"` inside
that session instead. The history carries over.

## 3. Connect from another device

Pick whichever route is closest:

- **Phone**: scan the QR code with the camera. It opens the session in the
  Claude app (install [iOS](https://apps.apple.com/us/app/claude-by-anthropic/id6473753684)
  or [Android](https://play.google.com/store/apps/details?id=com.anthropic.claude)
  first). In the app, tap **Code** in the nav to see all your remote sessions.
- **Browser**: open the printed URL or go to
  [claude.ai/code](https://claude.ai/code) and find the session by name in
  the list. Remote Control sessions show a small computer icon with a
  green dot.
- **Both at once**: the conversation syncs across every connected client,
  so you can type a prompt on your phone and watch the answer stream into
  the browser tab on your tablet.

The session keeps the title `Mock Interview Coach` because we passed
`--name`. Without it, you'd get an auto-generated name like
`mbp-graceful-unicorn` based on your hostname.

## 4. Use it for the things this repo actually does

A few flows that work well with Remote Control on this codebase:

- **Iterating on prompts in `app/api/score-answer`**: the scoring rubric
  lives in code, so Claude needs filesystem access to edit it. Start a
  session before you walk away, then send "tighten the rubric for the
  'star pattern' bullet" from your phone after dinner.
- **Tailing Vercel logs**: ask Claude to run `vercel logs --follow` on
  your machine and summarize errors as they stream in. You see the
  summary on your phone without needing the Vercel CLI installed there.
- **Supabase migrations**: have Claude draft a new SQL file in
  `supabase/`, run `supabase db push` locally, and report back. Useful
  when you want to confirm a schema change applied cleanly before opening
  your laptop.
- **Voice answers on real hardware**: open the deployed site on your
  phone, try the Web Speech API flow on `/interview`, and dictate the
  bug into the same Claude session — "the speech recognition stops after
  20 seconds on iOS Safari, fix it." Claude already has the repo open.

## 5. Push notifications (optional)

Once Remote Control is active, Claude can ping your phone when a long
task finishes — handy for `npm run build` or a slow Anthropic batch.

1. Sign in to the Claude mobile app with the same account.
2. Allow notifications when iOS/Android prompts.
3. On the dev machine, run `/config` inside Claude Code and turn on
   **Push when Claude decides**.

You can also ask in a prompt: "notify me when the tests pass." Requires
Claude Code v2.1.110 or later.

## 6. Tear it down

- In the terminal, press `Ctrl+C` to stop the server.
- In an interactive session, run `/remote-control` again to disconnect
  the remote without killing the local session.
- If your laptop sleeps or loses Wi-Fi, the session reconnects
  automatically when the machine wakes up — but if the outage runs past
  ~10 minutes, the session times out and you'll need to start a new one.

## Gotchas specific to this repo

- **`.env.local` stays on your machine**, which is what you want — your
  `ANTHROPIC_API_KEY`, Supabase service-role key, and `ADMIN_SECRET`
  never travel to the phone. But it also means Remote Control is the
  only way to remotely run anything that needs those secrets. Cloud
  Claude Code can't.
- **`/admin/health?key=…` and `/admin/api-test?key=…`** depend on
  `ADMIN_SECRET`. Ask Claude to read it from `.env.local` and hit those
  endpoints with `curl` — don't try to type the secret into the phone.
- **Ultraplan disconnects Remote Control.** If you kick off an
  ultraplan session for a big refactor, the active phone connection
  drops. Finish the plan, then restart `claude remote-control`.
- **Local-only commands**: `/mcp`, `/plugin`, and `/resume` open
  pickers in the terminal and won't work from the phone. Everything
  else in this repo's day-to-day workflow (editing files, running
  scripts, reading logs) works fine remotely.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Remote Control requires a claude.ai subscription` | You're on an API key. `unset ANTHROPIC_API_KEY` in your shell, then `claude /login` with the claude.ai option. |
| `Remote Control requires a full-scope login token` | You authenticated with `claude setup-token`. Run `claude /login` for a normal browser login instead. |
| Session shows up but is greyed out in the app | Local process exited. Restart `claude remote-control` on your machine. |
| Works from browser but phone shows "Offline" | Open the Claude app once on the phone so it can refresh its push token, then reconnect. |
| `Remote credentials fetch failed` | Re-run with `claude remote-control --verbose` and check for proxy/firewall errors on port 443. |

For anything else, see the upstream docs at
[docs.claude.com/en/docs/claude-code/remote-control](https://docs.claude.com/en/docs/claude-code/remote-control).
