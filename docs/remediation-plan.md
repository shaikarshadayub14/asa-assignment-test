# Remediation Plan — Deferred Findings

This covers every finding from `docs/findings.md` marked "not fixed." For each: what remains exposed, how much work fixing it would take, and what already reduces the risk in the meantime. Findings already fixed in this submission (SQL injection, JWT `alg=none`, hardcoded secrets, plaintext password logging, weak share-token PRNG) are not repeated here.

## Critical

### #3 — Broken access control on `GET /scans/{scan_id}` (IDOR)

- **Residual risk:** Any authenticated user can read any other user's scan record — title, description, CVE ID, affected component, and remediation notes — by incrementing an integer ID. This was deliberately left unfixed for this submission to keep the change under review small and auditable (the three required fixes plus the Task 1 PRNG fix already meet the "at least 3, one in Task 1" bar); it is not a statement that this is acceptable in production.
- **Remediation effort:** Trivial — under 30 minutes. Add the same `filter(models.ScanResult.owner_id == current_user.id)` clause already used in `list_scans`, `update_scan`, and `delete_scan` in `app/main.py`, and add a regression test asserting a second user gets a 404 rather than another user's data.
- **Compensating controls:** None in place today beyond the fact that the endpoint requires a valid bearer token — it does not stop enumeration once a session exists. This should be treated as the single highest-priority fix in any follow-up.

## High

### #7 — Unauthenticated webhook registration and dispatch in `notify/` (SSRF / open relay)

