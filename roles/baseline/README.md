# baseline

Applied to every container: base packages, timezone, locale, and an optional
Telegraf agent. Keep it universal. If a task needs a `when:` for half your
hosts, it belongs in a service role.

Tested on Debian 12 and 13 LXC containers.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `baseline_timezone` | `Etc/UTC` | Zone name under `/usr/share/zoneinfo` |
| `baseline_locale` | `en_US.UTF-8` | Locale enabled in `/etc/locale.gen` |
| `baseline_packages` | see `defaults/main.yml` | Installed everywhere. Includes `python3-debian`, which `deb822_repository` needs |
| `baseline_telegraf_enabled` | `false` | Install and run Telegraf |
| `baseline_telegraf_influx_url` | `""` | InfluxDB v2 URL. Required when Telegraf is enabled |
| `baseline_telegraf_influx_org` | `homelab` | InfluxDB organization |
| `baseline_telegraf_influx_bucket` | `telegraf` | InfluxDB bucket |
| `baseline_telegraf_influx_token` | `vault_influx_token` | Write token. Required when Telegraf is enabled |

The role asserts the URL and token are set before installing Telegraf.

## Vault variables

| Variable | Required |
| --- | --- |
| `vault_influx_token` | only when `baseline_telegraf_enabled` is true |

## Example

```yaml
- hosts: all
  roles:
    - role: baseline
      vars:
        baseline_timezone: America/New_York
```
