# mosquitto

An MQTT broker from the Debian package, with password authentication and
no anonymous access. Built for a Zigbee2MQTT and Home Assistant setup, one
broker user per client.

Tested on Debian 13 LXC containers (mosquitto 2.0.21).

## What it owns

| Path | Notes |
| --- | --- |
| `/etc/mosquitto/conf.d/local.conf` | Listener, `allow_anonymous false`, password file. The stock `mosquitto.conf` is left alone |
| `/etc/mosquitto/passwd` | The users in `mosquitto_users`. Other users in the file are left alone. `root:mosquitto 0640` |

Passwords are salted, so the hash changes on every write. Instead of
rewriting the file each run, the role checks each password with a small
Python helper run inline (`files/mosquitto-check-password.py`; PBKDF2-SHA512,
the `$7$` format mosquitto 2.x writes) and calls `mosquitto_passwd` only
for users that are missing or differ. A run with nothing to change makes
no changes, and changing a password in the vault rotates it on the next
run. Any change restarts the broker; clients reconnect within seconds.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `mosquitto_listen_address` | `0.0.0.0` | Listener address. mosquitto 2.x needs one to listen beyond localhost |
| `mosquitto_port` | `1883` | Listener port |
| `mosquitto_users` | `[]` | List of `{name, password}`. Passwords from the vault, at least 16 characters |
| `mosquitto_install_clients` | `true` | Also install `mosquitto_pub` and `mosquitto_sub` |

The role asserts every user has a name and a password of at least 16
characters. Avoid `$` and `!` in passwords: the same string ends up in
YAML, the broker's file and test commands, and a mangled one looks just
like a wrong password. `openssl rand -base64 24 | tr -d '/+='` works.

## Vault variables

One per user, named however you like, for example
`vault_mosquitto_z2m_password`.

## Example

```yaml
- hosts: mqtt
  roles:
    - role: mosquitto
      vars:
        mosquitto_users:
          - name: z2m
            password: "{{ vault_mosquitto_z2m_password }}"
          - name: hass
            password: "{{ vault_mosquitto_hass_password }}"
```

## Gotchas

- Runtime errors go to `/var/log/mosquitto/mosquitto.log`, not the
  journal. `Start request repeated too quickly` is systemd's rate limiter;
  run `systemctl reset-failed mosquitto` and read the log.
- Restart, don't reload, after changing users: on SIGHUP the daemon may
  not be able to re-read the password file.
- No TLS. Fine on a trusted LAN segment; put the broker behind TLS before
  exposing it anywhere else.
