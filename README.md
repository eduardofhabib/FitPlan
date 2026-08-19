# FitPlan

FitPlan manages personalised diet and workout plans, including BMI/BMR and meal-calorie calculations, plan sharing, and rankings.

## Local development on Windows

### Prerequisites

- Git, to clone the repository.
- Ruby **3.4.5** (the version in `.ruby-version`) with Bundler **2.4.17**.
- Node.js **20.4.0** (the version in `.node-version`) and Yarn Classic **1.22.22**.
- PostgreSQL **16** with its `bin` directory on `PATH`. This is the version used in CI and production deployment.
- Google Chrome only when running the system tests; the suite uses headless Chrome through Selenium.

Docker is not required for local development. The included Dockerfile is a production image, and development uses the installed PostgreSQL service directly.

### Configure PostgreSQL

Start the PostgreSQL 16 service, then provision the local login role used by the Windows configuration. Run the following command and enter the PostgreSQL administrator password selected during installation:

```powershell
& "C:\Program Files\PostgreSQL\16\bin\psql.exe" -h 127.0.0.1 -p 5432 -U postgres -d postgres
```

At the `psql` prompt, run these commands. They create `fitplan` only if needed, ensure it can create the development databases, and ask for its password without putting it in shell history:

```sql
SELECT 'CREATE ROLE fitplan LOGIN CREATEDB'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fitplan')
\gexec
ALTER ROLE fitplan WITH LOGIN CREATEDB;
\password fitplan
\q
```

Store that local password outside the repository in PostgreSQL's password file:

```powershell
New-Item -ItemType Directory -Force (Join-Path $env:APPDATA "postgresql")
notepad (Join-Path $env:APPDATA "postgresql\pgpass.conf")
```

Add this single line to the opened file, replacing the placeholder:

```text
127.0.0.1:5432:*:fitplan:YOUR_LOCAL_PASSWORD
```

`pgpass.conf` is local to the Windows profile and must not be copied into this repository. To use another host, port, or role, set `POSTGRES_HOST`, `POSTGRES_PORT`, and/or `POSTGRES_USER` in the terminal before running Rails. `POSTGRES_PASSWORD` is also supported, but the password file avoids placing a secret in shell history.

### Install and run

From the project directory:

```powershell
ruby bin/setup --skip-server
ruby bin/setup
```

The setup command verifies or installs the locked Ruby gems and Yarn packages, builds the CSS, and creates/migrates the four development databases: primary, cache, queue, and cable. The second command starts the server at http://localhost:3000.

On native Windows Ruby, Puma runs in single-process mode and background jobs use Rails' built-in asynchronous adapter. This avoids the unsupported `fork()` API while keeping jobs such as plan copies working during development. Solid Queue remains the development adapter on Linux and macOS and the production configuration is unchanged.

When editing SCSS, run the existing watcher in a second PowerShell window:

```powershell
yarn watch:css
```

### Validate

```powershell
ruby bin/rails db:test:prepare test
ruby bin/rubocop
ruby bin/brakeman --no-pager
ruby bin/importmap audit
```

The full test command includes system tests and therefore requires Chrome. The test suite uses its own `fitplan_test` database; `db:test:prepare` may recreate it.

### Local data and secrets

Development uses local disk storage (`storage/`) and does not require S3 or SMTP credentials. S3-compatible Hetzner storage and SMTP credentials are production-only. `.env*`, `config/master.key`, logs, temporary files, uploaded files, compiled assets, and `node_modules` are already ignored by Git. Do not add production credentials to local configuration files or commits.
