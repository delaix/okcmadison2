# Rails 7 Upgrade Plan — okcmadison2

This document outlines a step-by-step plan to upgrade from **Rails 6.0.2** to **Rails 7.x**. Follow phases in order; run the test suite after each phase.

**Current state:** Rails 6.0.2, Ruby 3.4.4 (Gemfile) / 2.7.0 (.ruby-version), Webpacker 5, Turbolinks 5, Sprockets for assets.

**Target:** Rails 7.1.x (LTS), Ruby 3.4.4, importmap + Turbo, Sprockets for CSS only (or keep full Sprockets).

---

## Prerequisites

- [ ] **Tests:** Add or run existing tests so you can verify behavior after each step.
- [ ] **Backup:** Ensure DB is backed up and you can roll back (e.g. git branch per phase).
- [ ] **Ruby:** Use the same Ruby everywhere. Set `.ruby-version` to `3.4.4` to match the Gemfile.

---

## Phase 0: Align environment (do first)

| Task | Action |
|------|--------|
| Ruby version | Set `.ruby-version` to `3.4.4` so it matches the Gemfile. |
| Bundle | Run `bundle install` (restore `Gemfile.lock` if needed with `bundle lock` then `bundle install`). |
| Zeitwerk | You're on `config.load_defaults 6.0`; Zeitwerk is already the default. Run `bin/rails zeitwerk:check` and fix any issues. |

---

## Phase 1: Rails 6.0 → 6.1

Upgrade one minor version so deprecation warnings point to Rails 7 breaking changes.

### 1.1 Update Gemfile

```ruby
# Change:
gem 'rails', '~> 6.0.2', '>= 6.0.2.2'
# To:
gem 'rails', '~> 6.1.0'
```

### 1.2 Bundle and update app

```bash
bundle update rails
bin/rails app:update
```

When prompted, prefer keeping your customizations; only overwrite when you're sure (e.g. you may keep your `config/routes.rb`, `config/application.rb` structure). If a `config/initializers/new_framework_defaults_6_1.rb` is created, leave it as-is for now.

### 1.3 Adopt 6.1 defaults (optional but recommended)

In `config/application.rb`:

```ruby
config.load_defaults 6.1
```

Re-run tests and fix any deprecations. Address **Rails 6.1 deprecations** (e.g. `ActiveModel::Error` API) so Rails 7 upgrade is smoother.

### 1.4 Verify

- [ ] `bundle exec rails -v` → 6.1.x  
- [ ] `bin/rails zeitwerk:check` → "All is good!"  
- [ ] Tests pass  
- [ ] Manual smoke test of main pages

---

## Phase 2: Replace Webpacker and Turbolinks (before Rails 7)

Rails 7 drops Webpacker. Your layout currently uses **Sprockets** (`javascript_include_tag "application"`), not the Webpacker pack, so the app is a good candidate for **importmap** (no Node build step for JS).

### 2.1 Add importmap and Turbo

```bash
# Remove Webpacker/Turbolinks from Gemfile (see 2.2), then:
bundle install
bin/rails importmap:install
bin/rails turbo:install
```

If the installer fails, add manually:

**Gemfile** — remove:

- `gem 'webpacker', '~> 5.0'`
- `gem 'turbolinks', '~> 5'`

**Gemfile** — add:

```ruby
gem 'importmap-rails', '~> 1.2'
gem 'turbo-rails', '~> 2.0'
```

Then:

```bash
bundle install
bin/rails importmap:install
bin/rails turbo:install
```

### 2.2 Configure importmap

- Pin Rails UJS and Turbo in `config/importmap.rb`:

  ```ruby
  pin "application"
  pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
  pin "@rails/ujs", to: "rails-ujs.js"
  ```

- Ensure `app/javascript/application.js` (or the entry point you use) loads Turbo and UJS:

  ```javascript
  import "@hotwired/turbo-rails"
  import "@rails/ujs"
  ```

- Remove or repurpose `app/javascript/packs/application.js` (Webpacker); the layout will load the importmap entry instead.

### 2.3 Update layout

In `app/views/layouts/application.html.erb`:

- Replace Sprockets JS with importmap and Turbo:

  ```erb
  <%= javascript_importmap_tags %>
  ```

- Keep:

  ```erb
  <%= stylesheet_link_tag "application", media: "all" %>
  <%= csrf_meta_tags %>
  ```

### 2.4 Remove Webpacker and Turbolinks

- **Gemfile:** Remove `webpacker`, `turbolinks`.
- **package.json:** Remove `@rails/webpacker`, `turbolinks` (and any other Webpacker-related deps). Keep only what you still need (e.g. no JS build = minimal or empty `dependencies`).
- Delete or ignore: `config/webpacker.yml`, `config/webpack/`, `app/javascript/packs/` (once migrated to `app/javascript/application.js` + importmap).
- Run `bundle install` and `yarn install` (if you still use yarn).

### 2.5 Verify

- [ ] No references to `javascript_pack_tag` or `stylesheet_pack_tag`.
- [ ] No references to `turbolinks` in JS or layout.
- [ ] Pages load; Turbo (e.g. link navigation) works if you use it.
- [ ] CSRF and UJS behavior (e.g. `data-method`, `data-confirm`) still work.

---

## Phase 3: Rails 6.1 → 7.0

### 3.1 Update Gemfile

```ruby
gem 'rails', '~> 7.0.0'
```

### 3.2 Spring

Spring must be **3.0+** for Rails 7. In Gemfile:

