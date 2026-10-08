# CLAUDE.md

Guidance for AI coding agents working in this repo.

## What this repo is

Ansible roles and playbooks that configure existing Debian LXC containers on
Proxmox. Code only: the inventory, variables, and vault live in a separate
private repo cloned next to this one, located through `ANSIBLE_INVENTORY` in
`.envrc` (see `.envrc.example` and `README.md`). Nothing specific to one lab
belongs here: no real addresses, domains, host names, user names, or
container IDs. Examples use `example.com`, `home.arpa`, and `192.0.2.0/24`.

## Running playbooks

- Run from the repo root with `.envrc` loaded (direnv). Without it Ansible
  has no inventory.
- Always run `ansible-playbook <playbook> --check --diff` first and review
  it. Apply mode only when the user explicitly approves that run.
- `--diff` output can contain templated secrets. Don't paste it into commits,
  docs, or reports; summarize it.
- Never run `ansible-vault`, `ansible-inventory --list`, or
  `ansible-inventory --host`: they show decrypted vault values. Refer to vault
  variables by name only.

## Role conventions

- Each role has a `README.md` listing purpose, requirements, every variable
  (name, default, description), required vault variables, and an example
  play. Update it in the same change as the role.
- Values with no safe default are required: leave them out of
  `defaults/main.yml` (document them in a comment) and assert them in a
  `Check required variables` task at the top of `tasks/main.yml`.
- Secrets come from `vault_*` variables, reach hosts through templated files
  with mode `0600`, and tasks that handle them use `no_log: true`.
- Idempotency is the correctness test: a second run must report
  `changed=0`. `command`/`shell` tasks need `changed_when` (and
  `check_mode: false` if they only read state that later tasks depend on).
- Playbooks target inventory groups, never addresses or single hosts.
- Pin everything: collections by exact version in `requirements.yml`, images
  by tag (and digest where verified), packages and tools by version, GitHub
  Actions by commit SHA with the version in a comment. No `latest`.

## Commits

- `pre-commit install` once per clone. Hooks: YAML and whitespace checks,
  gitleaks, and `scripts/check-private-strings.sh`, which blocks strings from
  the private repo's `denylist/` in staged files and in the commit's author
  and committer identity. It fails if the denylist is missing; don't
  bypass it with `--no-verify` or `SKIP` unless the user says so.
- Commit with the identity configured in this repo (`git config user.email`).
- Writing style for anything in this repo: plain and direct, no marketing
  tone, no em dashes.
