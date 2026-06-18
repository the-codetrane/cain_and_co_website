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
