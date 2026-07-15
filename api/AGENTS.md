# AGENTS.md — Solidaridad API

Instructions for AI agents and contributors working in `api/`.

## Stack

- Python 3.12, FastAPI, `uv`
- Layered layout: `presentation/` → `application/` → `domain/` ← `persistence/`
- Local Postgres via Docker Compose (see `README.md`)

Auth roadmap: [`docs/auth-plan.md`](docs/auth-plan.md).

## Required quality gate (every change)

After **any** code change in this package, before finishing the task, run:

```bash
make lint
make typecheck
make test
```

Or the combined target:

```bash
make check
```

Do not consider the task done if lint, typecheck, or tests fail. Fix issues introduced by the change (and pre-existing ones in files you touched, when straightforward).

| Command | Tool | Purpose |
|---------|------|---------|
| `make lint` | Ruff | Lint + import sorting (auto-fix with `make lint-fix`) |
| `make typecheck` | mypy | Static types |
| `make test` | pytest | Unit / API tests |

## Conventions

- Prefer small, focused diffs that match existing layer boundaries.
- Do not commit secrets; use `.env` (gitignored) from `.env.example`.
- Keep HTTP contracts additive when possible (`/v1`); see auth plan for compatibility notes.
- Seed data is local-only (`APP_ENV=local`).

## Local commands (quick)

```bash
cp .env.example .env
make install
make db-up && make migrate && make db-seed
make run
make check
```
