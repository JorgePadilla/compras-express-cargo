# Compras Express Cargo - Deployment en Render (Staging + Producción)

## Ambientes

| Ambiente     | URL                                          | Branch    | Base de datos       |
|-------------|----------------------------------------------|-----------|---------------------|
| Staging     | `https://cec-staging.onrender.com`           | `staging` | PostgreSQL (free/starter) |
| Producción  | `https://cec.comprasexpresscargo.com`        | `main`    | PostgreSQL (standard) |

---

## render.yaml (Blueprint)

```yaml
databases:
  - name: cec-db-production
    plan: standard
    databaseName: cec_production
    user: cec_admin
    region: oregon

  - name: cec-db-staging
    plan: starter
    databaseName: cec_staging
    user: cec_admin
    region: oregon

services:
  # ============ PRODUCCIÓN ============
  - type: web
    name: cec-production
    runtime: ruby
    plan: standard
    region: oregon
    branch: main
    buildCommand: |
      bundle install &&
      bundle exec rails assets:precompile &&
      bundle exec rails db:migrate
    startCommand: bundle exec puma -C config/puma.rb
    healthCheckPath: /up
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: cec-db-production
          property: connectionString
      - key: RAILS_SERVE_STATIC_FILES
        value: "true"
      - key: WEB_CONCURRENCY
        value: "2"
      - key: RAILS_MAX_THREADS
        value: "5"

  # Worker para Solid Queue (producción)
  - type: worker
    name: cec-worker-production
    runtime: ruby
    plan: starter
    region: oregon
    branch: main
    buildCommand: bundle install
    startCommand: bundle exec rails solid_queue:start
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: cec-db-production
          property: connectionString

  # ============ STAGING ============
  - type: web
    name: cec-staging
    runtime: ruby
    plan: starter
    region: oregon
    branch: staging
    buildCommand: |
      bundle install &&
      bundle exec rails assets:precompile &&
      bundle exec rails db:migrate
    startCommand: bundle exec puma -C config/puma.rb
    healthCheckPath: /up
    envVars:
      - key: RAILS_ENV
        value: staging
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: cec-db-staging
          property: connectionString
      - key: RAILS_SERVE_STATIC_FILES
        value: "true"
```

---

## Dockerfile (Rails 8 default)

```dockerfile
ARG RUBY_VERSION=3.3.0
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache

COPY . .

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
```

---

## Ambiente Staging (config/environments/staging.rb)

```ruby
# config/environments/staging.rb
# Copia de production con ajustes para testing

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.active_storage.service = :amazon  # o :local para staging
  config.force_ssl = true
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.log_level = :info

  config.action_mailer.default_url_options = {
    host: "cec-staging.onrender.com",
    protocol: "https"
  }

end
```

---

## Pasos para Hacer Deploy

### Setup Inicial

```bash
# 1. Crear app Rails 8
rails new compras-express-cargo -d postgresql -c tailwind

# 2. Generar autenticación Rails 8
bin/rails generate authentication

# 3. Configurar Git
git init
git add .
git commit -m "Initial Rails 8 setup"

# 4. Crear branches
git checkout -b staging
git push origin staging
git checkout main
git push origin main
```

### En Render Dashboard

1. **Conectar repositorio GitHub** al proyecto en Render
2. **Crear Blueprint** usando el `render.yaml`
3. **Configurar variables de entorno:**
   - `RAILS_MASTER_KEY` → (de `config/master.key`)
4. **Configurar dominio custom** para producción:
   - `cec.comprasexpresscargo.com` → apuntar DNS a Render

### Workflow de Deploy

```
Feature branch → PR a staging → Deploy automático a staging
                     ↓
              Revisar en staging URL
                     ↓
         PR de staging → main → Deploy a producción
```

---

## Comandos Útiles

```bash
# Ver logs en Render
render logs --service cec-production

# Consola Rails en Render (desde dashboard o CLI)
render shell --service cec-production
bin/rails console

# Ejecutar migración manual
render shell --service cec-production
bin/rails db:migrate

# Seed de datos iniciales
render shell --service cec-production
bin/rails db:seed
```

---

## Monitoreo

- **Health check:** `/up` (Rails 8 default)
- **Logs:** Render dashboard o CLI
- **Errores:** Considerar agregar Sentry o Honeybadger
- **Uptime:** Render incluye monitoring básico
