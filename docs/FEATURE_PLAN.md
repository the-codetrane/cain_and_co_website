# Cain & Co. Website — Feature Plan

A mobile-first, installable (PWA) Rails 8.1 site for the band. Fans browse shows, subscribe to a
monthly newsletter, and buy merch (guest checkout). The admin manages the email list, drafts the
newsletter with AI, and runs the store.

## Stack decisions (locked)

| Concern | Decision |
|---|---|
| Framework | Rails 8.1, Ruby 4.0.1, SQLite, Puma + Thruster |
| Jobs / cache / cable | Solid Queue / Solid Cache / Solid Cable (DB-backed, no Redis) |
| Frontend | Hotwire (Turbo + Stimulus), importmap-rails (no Node), Propshaft |
| CSS | TailwindCSS v4 via `tailwindcss-rails` (standalone CLI, no Node), mobile-first |
| Auth | Rails 8 built-in `authentication` generator — **admin-only, no public signup** |
| Fans | **No accounts** — email signup + guest checkout |
| Store | Stripe Checkout (hosted), **physical goods**, guest checkout, manual fulfillment |
| Email | Action Mailer over **Gmail SMTP**, provider-agnostic via ENV, throttled via Solid Queue |
| AI | Claude (Anthropic) — official `anthropic` Ruby gem, model `claude-opus-4-8` |
| Tour dates | **Bandsintown API** (`rest.bandsintown.com`) synced into local `Show` table via recurring job |
| PWA / push | Rails 8 PWA stubs + `web-push` gem (VAPID), Web Push notifications |
| Deploy | Kamal (already scaffolded) |

---

## Feature areas

> **Generators:** per the "use native generators where possible" requirement, all CRUD-heavy areas
> (Shows, Products/Variants, Orders admin, Subscribers admin) are built with
> `bin/rails generate scaffold` / `model` / `controller`, then restyled with Tailwind. Auth uses the
> built-in `authentication` generator. We only hand-write where no generator fits (Stripe webhook,
> AI service/job, push subscription flow).

### 1. Foundation + homepage
- TailwindCSS install (`bin/rails tailwindcss:install`), mobile-first layout shell, responsive nav,
  viewport meta. Tailwind watcher runs via Foreman (`bin/dev` is Procfile-based, multi-process).
- Public layout (fan-facing) vs `Admin::` namespaced layout.
- **Homepage / landing (`root` route):** band hero, intro/about blurb, music/streaming links
  (Spotify/Apple/Bandcamp), and entry points to shows, newsletter signup, and merch. This is the
  fan's front door — `root` is currently unset in `routes.rb`. Scope (hero + links vs. fuller
  about/music section) to confirm with the user.
- Health check `/up` already present.

### 2. Authentication (admin-only)
- `bin/rails generate authentication` → `User`, `Session`, `Current`, `Authentication` concern,
  sessions + passwords controllers, `PasswordsMailer`.
- **No signup controller** (the generator omits it by design — exactly what we want).
- Seed a single admin in `db/seeds.rb` from `ENV["ADMIN_PASSWORD"]`.
- **Access model — public-by-default with one admin chokepoint.** The generator's
  `require_authentication` is global/opt-out, but because this site is overwhelmingly public
  (account-free fans), `ApplicationController` calls `allow_unauthenticated_access` to make the whole
  site public, and `Admin::BaseController` re-adds `require_authentication`. Every admin controller
  inherits `Admin::BaseController`, so there is a single place to audit instead of an opt-out on every
  public controller. (Sign-out also requires auth so `Current.session` is resumed.)
- Password reset flow works out of the box (needs SMTP + `default_url_options[:host]`).

### 3. Shows / tour dates (Bandsintown-synced)
The band maintains tour dates in **Bandsintown**, so Bandsintown is the source of truth. We **sync**
events into a local `Show` table (not a live per-request proxy) so public pages are fast, styled,
offline-capable in the PWA, can fire push notifications, and feed the AI newsletter.

- **API:** base `https://rest.bandsintown.com`; events at
  `GET /artists/{artist}/events/?app_id={APP_ID}&date=upcoming|past` (artist referenced by stable
  `id_{artist_id}` form, not name). Requires a personal `app_id` — request from Bandsintown / get an
  API Key via *Settings › General*; store in Rails credentials (`bandsintown_app_id`). Rate limits
  are undocumented → we never hit the API per page view; we cache by syncing.
