# Changelog

## v0.1.19 (2026-06-18)

### Fixes

- Fix `NameError` at class load: `private_class_method` listed `user_may_receive_sms_credentials?` before the method was defined, so the model failed to load (crashing boot under Rails eager-loading / `eager_load = true`, and on Ruby 3.3). Move the `private_class_method` call to right after the method definition.

---

## v0.1.18 (2026-04-15)

### Changes

- Add optional `user_may_receive_sms_credentials?` setting. Called from `new_for_sms` before sending SMS when the user has no email, so hosts can block SMS password-reset delivery for high-access accounts.

---

## v0.1.17 (2026-04-15)

### Breaking changes

#### Migration required — new `reset_valid_until` column

Run the bundled migration to add the expiry column to `user_password_resets`:

```
rails db:migrate
```

Migration: `db/migrate/20260415140000_add_reset_valid_until_to_user_password_resets.rb`

The column is required. Without it, `token_allowed` rejects every token (`reset_valid_until` reads as `nil`, which is treated as expired). Existing rows with a non-nil `reset_digest` will be invalidated — users who requested a reset before the migration must request a new one.

---

### Changes

- **Reset token now expires after 1 hour.** `token_allowed` rejects tokens whose `reset_valid_until` has passed or is `nil`. The TTL is set when the token is created (`RESET_TOKEN_TTL = 1.hour`). The reset email now states the validity period, computed from the constant.

---

## v0.1.16 (2026-04-15)

### Changes

- Callers that already have a `User` object can now pass it directly to the
  reset request flow, avoiding a redundant lookup. Removes `find_by_email`,
  `find_by_phone`, `find_user_for_reset_request`, and `new_for_email`; use
  the unified `user:` keyword instead.

---

## v0.1.15 (2026-04-15)

### Notable behavior changes

- **Link-preview-safe landing page.** The email/SMS link (`GET
  email_link_for_typed_token_for_password_reset`) now renders a static
  confirmation page without validating the token. Only the user-initiated `POST
  typed_token_for_password_reset` validates and consumes it. This prevents
  link-preview bots from consuming tokens.

- **Reset token is single-use.** The POST to `typed_token` calls
  `consume_reset_token!` immediately after a successful check, nullifying
  `reset_digest`. Subsequent attempts with the same link fail.

---

## v0.1.14 (2026-04-14)

### Changes

- A readonly username field is shown on the new-password form so that password
  managers associate the username with the new password.
- New optional settings hook `username_for_autocomplete` — see v0.1.13 hooks
  table below.

---

## v0.1.13 (2026-04-14)

### Breaking changes

#### Migration required — new `submit_digest` / `submit_valid_until` columns

Run the bundled migration to add two columns to `user_password_resets`:

```
rails db:migrate
```

Migration: `db/migrate/20260414130000_add_submit_token_to_user_password_resets.rb`

The new columns back the submit token (see below). The app will raise
`ActiveRecord::StatementInvalid` if the migration has not been run.

---

#### `deliver_now` → `deliver_later` for password reset emails

`User::PasswordReset.new_for_email` now calls `deliver_later` instead of
`deliver_now`.

**Impact:** The mailer job must be processable by your Active Job backend. In
test environments, set `config.active_job.queue_adapter = :test` (or
`:inline`) if you rely on synchronous delivery assertions.

---

### Breaking changes — only if you have custom view overrides

> The built-in views are updated automatically. The items below only apply if
> your host app overrides any of the gem's views.

#### New mandatory hidden field: `submit_token` in `new_password` view

`typed_token` (POST) now mints a short-lived BCrypt submit token (15 min TTL)
and assigns it to `@submit_token`. `typed_new_password_for_password_reset`
validates it before updating the password.

A custom `new_password` view must include:

```erb
<%= hidden_field_tag :submit_token, @submit_token %>
```

If the field is missing or the token has expired, the password update is refused
and `@submit_token_expired` is set to `true` on the re-rendered view.

#### `generate_token` form field renamed: `email` → `contact`

