# tailscale

Installs Tailscale in an LXC container and logs it in with an auth key, once.

`tailscale up` is not idempotent and re-authenticates on every run, so the
role checks `tailscale status` first and only runs it for a node that isn't
already logged in.

## Requirements

`/dev/net/tun` must be passed into the container. On the Proxmox host, add to
the container's `.conf` and restart it:

```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

The role fails early if the device is missing.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `tailscale_hostname` | `inventory_hostname` | Node name in the tailnet |
| `tailscale_authenticate` | `true` | Log in with the auth key. Set `false` when migrating an existing node's identity (see below) |
| `tailscale_authkey` | `vault_tailscale_authkey` | Auth key for new nodes |
| `tailscale_up_args` | `--hostname=... --accept-dns=false` | Extra `tailscale up` arguments. Subnet routes are deliberately not accepted: a LAN server doesn't need them |

### Migrating a node

To move a node to a new container without registering a second machine, set
`tailscale_authenticate: false` and copy `/var/lib/tailscale/tailscaled.state`
from the old container. The node is authenticated as soon as `tailscaled`
starts. Running `tailscale up` with a fresh key instead would register a new
machine and lose the old one's shares.

## Vault variables

| Variable | Required |
| --- | --- |
| `vault_tailscale_authkey` | for new nodes (`tailscale_authenticate: true`) |

## Example

```yaml
- hosts: media
  roles:
    - tailscale
```
