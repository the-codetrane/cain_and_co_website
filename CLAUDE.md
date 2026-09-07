# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Cain & Co. company website. A freshly-generated **Rails 8.1** application (Ruby 4.0.1) on the modern Rails "omakase" stack — no custom domain models, controllers, or routes exist yet beyond the generated defaults. Treat this as a greenfield app: most feature work starts by generating models/controllers and adding routes.

## Stack

- **Database:** SQLite (`sqlite3`), used in all environments including production.
- **Background jobs / cache / cable:** the Solid trio — `solid_queue`, `solid_cache`, `solid_cable` — all database-backed (no Redis). Their schemas live in `db/{queue,cache,cable}_schema.rb` on separate database connections.
- **Frontend:** Hotwire (`turbo-rails` + `stimulus-rails`) with `importmap-rails` (no Node/bundler — JS dependencies are pinned in `config/importmap.rb` and served from `vendor/javascript`). Stimulus controllers live in `app/javascript/controllers/`. Assets via **Propshaft** (not Sprockets).
- **Server:** Puma behind Thruster (`bin/thrust`) for asset caching/compression in production.
- **Deploy:** Kamal (Docker-based) — see `config/deploy.yml` and `.kamal/`.

## Commands

```bash
bin/setup            # install deps, prepare DB, start dev server
bin/dev              # start the local dev server
bin/rails test                              # run all tests (Minitest)
bin/rails test test/path/to/file_test.rb    # run a single test file
bin/rails test test/path/to/file_test.rb:42 # run a single test by line number
bin/rails test:system                       # run Capybara/Selenium system tests
bin/rubocop          # lint (rubocop-rails-omakase house style; see .rubocop.yml)
bin/brakeman         # static security analysis
bin/bundler-audit    # audit gems for known CVEs
bin/importmap audit  # audit JS dependencies
```

CI (`.github/workflows/ci.yml`) runs, on every PR and push to `main`: Brakeman, bundler-audit, `importmap audit`, RuboCop, and `bin/rails db:test:prepare test test:system`. Match these locally before pushing.

## Conventions

- **Tests use Minitest**, not RSpec (`test/` dir, fixtures in `test/fixtures/`). System tests use Capybara + Selenium.
- **Linting is rubocop-rails-omakase** — add house-style overrides to `.rubocop.yml` rather than fighting the defaults.
- The `/up` route (`rails/health#show`) is the health check used by load balancers/Kamal.

## Credentials keys

There are **two** encrypted credentials files with **two different keys**, and mixing them up is the
single most common way to break a deploy:

| File | Key | Used by |
| --- | --- | --- |
| `config/credentials.yml.enc` | `config/master.key` | development/test |
| `config/credentials/production.yml.enc` | `config/credentials/production.key` | production |

Both key files are gitignored, so they never reach a CI runner or the Docker image. Kamal injects
the key as the `RAILS_MASTER_KEY` env var (see `.kamal/secrets`), sourced from the local key file
when present and otherwise from the GitHub Actions secret of the same name. Despite that name it
must hold **`config/credentials/production.key`**, not `config/master.key` — Rails resolves the key
as `read_env_key || read_key_file`, so the env var wins inside the container and the wrong one fails
boot with `ActiveSupport::MessageEncryptor::InvalidMessage: AEAD authentication tag verification
failed`, which Kamal only reports as a health-check timeout.

Run `bin/verify_credentials_key production` to check a key before deploying; the deploy job runs it
as a preflight. **If you rotate `config/credentials/production.key`, update the `RAILS_MASTER_KEY`
GitHub Actions secret in the same change** (`gh secret set RAILS_MASTER_KEY < config/credentials/production.key`).

## Personal data

`docs/DATA_PRIVACY.md` is the inventory of every column holding personal data, the three vendors it
reaches (Stripe, Mailgun, DigitalOcean), and the runbook for access/deletion requests, which go to
`info@2100enterprises.com`.

**When a migration adds or removes a column holding personal data, update `docs/DATA_PRIVACY.md` and
check whether the public policy in `app/views/pages/privacy.html.erb` needs the same change.** The
published policy is a binding public statement — letting it drift out of sync with the schema is a
liability in itself. The legal pages are served by `PagesController#privacy` / `#tos`; bump
`PagesController::LAST_UPDATED` whenever their text changes.
