# disable_ipv6

Turns IPv6 off inside a container and persists it in a sysctl file.

Useful when containers pick up a global IPv6 address from router
advertisements but have no working IPv6 route. Node/npm (Happy Eyeballs) and
Docker pulls try IPv6 first and stall on timeouts before falling back.
`net.ipv6.*` is per network namespace, so an unprivileged container can set
these for itself without touching the Proxmox host.

Disables `all`, `default`, and `eth0`.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `disable_ipv6_sysctl_file` | `/etc/sysctl.d/90-disable-ipv6.conf` | Where the settings are persisted |

## Requirements

Collection `ansible.posix`.

## Example

```yaml
- hosts: docker_hosts
  roles:
    - disable_ipv6
```
