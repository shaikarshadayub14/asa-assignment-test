# Executive Summary — VulnTracker Security Review

## Where we started, and where we are now

VulnTracker holds a company's list of unpatched security weaknesses — arguably the most sensitive inventory a security team keeps, since it's a roadmap for anyone who wants to break in. Before this review, the application had several ways for one logged-in user to read or tamper with another user's data, a way for an attacker to forge a login session without knowing any password at all, and hardcoded credentials sitting in the source code where anyone with repository access could read them. All of that has now been fixed, including a cross-tenant data-access gap found during this review's own manual pass. What remains is a smaller, well-understood list of lower-severity gaps, tracked below with a plan to close each one, plus the infrastructure and container-scanning changes needed to run this safely going forward.

## Top residual risks

1. **The internal notification service accepts instructions from anyone who can reach it, with no login required.** It's designed to only be reachable from inside our own network, not the internet — but if that boundary is ever misconfigured, an outside party could use it to reach systems it shouldn't be able to reach, or to flood a third party with traffic that looks like it's coming from us. This service was explicitly out of scope for code changes in this round; closing it requires adding authentication between our two internal services, roughly half a day of work.
2. **The software the application depends on — and the operating system layer underneath the container it runs in — carries a number of publicly known weaknesses**, some of which don't have a vendor-supplied fix yet. None of these are currently reachable by an outside attacker without another vulnerability first, but they widen what an attacker could do if one ever got in. This isn't a single fix — it's an ongoing discipline of re-scanning and re-patching on a schedule, which is now technically straightforward to add to our existing automated build process but hasn't been switched on yet.

## Recommended next steps

- **Turn on scheduled, automated scanning** of our code, dependencies, container images, and infrastructure configuration as a permanent part of how we build and ship this service, rather than a one-time exercise — the tooling to do this already exists in our build pipeline and just needs to run on a recurring schedule instead of ad hoc.
- **Authenticate the internal notification service** before this product handles a customer's real vulnerability data in production; this was intentionally deferred to keep this round's changes reviewable, not because it's low priority.
- **Revisit this list quarterly.** Security posture isn't a project with an end date — new weaknesses in third-party software are published continuously, and the right response is a standing process, not a one-time cleanup.
