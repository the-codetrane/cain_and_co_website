# Data & Privacy

What personal data this application stores, where it lives, who it goes to, and how to service a
deletion or access request.

**All GDPR/CCPA requests — access, correction, deletion, or objection — go to
`info@2100enterprises.com`.** The public-facing commitment to that address is in
`app/views/pages/privacy.html.erb`; keep the two in sync.

Operating entity: **2100 Enterprises, LLC**, doing business as Cain & Co.

> Keep this file current. When a migration adds a column holding personal data, add a row here and
> check whether `app/views/pages/privacy.html.erb` needs the same change. An inaccurate privacy
> policy is its own liability, separate from the underlying handling.

---

## Inventory

Every table below holds personal data. Line references are to `db/schema.rb`.

| Table | Fields | Why we hold it | Lifetime |
|---|---|---|---|
| `orders` | `buyer_name`, `buyer_email`, `shipping_name`, `shipping_address1`, `shipping_address2`, `shipping_city`, `shipping_state`, `shipping_zip`, `shipping_country` | Fulfilling and shipping merch, customer service | Tax/accounting retention — **window not yet set, see open questions** |
| `orders` | `stripe_checkout_session_id`, `stripe_payment_intent_id` | Reconciling a payment with Stripe; refunds | Same as the order |
| `subscribers` | `email`, `confirmed_at`, `unsubscribed_at` | Newsletter delivery, proof of double opt-in | Until unsubscribe |
| `deliveries` | `subscriber_id` → `newsletter_id`, `status`, `sent_at`, `error` | Which subscriber got which newsletter; send diagnostics | Cascades on subscriber delete (`dependent: :destroy`) |
| `push_subscriptions` | `endpoint` (unique per browser/device), `p256dh_key`, `auth_key`, `user_agent` | Delivering Web Push notifications | Until the user disables notifications or the endpoint 404/410s and `WebPushJob` prunes it |
| `sessions` | `ip_address`, `user_agent`, `user_id` | Admin sign-in audit trail | Until sign-out / session record deleted |
| `users` | `email_address`, `password_digest` | Admin login — **not** fan-facing; no public signup | Life of the admin account |
| `carts` | `token` (random, in the Rails session cookie) | Cart persistence across requests | Not identifying on its own; becomes linkable only if the cart converts to an order |

**Not collected:** no analytics, no advertising or cross-site tracking cookies, no fan accounts, no
card numbers (see below), no location data beyond the shipping address a buyer types in.

### Card data

Card numbers never reach our servers. Checkout redirects to Stripe-hosted Checkout
(`CheckoutController#create`); we persist only Stripe's identifiers on the `orders` row. Stripe is
the processor of record for payment instruments.

---

## Third parties

Personal data leaves our infrastructure to exactly three vendors, each receiving only what its
function requires.

| Vendor | Receives | Role |
|---|---|---|
| Stripe | Buyer name, email, shipping and card details entered on Stripe Checkout | Payment processing |
| Mailgun | Subscriber and buyer email addresses, message contents (`config/environments/production.rb:62`) | Transactional email + newsletter delivery |
| DigitalOcean | Everything at rest — SQLite volume + Spaces object storage (`config/storage.yml`) | Hosting and image storage |

Bandsintown (show sync) and YouTube (embedded video) are outbound/inbound content only — we send
them no personal data. A YouTube embed does let Google set its own cookies in the visitor's browser.

---

## Servicing a request

A request to `info@2100enterprises.com` touches up to four places. There is **no automated DSAR
tooling** — this is a manual runbook today.

1. **Verify the requester** controls the email address before disclosing or deleting anything.
2. **Newsletter** — find by email in `Admin::Subscribers`; unsubscribe or destroy. Destroying
   cascades to `deliveries`.
3. **Orders** — `Order.where(buyer_email: …)`. Deletion conflicts with tax retention; the usual
   answer is to keep the financial record and redact the shipping fields once the retention window
   passes. Decide this deliberately, not ad hoc.
4. **Push** — `PushSubscription` keys off an opaque `endpoint`, not an email, so it generally can't
   be matched to a person by request. Ask the requester to disable notifications in their browser.
5. **Stripe and Mailgun** hold their own copies. Deleting our row does not delete theirs; handle
   those in each vendor's dashboard.

---

## Open questions

Unresolved items that affect whether the published policy stays accurate:

- **Order retention window.** `app/views/pages/privacy.html.erb` currently says "as long as required
  for tax, accounting, and customer-service purposes" because no concrete period has been set.
  Setting one (commonly 7 years for financial records) lets the policy state it plainly.
- **Redaction path for fulfilled orders.** No mechanism exists to drop shipping fields while keeping
  the financial record. Worth a small job if order volume grows.
- **EEA/UK exposure.** Whether GDPR applies turns on shipping to or marketing into those regions.
  The policy honors these rights for everyone regardless, which is the safe posture, but the
  underlying obligations are a question for a lawyer — nothing here has had legal review.
