# ha_custom_components

Installs Home Assistant custom integrations (`custom_components`) pinned to a
release zip and its sha256: HACS as code. Upgrading is a version bump in
inventory and a playbook run, and the repo says exactly what's installed.

Runs on the Proxmox node hosting a Home Assistant OS VM. The download,
checksum and unpack happen inside the HA container (its own python, no extra
tools), reached through the QEMU guest agent.

## What a run does

1. For each component, compares the installed version (a marker file the
   role writes) with the pinned one. With `--check`, it stops at reporting.
2. Downloads the zip inside the HA container, verifies the sha256, refuses
   paths that would escape the target, requires `manifest.json` at the top,
   and swaps it into `/config/custom_components/<name>`. The previous version
   is kept as `.<name>.previous`.
3. If anything was installed: restarts HA core, waits for the API, removes
   the previous versions.
4. Reports whether a newer stable release exists upstream (read-only GitHub
   API call). It never upgrades by itself.

Configuring the integration (logins, devices) stays in the HA UI: most custom
integrations only support UI config entries, which HA keeps in its storage.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `ha_custom_components` | `[]` | List of `{name, version, url, sha256, repo}`; `repo` (owner/name) is optional, for the upstream check |
| `ha_custom_components_vmid` | `""` | The HAOS VM's ID on this node |
| `ha_custom_components_container` | `homeassistant` | The HA core container |
| `ha_custom_components_url` | `""` | HA base URL, to wait for the API after a restart |
| `ha_custom_components_token` | `""` | HA long-lived token |
| `ha_custom_components_check_upstream` | `true` | Report newer releases |

The role asserts names are `a-z0-9_`, URLs are https and checksums are 64
hex characters.

## Requirements

- The release asset is a zip with the integration's files at the top level
  (HACS `zip_release` style). Repos that only ship source archives need a
  different layout; check before pinning.
- Internet access from the HA container to the download URL.

## Example

```yaml
ha_custom_components:
  - name: example_integration
    version: v1.2.3
    url: https://github.com/owner/repo/releases/download/v1.2.3/example.zip
    sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
    repo: owner/repo
```
