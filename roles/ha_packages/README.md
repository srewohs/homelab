# ha_packages

Deploys Home Assistant [packages](https://www.home-assistant.io/docs/configuration/packages/)
from a directory on the control node into a Home Assistant OS VM on Proxmox,
checks the config, and reloads it without a restart. The repo copy is the
source of truth; edit there, run the playbook.

Runs on the Proxmox node that hosts the VM. Files go in through the QEMU
guest agent (`qm guest exec`), since HAOS has no API for writing files; the
config check and reloads go through the HA API from the control node.

## What a run does

1. Compares checksums of the local `*.yaml` files with the VM's copies and
   reports which differ, which match, and any files in the VM that aren't in
   the repo (reported, never touched). With `--check`, it stops there.
2. Backs up each changed file inside the VM, writes the new version.
3. Runs HA's config check, then reloads the domains in `ha_packages_reload`.
4. **If any step after the write fails, it restores the previous files,
   reloads them, and stops.** HA's config check is shallow (it passed an
   input_boolean with an invalid name); the reload is where each domain
   validates, so a failed reload rolls back too.
5. Runs `ha_packages_post_actions`, for example re-triggering an automation
   so lights match the new config.
6. With `-e ha_packages_smoke=true`, runs `ha_packages_smoke_tests`: each
   calls a service, waits, checks entity states, and prints brightness and
   colour for a visual check. Post actions run again afterwards to restore
   the live state.

Nothing happens when no file changed (except smoke tests, if asked for). The
role never restarts Home Assistant: a package that adds a new top-level
integration needs `ha core restart` once.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `ha_packages_src` | `""` | Directory of `*.yaml` package files on the control node |
| `ha_packages_vmid` | `""` | The HAOS VM's ID on this node |
| `ha_packages_dest` | `/mnt/data/supervisor/homeassistant/packages` | The packages directory as the HAOS host sees it |
| `ha_packages_url` | `""` | HA base URL, reachable from the control node |
| `ha_packages_token` | `""` | Long-lived token of an **admin** HA user (check_config and reloads need admin) |
| `ha_packages_reload` | input_boolean, template, scene, script, automation | Domains reloaded after a valid check |
| `ha_packages_post_actions` | `[]` | `{service: "domain/name", data: {}}` calls after the reload |
| `ha_packages_smoke` | `false` | Run the smoke tests |
| `ha_packages_smoke_tests` | `[]` | `{name, service, data, wait, expect: {entity_id: state}}` |

The role asserts the four required variables are set.

## Requirements

- `configuration.yaml` loads packages: `homeassistant: packages: !include_dir_named packages`
- The QEMU guest agent enabled on the VM (HAOS ships it)
- Files under about 48 KB each: they travel base64-encoded in one guest-agent
  command

## Example

```yaml
- hosts: pve_nodes
  gather_facts: false
  roles:
    - role: ha_packages
      vars:
        ha_packages_src: "{{ inventory_dir }}/ha/packages"
        ha_packages_vmid: 200
        ha_packages_url: http://homeassistant.example:8123
        ha_packages_token: "{{ vault_ha_token }}"
        ha_packages_post_actions:
          - service: automation/trigger
            data: { entity_id: automation.example }
```

```bash
ansible-playbook playbooks/deploy-ha-packages.yml --check   # what would change
ansible-playbook playbooks/deploy-ha-packages.yml
ansible-playbook playbooks/deploy-ha-packages.yml -e ha_packages_smoke=true
```
