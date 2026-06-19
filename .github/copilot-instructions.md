# GitHub Copilot Instructions

## Project

Rails 8.1, Ruby 4.0.1. SQLite in all environments. No Redis — background jobs, cache, and Action Cable run on the Solid trio (`solid_queue`, `solid_cache`, `solid_cable`). Frontend is Hotwire (Turbo + Stimulus) via importmap — no Node, no bundler, no webpack. Assets via Propshaft. Deployed with Kamal.

---

## Ruby Style

- Enforce **rubocop-rails-omakase** — flag any cop violation, even minor layout issues; do not suggest suppressing cops without a strong reason.
- Prefer modern Ruby 4 syntax:
  - Pattern matching (`case/in`, `=>`, `in` guard) over complex conditionals.
  - Endless methods (`def foo = bar`) for single-expression readers.
  - Numbered block parameters (`_1`, `_2`) for short, obvious blocks; named params for anything non-trivial.
  - `Data.define` for lightweight value objects instead of `Struct`.
  - `then` / `yield_self` for object pipelines; `tap` only for side-effectful debugging chains.
  - Hash shorthand syntax (`{foo:}` not `{foo: foo}`).
  - Rightward assignment (`=> result`) only where it genuinely improves readability.
- Prefer `frozen_string_literal: true` at the top of every file not already frozen.
- No `unless` with `else`; rewrite as `if/else`.
- No `rescue Exception` — rescue `StandardError` or a specific subclass.
- Avoid `send` / `public_send` for dynamic dispatch unless genuinely necessary; prefer a `case` or a lookup table.

---

## Rails Conventions

### Models
- Scopes must be lambdas (`scope :active, -> { where(active: true) }`).
- Prefer `with_options` to group repeated options on validations/callbacks.
- Avoid `after_commit` / `after_save` for business logic — use a service object or a `SolidQueue` job instead.
- Always add database-level constraints (index, `null: false`, `default:`) in migrations alongside model validations; the DB is the last line of defence.
- Use `enum` with the hash form (`enum status: { draft: 0, published: 1 }`, never the array form) and prefix or suffix to avoid method collisions.
- Avoid `default_scope` entirely.

### Controllers
- Keep controllers thin: one public action, private helper methods, no business logic beyond finding/persisting records.
- Require and permit params explicitly via `params.require(:resource).permit(...)`. Flag any `permit!` or unbounded param merging.
- Use `before_action` only for authentication/authorization and simple record lookup; avoid chains of callbacks that obscure control flow.
- Redirect after mutation (PRG pattern); never render a form from a `POST` action on success.
- Prefer `respond_to` + Turbo Stream responses over full-page redirects for interactive flows.

### Views / Hotwire
- Default to server-side rendering with Turbo Frames and Turbo Streams; suggest Stimulus only when interactivity cannot be achieved with Turbo.
- Stimulus controllers belong in `app/javascript/controllers/`; they must be imported via `importmap.rb` — no `npm install`, no inline `<script>` tags.
- Partials extracted for any template fragment used more than once.
- No raw SQL or ActiveRecord calls in views or helpers; delegate to presenters/helpers or the controller.

### Queries & Performance
- Flag any N+1 query: every `has_many` / `belongs_to` traversal in a loop must be covered by `includes`, `preload`, or `eager_load`.
- Prefer `pluck` over `map(&:attr)` when only column values are needed.
- Use `find_each` / `find_in_batches` instead of `.all.each` on unbounded collections.
- Avoid `count` in favour of `size` when the association may already be loaded.
- Index every foreign key and every column used in `where`, `order`, or `group` by default; flag missing indexes in migrations.
- Be explicit about `SELECT` when only a subset of columns is needed (`.select(:id, :name)`) for large tables.

### Background Jobs (SolidQueue)
- Jobs must be idempotent — flag any job that would cause data corruption if enqueued twice.
- Set `retry_on` / `discard_on` explicitly; do not rely on the default retry behaviour for domain-specific errors.
- Avoid heavy computation in the job body; delegate to a service object.
- Never perform HTTP calls inline in a request — always enqueue a job.

### Security
- Strong parameter discipline (see Controllers above).
- No `html_safe` / `raw` unless the content is provably developer-controlled; flag any use on user-supplied data.
- Credentials and secrets must live in `credentials.yml.enc` or environment variables — never hardcoded, never committed in plain text.
- Flag any SQL fragment interpolated directly from user input; use `sanitize_sql_array` or a parameterised scope.
- `protect_from_forgery` must remain enabled; flag any `skip_before_action :verify_authenticity_token` without a clear, scoped reason (e.g., API-only endpoint with token auth).
- Cross-reference findings against Brakeman categories — CI already runs `bin/brakeman`; any warning category it covers is in scope here.

### Routing
- Prefer resourceful routes (`resources`, `resource`) over one-off named routes.
- Namespace admin/internal routes under a dedicated scope with appropriate authentication.
- No logic in `routes.rb` beyond route declarations; use constraints classes for complex matching.

---

## Testing (Minitest)

- Tests live in `test/`, fixtures in `test/fixtures/`. **No RSpec.**
- System tests use Capybara + Selenium (`test/system/`).
- Every model validation, scope, and callback needs a unit test.
- Controller tests should cover authorization as well as happy-path responses.
- Fixtures over factories; add factory-like helpers only if fixture complexity becomes unmanageable.
- Use `assert_difference`, `assert_changes`, and `assert_enqueued_with` from Rails' test helpers before rolling custom matchers.
- Flag any test that stubs `Time.now` without using `travel_to`.

---

## Frontend (importmap / Propshaft)

- JS dependencies are pinned in `config/importmap.rb` and vendored in `vendor/javascript` — flag any suggestion to run `npm`/`yarn`.
- Stimulus controllers must use `connect()` / `disconnect()` lifecycle correctly; flag missing `disconnect` cleanup for event listeners or timers.
- No inline styles; use CSS custom properties or Tailwind/BEM classes consistent with the existing stylesheet conventions.
- No CDN imports in templates; all assets must be local or properly pinned in importmap.

---

## Deployment / Infrastructure

- Kamal manages deployment; `config/deploy.yml` is the source of truth for services and environment config.
- SQLite is intentional in all environments — do not suggest migrating to Postgres unless the user raises it.
- Thruster (`bin/thrust`) handles asset serving in production; Propshaft handles the pipeline — flag any reference to Sprockets, Asset Pipeline v1, or `asset_path` helpers that assume the old pipeline.
- The health check endpoint is `GET /up` — do not remove or rename it.