The `new` view's form previously submitted `params[:email]`. It now submits
`params[:contact]`, matched against username, email, and phone (unique match
required). A custom `new` view that uses `name="email"` must be updated to
`name="contact"`. The `email:` / `phone:` keyword arguments on
`User::PasswordReset.request_reset` are preserved for programmatic use.

#### User identified by `id` in follow-up steps, not re-submitted contact

Follow-up steps previously accepted `params[:email]` or `params[:id]` to
resolve the user. They now exclusively use `params[:id]` via
`User::PasswordReset.user_for_identifier`. Custom views that re-submit `email`
to later steps will stop resolving the user — pass the hidden `id` field instead
(`generate_token` sets `@password_reset_user_id` for this purpose).

---

### New settings hooks (opt-in)

| Key | Signature | Purpose |
|-----|-----------|---------|
| `on_reset_requested` | `->(user) {}` | Called after reset instructions are sent (e.g. invalidate first-login tokens). |
| `scope_users_for_password_reset` | `->(relation) { relation.where(...) }` | Restrict which users participate in lookup and delivery (e.g. exclude disabled accounts). |
| `user_may_request_password_reset?` | `->(user) { true/false }` | Per-user gate after the user is found; return `false` to silently refuse. |
| `username_for_autocomplete` | `->(user) { string }` | Display name shown in the readonly username field on the new-password form. |
| `log_password_setting_event` | `->(user:, kind:, actor:, channel:) {}` | Receives `password_reset_instructions_sent` and `password_reset_completed` events. |

---

## v0.1.12 (2025-05-29)

### Breaking changes

#### SMS sending moved from hardcoded `Sms` constant to a settings hook

Previously the gem called `Sms.send(...)` directly, requiring a top-level `Sms`
class in the host app. This is now configured via a settings hook instead:

```ruby
UserPasswordResetSystem.settings[:send_sms] = ->(to:, message:) { Sms.send(to: to, message: message) }
```

Host apps that relied on the `Sms` constant being called automatically must add
this hook; without it, no SMS is sent.

---

## v0.1.11 (2025-02-08)

### Bug fixes

- Fixed a nil error on boot caused by `settings` not being initialized to an
  empty hash before `setup` blocks ran.

---

## v0.1.10 (2021-07-17, patch 2024-10-09)

### Changes

- Added `hide_username` settings flag to hide the username field on the
  new-password form (useful when the host app does not use usernames).
- Fixed a mailer `ArgumentError` on Rails 6.1.7.8 caused by double-splat
  argument passing; the mailer now uses `params` instead.

---

## v0.1.09 (2021-04-29)

### Bug fixes

- Fixed leftover references that caused errors after the cancellation feature
  was removed in v0.1.07.

---

## v0.1.08 (2021-04-11)

### Changes

- Added English locale file (`config/locales/en.yml`). Previously only Finnish
  was bundled.

---

## v0.1.07 (2021-04-11)

### Changes

- Removed the token cancellation action and its associated route and mailer
  template.
- Controller actions now call `skip_authorization` so the gem works with
  Pundit-based host apps out of the box.

---

## v0.1.06 (2021-04-11)

### Bug fixes

- Fixed a deprecated method call in the password reset email template.

---

## v0.1.05 (2021-04-01)

### Changes

- Rails 6.1 compatibility: removed engine initializer pattern that was
  incompatible with the new zeitwerk autoloader.

---

## v0.1.04 (2020-09-10)

### Changes

- Introduced the `UserPasswordResetSystem.setup` configuration block and the
  `settings` hash — the foundation for all host-app hooks.
- Added `run_after_password_reset_success` settings hook: when set, the
  controller calls `after_password_reset_success(user)` instead of redirecting
  to `root_path`, letting the host app control post-reset navigation.
- Hardened the `typed_token` and `typed_new_password_for_password_reset` actions
  against nil users and missing query parameters.
- The flash notice after submitting an email address is now immediately discarded
  so it does not persist to the next page.

---

## v0.1.02 (2019-12-05)

Initial release. Provides the `user_password_resets` table, the email-based
password reset flow (request → type token → set new password), and a Finnish
locale.
