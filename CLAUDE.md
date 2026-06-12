# CLAUDE.md

Operating rules for Claude in this repository. The **source of truth for project
conventions is `.cursor/rules/`**. This file mirrors them for Claude; the linked
`.mdc` files are authoritative.

## Project at a glance

- Small Rails engine: password-reset flow (request → single-use token, 1 h expiry → reset) with email + SMS delivery and host hook points (`user_may_receive_sms_credentials?`, …)
- `app/` (mailers, models, controllers, views) + `config/locales` + `CHANGELOG.md`
- **No test suite** — verify in a host app; security properties (single-use, expiry, preview-safe landing) must be preserved
- Branch: `master` (`dev`, `phone-numbers` are feature branches)

## Always-applied rules (summary + link)

- **[base](.cursor/rules/base.mdc)** — Hook names/routes/views are public API; preserve token security properties; CHANGELOG with every version bump; verify in a host app.
- **[gemspec-version](.cursor/rules/gemspec-version.mdc)** — Bump `s.version` (`0.1.X`) + `s.date` on every code commit; matching `CHANGELOG.md` entry; docs/rules-only commits exempt.
- **[commit-messages](.cursor/rules/commit-messages.mdc)** — Imperative subject; security rationale in the body when relevant; trailer `Made-with: Claude`; no `Co-authored-by:`.
- **[english-code-and-docs](.cursor/rules/english-code-and-docs.mdc)** — English code/docs; locale languages kept in sync.

## Commit checklist

- Gemspec version + date bumped, CHANGELOG entry added (code commits).
- Token security properties unchanged or change explicitly justified.
- State how the change was verified.
- Trailer: `Made-with: Claude`.

## Persisting conventions

When the user corrects style/process/tooling, or you discover a non-obvious
convention worth keeping, add or extend a `.cursor/rules/*.mdc` file in the same
task. This file stays a thin index.
