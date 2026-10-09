# homelab

Ansible roles and playbooks for my Proxmox homelab: Debian LXC
containers running Traefik, Samba, Jellyfin with Intel GPU transcoding, and a
self-hosted AI stack (Open WebUI, a LiteLLM gateway, and a sandboxed coding
agent).

For this setup, Ansible configures containers that already exist. It does
not create them; that happens on the Proxmox host (see
[`scripts/create-ai-containers.sh`](scripts/create-ai-containers.sh) for one
example).

## What's here

| Path | Contents |
| --- | --- |
| [`roles/`](roles/) | One role per service, each with a README listing its variables |
| [`playbooks/`](playbooks/) | One playbook per service. They target inventory groups, never addresses |
| [`examples/`](examples/) | A fake inventory with every variable and vault variable the roles expect |
| [`docs/ai-stack/`](docs/ai-stack/README.md) | Design and build notes for the AI stack |
| [`scripts/`](scripts/) | Container creation script and the pre-commit denylist hook |

| Role | Purpose |
| --- | --- |
| [`baseline`](roles/baseline/README.md) | Packages, timezone, locale, optional Telegraf. Applied to every container |
| [`disable_ipv6`](roles/disable_ipv6/README.md) | Turn off IPv6 in containers with no working v6 route |
| [`docker`](roles/docker/README.md) | Docker Engine, refusing to run on the `vfs` storage driver |
| [`traefik`](roles/traefik/README.md) | Reverse proxy with wildcard certificates via Cloudflare DNS |
| [`samba`](roles/samba/README.md) | One locked-down SMB3 share |
| [`tailscale`](roles/tailscale/README.md) | Tailscale, logged in once, with a path for migrating a node's identity |
| [`jellyfin`](roles/jellyfin/README.md) | Jellyfin with an Intel GPU passed into the container |
| [`ai_stack`](roles/ai_stack/README.md) | Open WebUI and LiteLLM under Docker Compose |
| [`pi_sandbox`](roles/pi_sandbox/README.md) | A container for the Pi coding agent, reaching models only through LiteLLM |

## Code here, data elsewhere

This repo holds code only. The inventory, variables, and vault live in a
separate private repo, cloned next to this one:

```
<parent>/
  homelab/            this repo
  homelab-private/    inventory.yml, group_vars/, host_vars/, the vault
```

Ansible loads `group_vars/` and `host_vars/` from the directory the inventory
file is in, so pointing at the private inventory brings all of its variables
with it. Nothing in this repo needs to change to run it against a different
lab, and nothing about a specific lab has to be stripped out before sharing
it.

## Set up your own

1. Install the collections:

   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

2. Create your private repo from the examples:

   ```bash
   mkdir ../homelab-private
   cp -r examples/inventory.yml examples/group_vars ../homelab-private/
   ```

   Replace the addresses, domains, and names. Fill in
   `group_vars/all/vault.yml`, then encrypt it:

   ```bash
   ansible-vault encrypt ../homelab-private/group_vars/all/vault.yml
   ```

   Each role's README lists its variables, defaults, and which vault
   variables it needs. Roles fail early with a clear message when a required
   variable is missing.

3. Point Ansible at it. `ansible.cfg` here holds only portable settings, and
   Ansible reads exactly one config file, so personal settings go in
   environment variables. With [direnv](https://direnv.net/):

   ```bash
   cp .envrc.example .envrc   # adjust the paths
   direnv allow
   ```

   Without direnv, export the same variables in your shell, or pass `-i` and
   `--vault-password-file` on each run.

4. Preview, then apply:

   ```bash
   ansible-playbook playbooks/deploy-traefik.yml --check --diff
   ansible-playbook playbooks/deploy-traefik.yml
   ```

## Pre-commit hooks

```bash
pipx install pre-commit
pre-commit install
```

The hooks run YAML and whitespace checks, `gitleaks`, and
`scripts/check-private-strings.sh`. That last one reads a denylist of
identifying strings (addresses, domains, host names) from the private repo,
in `denylist/literal.txt` and `denylist/regex.txt`, and blocks any commit
whose files or author/committer identity contain one. It finds the private
repo through `HOMELAB_PRIVATE`, then `git config homelab.private`, then
`../homelab-private`, and fails if the denylist is missing. If you don't keep
one, skip it with `SKIP=check-private-strings git commit ...`.

## License

[MIT](LICENSE)