- **Residual risk:** Anyone who can reach `notify/` on the network can register an arbitrary URL and cause it to receive attacker-triggered POST requests, or use it to probe/attack internal-only hosts (including cloud metadata endpoints) that the notify service can reach but an external attacker cannot reach directly.
- **Remediation effort:** Medium. The README explicitly states `notify/` requires "no changes required" for this assignment, so it was left untouched. A real fix requires: (a) authenticating `POST /webhooks` and `POST /notify` (e.g. a shared service token between the two services — `config.SERVICE_KEY` already exists but is only used outbound, never checked inbound), and (b) validating registered URLs against an allowlist or blocking RFC1918/link-local ranges to close the SSRF angle. Roughly half a day including tests.
- **Compensating controls:** The service is designed to sit on an internal network only, callable by the Python API — not intended to be internet-facing. The Terraform network policy in `terraform/network_policy.tf` restricts *ingress to the API pod*, but does not currently cover a `notify` deployment (it isn't deployed by this Terraform at all — see Task 4 scope note below). Until network isolation is formalized, this is the most significant residual risk in the whole system.

### #8 — Remaining HIGH-severity CVEs in `cryptography`, `starlette`, `python-multipart`

- **Residual risk:** These libraries sit on the request-parsing path. The specific advisories (see `reports/sca.pip-audit.json`) are denial-of-service and edge-case parsing issues rather than remote code execution, but a DoS against a vulnerability-tracking API delays remediation of everything else it's tracking.
- **Remediation effort:** Low, but time-gated rather than skill-gated — `pip-audit` was re-run after bumping these three packages plus `fastapi`, `python-multipart`, and `pytest`, and vulnerability count dropped from 33 across 7 packages to 28 across 6 (see `reports/sca.pip-audit.json`). The remaining findings are on versions that are already the latest available release for this dependency tree; there is no newer pin to move to yet without breaking compatibility with `python-jose`/`fastapi`. This needs to be revisited on a schedule (e.g. monthly `pip-audit` in CI), not fixed once.
- **Compensating controls:** The app already runs behind Uvicorn with sane defaults and no direct internet exposure is assumed for the raw container (Task 4's Terraform fronts it with a `NetworkPolicy`). Recommend adding a scheduled dependency-audit CI job (the `ci.yml` already has TODO placeholders for exactly this) rather than treating this as a one-time task.

### #9 — Kubernetes deployment uses `:latest` tag instead of a pinned digest

- **Residual risk:** No reproducibility guarantee between what was scanned/reviewed and what actually runs. A tag can be overwritten (accidentally or maliciously) after review without the deployment manifest changing at all.
- **Remediation effort:** Low — the CI pipeline already tags and pushes both `:latest` and `:${{ github.sha }}` (see `.github/workflows/ci.yml`). Switching `terraform/terraform.tfvars.example`'s `image` variable to reference the digest (`arshadayubshaik/vulntracker-api@sha256:...`) captured from the CI push step is a same-day change; it was left as `:latest` here because the digest changes on every push and pinning it in a static example file would go stale immediately without a CI step to inject it.
- **Compensating controls:** The CI job already produces an immutable `:${{ github.sha }}` tag alongside `:latest`, so a reproducible reference exists today — it's just not wired into the Terraform variable yet.

### #10 — Container base image OS-package CVEs (Debian/`perl-base`, `libssl3`, `libgnutls30`, `libexpat1`, etc.)

- **Residual risk:** 12 CRITICAL and 77 HIGH findings from Trivy, the large majority in Debian packages the application never directly invokes (`perl-base` is pulled in transitively by `apt`, not used by the Python app). Several have no vendor fix at all yet.
- **Remediation effort:** Low effort, ongoing cadence. Rebuilding against a newer `python:3.11-slim-bookworm` point release or moving to a distroless/Alpine-based image would shrink this list, but it will never reach zero — OS CVEs get published faster than they get patched. This is a "re-scan on every build" problem, not a one-time fix.
- **Compensating controls:** The Dockerfile already runs as a non-root user with a minimal package footprint (no build tools, no extra shells beyond what the base image ships), and the Terraform's container `security_context` drops all Linux capabilities and disallows privilege escalation — both reduce what a compromised container can actually do even if one of these library CVEs were exploited.

## Medium

### #11 — CORS policy reflects any Origin with credentials allowed

- **Residual risk:** Effectively equivalent to `Access-Control-Allow-Origin: *` combined with credentialed requests, which browsers otherwise disallow as a combination — the middleware works around that by echoing the specific `Origin` header value back rather than sending a literal `*`.
- **Remediation effort:** Low — replace the origin-reflection logic in `main.py`'s `cors_middleware` with FastAPI's built-in `CORSMiddleware` and an explicit `allow_origins` list of known frontends. Under an hour, but requires knowing the real list of origins that need access, which wasn't specified for this prototype.
- **Compensating controls:** Auth is Bearer-token-based (`Authorization` header), not cookie-based, so a malicious page can't silently ride an existing session the way it could with cookie auth — the attacker would still need to have already obtained the token via some other means.

### #12 — Unhandled exceptions leak stack traces to the client

- **Residual risk:** Any unexpected error (bad input that slips past validation, a downstream DB error, etc.) returns the full Python traceback and file paths in the HTTP response body.
- **Remediation effort:** Trivial, under 30 minutes — log the full traceback server-side (already logged via `logger.error`) but return a generic `{"error": "Internal server error"}` to the client, gated on whether the app is running in a debug/dev mode.
- **Compensating controls:** None currently; this is an easy, low-risk fix that simply wasn't in the 3-fix scope for this submission.

### #13 — No rate limiting on password-protected share links

- **Residual risk:** `GET /share/{token}` checks a password with no throttling or lockout, so an attacker who already has a valid token (e.g. one that leaked via a forwarded email) could brute-force the password offline-speed-limited only by bcrypt's cost factor.
- **Remediation effort:** Medium — needs either an in-memory/Redis rate limiter keyed by token+IP, or a maximum-attempts counter stored alongside the `SharedLink` row. A few hours including tests.
- **Compensating controls:** Tokens are generated with `secrets.token_urlsafe(32)` (256 bits of entropy) and links expire after 24 hours, which together make guessing the *token* itself infeasible — this finding only matters if the token has already leaked through some other channel, narrowing the actual attack surface considerably.

### #14 — Kubernetes secrets delivered as environment variables, not mounted files

- **Residual risk:** Env vars are more exposed than mounted secret files to process-listing leaks, crash dumps, or accidental inheritance by child processes.
- **Remediation effort:** Medium — the app currently reads all config via `os.environ` in `config.py`. Switching to file-based secrets means either changing the app to read from `/run/secrets/...` files, or using a sidecar/init pattern to materialize env vars from mounted files at container start. Non-trivial because it touches the app's config-loading code, not just the Terraform.
- **Compensating controls:** The Kubernetes Secret itself is still sourced from AWS Secrets Manager rather than hardcoded (satisfying the Task 4 requirement), and the pod's `automount_service_account_token = false` plus dropped Linux capabilities reduce what a process that did dump its own environment could do with the access.

## Low / accepted

### #17 — `read_only_root_filesystem` not enabled

Accepted, not deferred — see the code comment in `terraform/deployment.tf`. The app's SQLite fallback needs a writable `/app`. Revisit only if `DATABASE_URL` is pointed at a real external database in production, at which point this becomes a same-day change.

### #18 — `libsqlite3-0` and `zlib1g` CRITICAL CVEs with no vendor fix

No action available today. Tracked for re-scan on every image rebuild; will resolve itself once Debian ships a patched package, not through anything this team can do directly.

## Scope note on `notify/`

Several findings above (#7, #15) live in `notify/`, which the assignment README states requires "no changes required." They are documented here for completeness and honesty about residual risk, not because they were expected to be fixed as part of this submission.
