<div align="center">

# 🛡 Bastion

**Local web vulnerability scanner — passive & active, with AI-driven hunting.**
Native binary · zero dependencies · Linux & Windows.

</div>

---

## ⚠️ Authorized use only — read first

Bastion is an **offensive security tool**. It sends real attack payloads
(XSS, SQLi, command injection, LFI, brute-force, …) and can confirm
exploitation.

> **Use Bastion ONLY against systems you own or for which you have explicit,
> written permission to test.** Unauthorized use is illegal in most
> jurisdictions and is **your sole responsibility**. See [LICENSE](LICENSE).

On first launch you must accept these terms. By installing or using Bastion you
agree to the [license](LICENSE).

### 🎯 Engagements (authorized perimeter)

To keep a scan inside its authorized boundary, define an **engagement**: a named
scope (one or more host patterns) plus optional notes. Create it in
**Settings → Engagements** and pick it in any scan/hunt/brute launcher. While an
engagement is selected, Bastion **refuses every request to a host outside the
scope** — off-site redirects and external links are blocked before they leave
your machine, and the report records how many out-of-scope requests were stopped.

Scope patterns (one per line): `example.com`, `*.example.com`,
`example.com:8080`, `example.com/api` (`host[:port][/path-prefix]`). An empty
scope means no restriction.

---

## 🚀 Install (one line)

**Linux** (Kali / Debian / Ubuntu …)
```bash
curl -fsSL https://raw.githubusercontent.com/kritogmre/bastion/main/install.sh | bash
```

**Windows** (PowerShell)
```powershell
irm https://raw.githubusercontent.com/kritogmre/bastion/main/install.ps1 | iex
```

The installer:
1. downloads the latest release (a **native binary** — no Python, no pip, nothing
   else to install) and **verifies its SHA-256**;
2. installs to `~/.local/share/bastion` (Linux) / `%LOCALAPPDATA%\Bastion`
   (Windows) and adds the `bastion` / `bastion-serve` commands;
3. starts the local backend automatically at each session;
4. **force-installs the signed browser extension** (Brave / Chrome / Chromium) —
   it appears on its own after a full browser restart and updates automatically.

> **Uninstall:** run `bastion uninstall` (add `--purge` to also remove your
> config and AI key). It stops the backend, removes the browser policy, the
> launchers and the install directory. Equivalent low-level path:
> `~/.local/share/bastion/setup.sh --uninstall` (Linux) ·
> `& "$env:LOCALAPPDATA\Bastion\setup.ps1" -Uninstall` (Windows).

---

## 🧭 How it works

Bastion has two parts that talk over `127.0.0.1:8777`:

- a **local backend** (the scan engine, compiled native binary) — never exposed
  to the network;
- a **browser extension** (the UI) that targets the page you are on and drives
  the backend.

You can also drive it entirely from the **command line**.

---

## 🔍 What it detects

**Passive** (no payload sent):
- Security headers (HSTS, **deep CSP analysis**, X-Frame-Options, nosniff,
  Referrer-Policy, Permissions-Policy)
- TLS / certificate (weak protocol, expiry, untrusted cert, plain HTTP)
- Cookies & sessions (Secure / HttpOnly / SameSite)
- Vulnerable JS libraries → known CVEs (jQuery, Bootstrap, Angular, lodash…)
- Exposed secrets (AWS/Google/Stripe/GitHub keys, private keys, JWTs, sensitive
  comments) — **reveal on demand**
- CORS, CSRF, HTTP methods, JWT weaknesses, missing SRI / mixed content
- **Recon**: DNS records, subdomains, zone transfer, SPF/DMARC, robots/sitemap,
  Swagger/OpenAPI/GraphQL, JS source maps, `.well-known`, exposed files
- Code debrief: endpoints, hosts, cloud assets, emails, JWTs mined from JS/HTML
- **Deep code harvest**: downloads *every* same-origin script and **recovers the
  original source from source maps** (`//# sourceMappingURL` + inline maps), then
  **seeds the parameterised endpoints found in the code as attack targets** — so
  the active modules test what the front-end actually talks to, not just crawled
  links (on by default for the Full profile)
