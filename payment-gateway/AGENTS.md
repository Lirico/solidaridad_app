# AGENTS.md — Solidaridad Payment Gateway

Instructions for AI agents and contributors working in `payment-gateway/`.

## Stack

- Python 3.12, FastAPI, `uv`
- Hexagonal layout: `presentation/` → `application/` → `domain/` ← `infrastructure/`
- Stateless adapter: HTTP in, ISO8583 TCP out (or mock). No client DB.

Contract notes: [`docs/gateway-plan.md`](docs/gateway-plan.md).

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

`make check` includes coverage. Do not consider the task done if lint, typecheck, tests, or coverage fail.

### Coverage (≥ 90%)

- Total line coverage for gateway packages must stay **at or above 90%**.
- Verify with `make test-cov` (or via `make check`).

| Command | Tool | Purpose |
|---------|------|---------|
| `make lint` | Ruff | Lint + import sorting (auto-fix with `make lint-fix`) |
| `make typecheck` | mypy | Static types |
| `make test` | pytest | Unit / HTTP tests |
| `make test-cov` | pytest-cov | Tests + coverage; fails under 90% |

## Conventions

- Prefer small, focused diffs that match layer boundaries.
- Do not commit secrets; use `.env` (gitignored) from `.env.example`.
- No client/user/installation context here — only authorize DTO ↔ ISO.
- Target Python 3.12 only: **do not** add retrocompatibility shims.
- ISO packer must stay faithful to `payment_processor/legacy/bin/iso_common.c`.

## Local commands (quick)

```bash
cp .env.example .env
make install
make run
# against real authkig:
#   make -C ../payment_processor up
#   set ISO_TRANSPORT=tcp in .env
make check
```