- **`BandsintownClient` service:** wraps the events + artist-info endpoints, parses JSON, handles
  timeouts/errors.
- **`Show` model** mirrors Bandsintown fields for upsert: `bandsintown_id` (unique), `starts_at`,
  `title`, `description`, `venue_name`, `city`, `region`, `country`, `latitude`, `longitude`,
  `lineup`, `bandsintown_url`, ticket `offers` (JSON: type + url + status). Plus local columns:
  `status` (active/canceled), `featured`, `source` (bandsintown/manual).
- **`SyncBandsintownEventsJob`** (Solid Queue, recurring via `config/recurring.yml`, e.g. hourly):
  fetch upcoming + past, **upsert by `bandsintown_id`**, mark events that disappeared as `canceled`.
  Detect newly-synced upcoming shows → enqueue a push notification (see §9). Also a manual
  "Sync now" button in admin.
- **Public:** upcoming shows list (mobile-first cards) + past-shows archive, rendered from the local
  DB; "Get tickets" buttons from `offers`, venue map link from lat/long.
- **Admin:** read-only view of synced shows + manual sync + `featured` toggle. Optional: add/edit
  **manual** (local-only) shows for one-offs Bandsintown doesn't carry (`source: manual`, never
  overwritten by sync).
- Synced shows are available as AI-newsletter context (see §7).

### 4. Newsletter — subscribe (public, account-free)
- `Subscriber` model: `email` (unique, lower-cased), `confirmed_at`, `unsubscribed_at`.
- **Double opt-in:** signup form → `ConfirmationMailer` with a signed token
  (`generates_token_for :confirmation, expires_in: 2.days`) → `GET /confirm` sets `confirmed_at`.
  Only confirmed + not-unsubscribed subscribers receive sends.
- **One-click unsubscribe (RFC 8058 — required by Gmail/Yahoo):** non-expiring signed
  `:unsubscribe` token; `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click`
  headers; a **CSRF-exempt POST** unsubscribe endpoint, plus a visible link in the body.

### 5. Email list management (admin)
- `Admin::Subscribers` area: list with confirmed / unconfirmed / unsubscribed counts, search by email,
  manually add or remove a subscriber, resend confirmation, and **export to CSV**.
- This is the admin-facing half of §4 — "manage my email list" as an explicit requirement.

### 6. Newsletter — compose & send (admin)
- `Newsletter` model: `subject`, Action Text `body` (rich text), `status` enum (draft/scheduled/sent),
  `scheduled_at`, `sent_at`.
- `Delivery` model: `(newsletter_id, subscriber_id)` unique index for idempotent per-recipient sends,
  status (pending/sent/failed), error.
- Admin composes in a Trix editor; preview; send/schedule.
- **Send pipeline:** parent `SendNewsletterJob` fans out one `NewsletterMailer.issue(...).deliver_later`
  **per recipient**. Throttle via a dedicated single-thread `newsletters` queue in `config/queue.yml`
  (not `limits_concurrency`). Multipart HTML+text; render Action Text through a mailer **view**
  (`<%= @newsletter.body %>`) with absolute host so images resolve; inline Trix CSS.
- **Quota guard:** gate enqueuing on a per-day sent counter — free Gmail caps at **500/day**,
  Workspace **2,000/day**. Lists beyond the cap must span multiple days (recurring drain job).

### 7. AI newsletter drafting (admin)
- `gem "anthropic"`; key in Rails credentials (`anthropic_api_key`).
- `NewsletterDrafter` service: takes context (upcoming shows, recent merch, admin topic) → builds a
  prompt (stable persona via `system_:`, volatile context in user turn) → `client.messages.create`
  (`model: :"claude-opus-4-8"`, `max_tokens: ~16000`) → returns draft body.
- `GenerateNewsletterDraftJob` (Solid Queue): runs the service, saves to the `Newsletter` draft,
  **Turbo Stream broadcast** replaces a "Generating…" placeholder with the result (no reload).
  Admin then edits the draft before sending.
- Rescue `Anthropic::APIStatusError` → mark failed + broadcast error state.

### 8. Merch store (public + admin)
- Models: `Product`, `Variant` (`price_cents`, `stock_quantity`, sku), `Cart`/`CartItem`
  (session/token-based guest cart), `Order` (status pending/paid/fulfilled/canceled, Stripe ids,
  shipping address, totals), `OrderItem` (snapshot `unit_price_cents`), `StripeEvent` (idempotency).
