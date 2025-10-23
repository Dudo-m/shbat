# Repository Guidelines

## Project Structure & Module Organization

Scripts are grouped by purpose:

```
docker/       Docker environment and common services
vpn/          VPN setup (CentOS focused)
email/        Mail server setup
cert/         Self‑signed certificate tools
gs-netcat/    gsocket relay helper
dictadmin/    Lightweight proxy tools
udptcp-py/    Python network test tool
```

Place new scripts in the most relevant folder. Create a new folder only when a feature spans multiple scripts or assets. Keep scripts self‑contained and documented via `--help`.

## Build, Test, and Development Commands

- Run scripts: `bash docker/docker.sh`, `bash vpn/vpn-centos.sh`, `bash email/email-centos.sh`
- Python tool help: `python3 udptcp-py/net_tool.py --help`
- Bash lint: `shellcheck path/to/script.sh`
- Bash format: `shfmt -w .`
- Python lint: `ruff udptcp-py` (or `flake8 udptcp-py`)

Target platform is Linux Bash; on Windows use WSL or a Linux VM.

## Coding Style & Naming Conventions

- Bash: start with `#!/bin/bash` and `set -euo pipefail`; 2‑space indent; functions `snake_case`; constants `UPPER_SNAKE`.
- Files: lowercase kebab‑case for shell scripts (e.g., `docker_services.sh`, `vpn-centos.sh`), `.py` for Python.
- Python: follow PEP 8/Black style; prefer f‑strings; small, focused modules.
- Provide `usage`/`--help` output and comments for non‑obvious logic.

## Testing Guidelines

- No formal suite yet; add smoke checks for new scripts.
- Bash: `bash -n script.sh` and `shellcheck script.sh` must pass.
- Python: add `pytest` tests under `udptcp-py/tests/` (files named `test_*.py`).
- Optional: add Bats tests under `tests/` for shell behavior.

## Commit & Pull Request Guidelines

- History contains short Chinese summaries; prefer Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`. Keep subject ≤50 chars; add context in body.
- Reference issues (e.g., `Closes #12`) when applicable.
- PRs must include: what changed, why, how to test (commands), and logs/screenshots if relevant.
- Ensure scripts are non‑interactive by default or document prompts clearly.

## Security & Configuration Tips

- Some scripts require privileges; review diffs and external URLs, especially with `curl | bash`.
- Never commit secrets; use environment variables or local `.env` (git‑ignored).
- Test infrastructure changes on non‑production machines first.

