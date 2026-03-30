# Compras Express Cargo - Deployment en Render (Staging + Producción)

## Ambientes

| Ambiente     | URL                                          | Branch    | Base de datos         |
|-------------|----------------------------------------------|-----------|----------------------|
| Staging     | `https://cec-staging.onrender.com`           | `staging` | PostgreSQL (basic)   |
| Producción  | `https://cec.comprasexpresscargo.com`        | `main`    | PostgreSQL (basic)   |

---

## Pipeline CI/CD

```
feature/branch → PR a staging → CI tests pasan? → Merge → Render auto-deploy Staging
                                      ↓ falla
                                   Bloquea merge

staging → PR a main → CI tests pasan? → Merge → Render auto-deploy Producción
                            ↓ falla
                         Bloquea merge
```

### GitHub Actions CI

Archivo: `.github/workflows/ci.yml`

- Se ejecuta en cada PR a `staging` y `main`
- Configura Ruby 3.3 + PostgreSQL 16
- Corre `bundle install`, `db:create`, `db:migrate`, `rails test`
- El check **Tests** es requerido para poder hacer merge

### Protección de branches

Ambos branches (`staging` y `main`) tienen protección:
- Requieren PR (no push directo)
- Requieren que el check **Tests** pase antes de merge

---

## Servicios en Render

### Web Services

| Servicio          | Tipo | Branch    | Plan    | URL |
|-------------------|------|-----------|---------|-----|
| cec-production    | web  | `main`    | starter | `https://cec-production.onrender.com` |
| cec-staging       | web  | `staging` | starter | `https://cec-staging.onrender.com` |

### Worker

| Servicio               | Tipo             | Branch | Plan    |
|------------------------|------------------|--------|---------|
| cec-worker-production  | background_worker | `main` | starter |

- Ejecuta Solid Queue: `bundle exec rails solid_queue:start`

### Bases de Datos

| Base de datos     | Plan       | Database      | Usuario   |
|-------------------|------------|---------------|-----------|
| cec-db-production | basic_256mb | cec_production | cec_admin |
| cec-db-staging    | basic_256mb | cec_staging    | cec_admin |

### Build & Start Commands

```bash
# Build (web services)
bundle install && bundle exec rails assets:precompile && bundle exec rails db:migrate

# Start (web)
bundle exec puma -C config/puma.rb

# Start (worker)
bundle exec rails solid_queue:start
```

### Variables de Entorno

**Producción:**
- `RAILS_ENV=production`
- `DATABASE_URL` → connection string de cec-db-production
- `RAILS_MASTER_KEY` → (configurar manualmente desde `config/master.key`)
- `APP_HOST=cec.comprasexpresscargo.com`
- `RAILS_SERVE_STATIC_FILES=true`
- `WEB_CONCURRENCY=2`
- `RAILS_MAX_THREADS=5`

**Staging:**
- `RAILS_ENV=production`
- `DATABASE_URL` → connection string de cec-db-staging
- `RAILS_MASTER_KEY` → (configurar manualmente desde `config/master.key`)
- `APP_HOST=cec-staging.onrender.com`
- `RAILS_SERVE_STATIC_FILES=true`

**Nota:** `RAILS_MASTER_KEY` debe configurarse manualmente en el dashboard de Render para cada servicio.

---

## render.yaml (Blueprint)

```yaml
databases:
  - name: cec-db-production
    plan: basic_256mb
    databaseName: cec_production
    user: cec_admin
    region: oregon

  - name: cec-db-staging
    plan: basic_256mb
    databaseName: cec_staging
    user: cec_admin
    region: oregon

services:
  # ============ PRODUCCIÓN ============
  - type: web
    name: cec-production
    runtime: ruby
    plan: starter
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
      - key: APP_HOST
        value: cec.comprasexpresscargo.com
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
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        fromDatabase:
          name: cec-db-staging
          property: connectionString
      - key: APP_HOST
        value: cec-staging.onrender.com
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

## Workflow del Desarrollador

```bash
# 1. Crear feature branch desde staging
git checkout staging && git pull
git checkout -b feature/mi-feature

# 2. Trabajar, commit, push
git push -u origin feature/mi-feature

# 3. PR a staging — CI corre tests
gh pr create --base staging

# 4. Tests verdes → merge → Render deploya a cec-staging.onrender.com
# 5. Verificar en staging URL

# 6. PR staging → main — CI corre tests
gh pr create --base main --head staging

# 7. Tests verdes → merge → Render deploya a cec.comprasexpresscargo.com
```

---

## Pasos Pendientes Post-Setup

1. **Configurar `RAILS_MASTER_KEY`** en el dashboard de Render para cada servicio web y worker
2. **Configurar dominio custom** `cec.comprasexpresscargo.com` → apuntar DNS a Render (desde dashboard de cec-production)
3. **Primer deploy exitoso** requiere que el código Rails exista (Gemfile, config, etc.)

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

---

## IDs de Recursos en Render

| Recurso              | ID                          |
|----------------------|-----------------------------|
| cec-production       | srv-d750d7p4tr6s73d11i70    |
| cec-staging          | srv-d750da14tr6s73d11k00    |
| cec-worker-production| srv-d750ddsr85hc73805hpg    |
| cec-db-production    | dpg-d750d1sr85hc73805bd0-a  |
| cec-db-staging       | dpg-d750d314tr6s73d11fug-a  |
| Workspace            | tea-d74uphua2pns73apnong    |
