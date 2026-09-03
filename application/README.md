# Inertia Rails React Starter Kit

A modern full-stack starter application with Rails backend and React frontend using Inertia.js based on the [Laravel Starter Kit](https://github.com/laravel/react-starter-kit).

## About this repo

This starter kit is generated output of [inertia-rails/generator](https://github.com/inertia-rails/generator):
each generator release regenerates the app and opens an automated sync PR here, so most files in this repo
are overwritten on every sync. **To contribute changes to the app itself, open a PR against the generator** —
only this README and the deploy workflow are kit-owned.

Prefer different options (framework, JavaScript instead of TypeScript, feature set)? Generate your own app:

```sh
rails new myapp -m https://raw.githubusercontent.com/inertia-rails/generator/dist/template.rb
```

## Features

- [Inertia Rails](https://inertia-rails.dev) & [Vite Rails](https://vite-ruby.netlify.app) setup
- [React](https://react.dev) frontend with TypeScript & [shadcn/ui](https://ui.shadcn.com) component library
- User authentication system (based on [Authentication Zero](https://github.com/lazaronixon/authentication-zero))
- [Kamal](https://kamal-deploy.org/) for deployment
- Optional SSR support

See also:
- [Svelte Starter Kit](https://github.com/inertia-rails/svelte-starter-kit) for Inertia Rails with Svelte
- [Vue Starter Kit](https://github.com/inertia-rails/vue-starter-kit) for Inertia Rails with Vue

<a href="https://evilmartians.com/?utm_source=inertia-rails-react-starter-kit&utm_campaign=project_page">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Built by Evil Martians" width="236" height="54">
</a>

## Setup

1. Clone this repository
2. Start PostgreSQL:
   ```bash
   docker compose up -d db
   ```
3. Setup dependencies & run the server:
   ```bash
   bin/setup
   ```
4. Open http://localhost:3000

The Compose service runs PostgreSQL 18.4 on `localhost:5433`. Rails connects as the
restricted `hire_do_app` role (password `hire_do_development`) to database
`hire_do_development`; `bin/setup` uses the `hire_do` migration owner. Override the
connection with `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`,
`POSTGRES_DATABASE`, and `POSTGRES_TEST_DATABASE` as needed. Stop it with `docker compose down` (add `-v` to
also remove its local database volume).

The PostgreSQL schema is stored in `db/structure.sql`, not `db/schema.rb`, because
RLS policies must survive loading a fresh test or staging database. Run the direct
database proof with:

```bash
bin/rspec spec/database/row_level_security_spec.rb
```

To provision or rotate a local/runtime role as the migration owner, run:

```bash
POSTGRES_USER=hire_do \
POSTGRES_RUNTIME_PASSWORD=replace-me \
bin/rails db:provision_runtime_role
```

The task creates a login role with `NOSUPERUSER` and `NOBYPASSRLS`, then grants only
application table/sequence access. Do not run it with an application runtime URL.

To erase and reload only the local development database, use the safe reset script:

```bash
bin/reset-database
```

It runs migrations and seeds as `hire_do`, then reapplies the grants required by the
restricted `hire_do_app` web role. Do not use a bare `db:drop db:create` command:
Docker's one-time initialization script does not rerun after a database recreation.

After setup, sign in internally with `admin@hire.do` and password `HireDoDemo2026!`.
The development seeds create a TurnKey Staffing workspace with a client, project,
jobs, and candidates. To verify the client boundary, sign in as
`client@northstar.example` with the same password and open
`/client/applications`; that account can see only candidates presented to Northstar.

## Production database configuration

Production uses separate PostgreSQL databases for the primary application, Solid
Cache, Solid Queue, and Solid Cable. Set `DATABASE_URL`, `CACHE_DATABASE_URL`,
`QUEUE_DATABASE_URL`, and `CABLE_DATABASE_URL`; all four are required in production.
These databases can share one PostgreSQL server; they do not require four PostgreSQL
instances. These are **runtime** URLs and must point to the restricted application
role.

Migrate each release from a short-lived migrator environment with separate owner
URLs; do not inject these values into long-running web or worker containers:

```bash
DATABASE_MIGRATION_URL=postgresql://migration-owner:... \
CACHE_DATABASE_MIGRATION_URL=postgresql://migration-owner:... \
QUEUE_DATABASE_MIGRATION_URL=postgresql://migration-owner:... \
CABLE_DATABASE_MIGRATION_URL=postgresql://migration-owner:... \
bin/prepare-database
```

The runtime image intentionally does not call `db:prepare` on boot.

## Enabling SSR

This starter kit ships SSR-ready but turned off. The Puma plugin
([`plugin :inertia_ssr`](config/puma.rb)) manages the Node.js renderer
in-process — no separate accessory required.

To turn SSR on, flip two switches:

1. Set `config.ssr_enabled = true` in [`config/initializers/inertia_rails.rb`](config/initializers/inertia_rails.rb).
2. Build the image with `SSR_ENABLED=true` so the SSR bundle ships
   alongside the app. Two ways:

   **With Kamal** — add to [`config/deploy.yml`](config/deploy.yml):

   ```yml
   builder:
     args:
       SSR_ENABLED: true
   ```

   **By hand** — pass the build arg directly:

   ```bash
   docker build --build-arg SSR_ENABLED=true -t react_starter_kit .
   ```

That's it. Puma boots the SSR process automatically when
`ssr_enabled` is true, and Inertia falls back to client-side
rendering if it ever fails (see `config.on_ssr_error`).

In development, flipping `ssr_enabled` is enough — Vite serves SSR
via its own dev endpoint with HMR. The Docker build arg only matters
for production images.

## License

The project is available as open source under the terms of the [MIT License](LICENSE).