- Public: product catalog + detail (mobile-first), cart, checkout button.
- **Stripe Checkout flow:** create a pending `Order` + Checkout Session server-side (line items
  built from DB prices — never client values), `shipping_address_collection`, `shipping_options`,
  `client_reference_id: order.id` → redirect to Stripe → success/cancel URLs.
- **Webhook** (`POST /webhooks/stripe`, CSRF-exempt): verify signature with raw body; dedupe on
  `event.id` (same transaction as fulfillment); **fulfill only when `payment_status == "paid"`**;
  decrement stock with `variant.with_lock`. Handle `checkout.session.completed`,
  `async_payment_succeeded/failed`, `expired`. **Fulfill on webhook, never on redirect.**
- Admin: product/variant CRUD, order list with shipping addresses to fulfill, mark fulfilled.
- **Order confirmation email:** branded receipt to the buyer on successful payment (sent from the
  webhook job, via the same SMTP transport). Alternatively rely on Stripe's built-in receipts —
  to confirm with the user.
- Local testing via Stripe CLI (`stripe listen --forward-to …`). Test-mode keys.
- Known tradeoff: webhook-only stock decrement has a small oversell window — acceptable with manual
  fulfillment (admin refunds rare oversell).

### 9. PWA + native notifications
- Enable Rails PWA: uncomment `manifest`/`service-worker` routes; fill `manifest.json.erb`
  (`display: standalone`, `start_url`, theme/background colors, **192 + 512 + maskable** icons);
  add `apple-touch-icon`; register the service worker.
- Service worker: install/activate (cache version), fetch (offline fallback page via `asset_path`),
  `push`, `notificationclick` handlers.
- `gem "web-push"`; generate VAPID keys → credentials; expose public key via meta tag.
- `PushSubscription` model (`endpoint` unique, `p256dh_key`, `auth_key`, `user_agent`).
- Stimulus controller: `Notification.requestPermission()` on a **button tap** → `pushManager.subscribe`
  → POST subscription to `PushSubscriptionsController`.
- `WebPushJob` (Solid Queue), one per subscription; rescue `WebPush::ExpiredSubscription` /
  `InvalidSubscription` → destroy dead record (410/404). Payload small (title + body + URL).
- Triggers: new published show, new merch drop, newsletter published.
- **iOS caveat:** Web Push needs **iOS 16.4+ AND the site Added to Home Screen first** (no auto
  prompt) → add onboarding UI guiding users to install. Android/Chrome works in-tab.

### 10. Cross-cutting / polish
- Email config: provider-agnostic SMTP via ENV (`SMTP_ADDRESS/PORT/USERNAME/PASSWORD`), Gmail app
  password (2FA required). Swapping to Resend/Postmark later = ENV change only.
- Branding/theme, SEO meta/OpenGraph, sitemap, favicons.
- Brakeman / bundler-audit / importmap audit / RuboCop already wired in CI — keep green.

---

## Suggested build order (phases)

1. **Foundation + Auth + homepage** — Tailwind, layouts, auth generator, admin namespace, seed admin,
   root landing page.
2. **Shows** — `Show` model + `BandsintownClient` + recurring sync job + public list/archive + admin
   sync view (smallest end-to-end vertical slice; needs the Bandsintown `app_id`).
3. **Newsletter subscribe + list management** — Subscriber, double opt-in, unsubscribe, Gmail SMTP
   wired, `Admin::Subscribers` (counts, search, add/remove, CSV export).
4. **Newsletter compose/send** — Newsletter/Delivery, Trix, throttled send pipeline.
5. **AI drafting** — anthropic gem, drafter service, background job + Turbo Stream.
6. **Merch store** — products/cart/orders, Stripe Checkout + webhook, admin fulfillment, order email.
7. **PWA + push** — manifest/SW, web-push, subscriptions, notification triggers, iOS onboarding.
8. **Polish** — branding, SEO, deploy hardening.

## Deliverability ceiling (plan to revisit)

Free `@gmail.com` can't authenticate a custom From domain (no SPF/DKIM) and caps at 500/day.
The provider-agnostic ENV config is the escape hatch: move to Google Workspace (branded From,
2,000/day) or an ESP (Resend/Postmark) when the list outgrows Gmail. No code change required.
