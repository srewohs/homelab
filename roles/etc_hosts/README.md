# etc_hosts

Pins names to addresses in `/etc/hosts`, so they resolve even when DNS
doesn't. Useful for anything a scheduled job can't do without: a backup
server, for example, whose name a public fallback resolver doesn't know.

Each entry is one line, identified by its first name. A line that already
has that name, added by hand for example, is replaced in place, not
duplicated. Lines the role doesn't manage are left alone, and removing an
entry from the list leaves its line in the file.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `etc_hosts_entries` | `[]` | List of `{ip, names}`; `names` is a list, the first one identifies the line |

The role asserts that every entry has `ip` and a list of `names`.

### Proxmox VE notes

- On a node, `/etc/hosts` is an ordinary file and stays as written.
- In a container, Proxmox rewrites `/etc/hosts` at each start unless
  `/etc/.pve-ignore.hosts` exists, so entries added there don't last.

## Example

```yaml
- hosts: pve_nodes
  roles:
    - role: etc_hosts
      vars:
        etc_hosts_entries:
          - ip: 192.0.2.11
            names: [pbs.home.arpa, pbs]
```