- **DOM-based XSS (static)**: analyses the JavaScript corpus for client-side
  source→sink flows (`location`/`document.URL`/`referrer`/`window.name`/
  `postMessage` → `innerHTML`/`eval`/`document.write`/…) that an HTTP-only scanner
  can't see — with one-hop taint tracking to keep false positives low

**Active** (sends payloads — authorized targets only):
- XSS (multi-context: html/img/attr/js/template/tag/body), SQLi (error /
  boolean-blind / time-based), command injection, LFI / path traversal, SSTI,
  open redirect, host-header injection, SSRF, NoSQLi, CRLF, XXE, file upload →
  RCE, IDOR, GraphQL introspection, directory fuzzing
- **Two-request confirmation**: candidate injections are re-checked (the signal
  must reproduce *and* be absent for a benign control value) to cut false
  positives while probing harder
- **Login brute-force** (default creds, missing rate-limit, password spraying,
  CSRF-token aware)
- **Exploitation phase**: confirmed injections are safely exploited read-only
  (dump DB version/user, `id`/`whoami`, `/etc/passwd`) to prove impact

**Profiles**: Fast · Full · **Stealth** (rotating UAs, spaced requests).
**WAF evasion**, **proxy pool / Tor** rotation, and **authenticated scans**
(your browser session) are available in Settings.

**Parallel engine**: scan modules *and* per-target probing inside a module run
concurrently, so many attack types fire at once. A single global request
semaphore caps the real network concurrency, so it stays fast without hammering
the target (Stealth stays sequential and quiet). DNS is cached process-wide.

---

## 🤖 AI hunt & analysis

- **AI hunt**: the AI maps the surface — including the **deep-harvested code and
  the endpoints recovered from source maps** — forms ranked hypotheses,
  auto-verifies the most promising ones, and returns a prioritized debrief.
- **AI + pentest combined**: enable *AI analysis* on the full pentest and the AI
  reviews the whole report automatically as soon as the scan finishes.
- **AI analysis**: explains findings and suggests fixes; multi-turn Q&A.

Powered by **Claude** by default, or any OpenAI-compatible API — including a
**100% local, free** model via [Ollama](https://ollama.com) (nothing leaves your
machine). Configure it at `http://127.0.0.1:8777/config` or from Settings. The
API key is stored **server-side only**, never in the browser.

---

## 💻 Command line

```bash
bastion https://your-target.example --active        # full active scan
bastion https://your-target.example --profile furtif # stealth
bastion serve                                        # start the local API
bastion --help                                       # all options
```

**Saving reports** — by default an HTML report is written to the current
directory. Choose where every report goes, and which formats:
```bash
bastion https://target --active --output-dir ~/reports   # all reports → that dir
bastion https://target --txt                              # also save the console (text) report
bastion https://target --json out.json --sarif out.sarif # JSON + SARIF (CI)
```
Set a **default report directory** once (used when `--output-dir` is omitted) at
`http://127.0.0.1:8777/config` or via the `report_dir` config key.

A deliberately vulnerable demo target is included for offline practice:
```bash
python3 ~/.local/share/bastion/examples/vulnerable_server.py   # then scan http://127.0.0.1:8000
```

---

## 🌍 Languages

The interface is available in **English, Français, Español, Deutsch, 中文,
日本語, Italiano**. It auto-detects your browser language and can be changed any
time in **Settings → Language**. Translations are bundled (offline, no external
service).

---

## 🔄 Updates

Bastion checks the latest GitHub release and offers an in-app **Update** button.
Updating re-runs the installer, which replaces the binary and restarts the
backend. You can also enable automatic updates in the backend config.

---

## 📈 Stats & privacy

Bastion does **not** phone home. It only contacts the targets **you** explicitly
scan. Install/usage numbers are available to the publisher via GitHub's own
release **download counts** — no telemetry, no tracking. An optional, **opt-in**
anonymous counter can be enabled in Settings (off by default).

---

## 📜 Legal & copyright

© 2026 kritogmre. All rights reserved. Bastion is **proprietary** software and is
**not open source** — see [LICENSE](LICENSE). Reverse-engineering,
redistribution, and resale are prohibited without written permission.

Bastion is provided **as is, without warranty**. The author declines all
liability for misuse. **You** are responsible for ensuring you have authorization
for every target you test.
