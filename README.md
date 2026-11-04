# Cain & Co. Website

A mobile-first, installable (PWA) Rails 8.1 site for [Cain & Co.](https://cainandco.band), an American blues rock band based in St. Paul, Minnesota. Fans browse shows, subscribe to a monthly newsletter, and buy merch with guest checkout. The band's admin manages the email list, drafts the newsletter with AI help, and runs the store.

## Features

- **Shows**: tour dates synced from Bandsintown into a local table, with an upcoming list and past-shows archive
- **Newsletter**: double opt-in signup, one-click unsubscribe, rich-text composer, and a throttled send pipeline
- **AI drafting**: newsletter drafts generated with Claude via the official `anthropic` gem, then edited by an admin
- **Merch store**: guest checkout through hosted Stripe Checkout, with webhook-driven fulfillment and an admin order view
- **PWA and push**: installable app with Web Push notifications for new shows and merch
- **Admin area**: authentication is admin-only, with no public signup and no fan accounts

## Stack

- **Framework**: Rails 8.1 with SQLite, served by Puma and Thruster
- **Jobs, cache, and cable**: Solid Queue, Solid Cache, and Solid Cable (no Redis)
- **Frontend**: Hotwire (Turbo and Stimulus), importmap-rails, and Propshaft (no Node)
- **CSS**: Tailwind CSS v4, mobile-first
- **Payments**: Stripe Checkout
- **Email**: Action Mailer over provider-agnostic SMTP
- **Deploy**: Kamal

## Docs

- [docs/FEATURE_PLAN.md](docs/FEATURE_PLAN.md): stack decisions, feature areas, and build phases
- [docs/DATA_PRIVACY.md](docs/DATA_PRIVACY.md): personal-data inventory, third-party processors, and the runbook for access and deletion requests