```ruby
gem 'spring', '>= 3.0'
```

### 3.3 Sprockets (assets)

Rails 7 does not depend on `sprockets-rails`. You use Sprockets for CSS (and possibly images). Add explicitly:

```ruby
gem 'sprockets-rails'
```

### 3.4 Bundle and app update

```bash
bundle update rails spring
bin/rails app:update
```

Again, prefer keeping your customizations; merge new framework defaults and initializers carefully.

### 3.5 Cookie rotator (SHA1 → SHA256)

Rails 7 changes the key generator digest to SHA256. To avoid invalidating existing sessions on first deploy, add a cookie rotator.

Create `config/initializers/cookie_rotator.rb`:

```ruby
# See: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#key-generator-digest-class-change-requires-a-cookie-rotator
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    authenticated_encrypted_cookie_salt = Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt
    signed_cookie_salt = Rails.application.config.action_dispatch.signed_cookie_salt
    secret_key_base = Rails.application.secret_key_base

    key_generator = ActiveSupport::KeyGenerator.new(secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1)
    key_len = ActiveSupport::MessageEncryptor.key_len

    old_encrypted_secret = key_generator.generate_key(authenticated_encrypted_cookie_salt, key_len)
    old_signed_secret = key_generator.generate_key(signed_cookie_salt)

    cookies.rotate :encrypted, old_encrypted_secret
    cookies.rotate :signed, old_signed_secret
  end
end
```

After all servers run Rails 7 and old cookies have rotated, you can remove this initializer.

### 3.6 Framework defaults

In `config/application.rb`:

```ruby
config.load_defaults 7.0
```

If you have `config/initializers/new_framework_defaults_7_0.rb`, enable any defaults you want (or remove the file and rely on `load_defaults 7.0` after reading the guide).

### 3.7 Test environment

In `config/environments/test.rb`, Rails 7.1+ expects symbolic values for `show_exceptions`. You can do this in Phase 4, or now:

```ruby
config.action_dispatch.show_exceptions = :none   # was false
```

### 3.8 Schema

After `app:update`, run:

```bash
bin/rails db:schema:dump
```

Ensure `db/schema.rb` uses the new format (e.g. `ActiveRecord::Schema[7.0].define(...)`). Commit the updated schema.

### 3.9 Verify

- [ ] `bundle exec rails -v` → 7.0.x  
- [ ] `bin/rails zeitwerk:check`  
- [ ] Tests pass  
- [ ] No autoload of reloadable constants during initialization (fix any such deprecations).

---

## Phase 4: Rails 7.0 → 7.1 (recommended)

Rails 7.1 is the current LTS. Ruby 3.1+ required for 7.1; you're on 3.4.4, so you're fine.

### 4.1 Update Gemfile

```ruby
gem 'rails', '~> 7.1.0'
```

### 4.2 Bundle and update

```bash
bundle update rails
bin/rails app:update
```

### 4.3 Development/test secret file (7.1)

Rails 7.1 reads the local secret from `tmp/local_secret.txt` (not `tmp/development_secret.txt`). Either:

- Rename: `mv tmp/development_secret.txt tmp/local_secret.txt` (if it exists), or  
- Let Rails create a new `tmp/local_secret.txt` (sessions in dev/test will reset).

### 4.4 Test environment

In `config/environments/test.rb`:

```ruby
config.action_dispatch.show_exceptions = :rescuable   # Rails 7.1 default
```

### 4.5 Framework defaults

In `config/application.rb`:

```ruby
config.load_defaults 7.1
```

### 4.6 Verify

- [ ] `bundle exec rails -v` → 7.1.x  
- [ ] Tests pass  
- [ ] Optional: enable one-by-one any flags in `config/initializers/new_framework_defaults_7_1.rb`, then remove the file and rely on `load_defaults 7.1`.

---

## Phase 5: Cleanup and optional improvements

### 5.1 Remove webdrivers (test)

Selenium 4.6+ manages drivers. In Gemfile, remove from `group :test`:

```ruby
# gem 'webdrivers'
```

Run tests; if something fails due to missing driver, ensure `selenium-webdriver` is up to date. Then `bundle install`.

### 5.2 Obsolete front-end

- **Google+:** Remove the Google+ script and `g-plusone` from `app/views/layouts/_header.html.erb` (Google+ was shut down).
- **Facebook:** Update to the current Facebook SDK if you still use it.

### 5.3 Production config

- Ensure `config.require_master_key = true` (or equivalent) in production if you use encrypted credentials.
- Review `config.active_support.cache_format_version` if you use caching (7.0/7.1 defaults can change format).

---

## Checklist summary

| Phase | Focus |
|-------|--------|
| 0 | Ruby 3.4.4 everywhere, `zeitwerk:check` |
| 1 | Rails 6.1, fix 6.1 deprecations |
| 2 | importmap + Turbo; remove Webpacker/Turbolinks |
| 3 | Rails 7.0, Sprockets, Spring 3+, cookie rotator, schema |
| 4 | Rails 7.1, local_secret.txt, test show_exceptions |
| 5 | webdrivers, Google+/FB cleanup, production config |

---

## References

- [Upgrading Ruby on Rails](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Rails 7.0 release notes](https://guides.rubyonrails.org/7_0_release_notes.html)
- [Rails 7.1 release notes](https://guides.rubyonrails.org/7_1_release_notes.html)
- [Importmap Rails](https://github.com/rails/importmap-rails)
- [Turbo Handbook](https://turbo.hotwired.dev/)
