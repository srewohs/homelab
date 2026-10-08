# samba

A single SMB share for a fixed set of users, locked down: SMB 3.1.1 minimum,
encryption required, no guest access, no NetBIOS, and an explicit list of
allowed clients.

The `hosts allow` list is meant to be redundant with a firewall rule, so two
independent things have to be wrong before the share is reachable from
somewhere it shouldn't be.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `samba_share_name` | `shared` | Share name |
| `samba_share_path` | `/srv/share` | Directory shared. Group-owned by `samba_share_group`, mode `2770` |
| `samba_share_group` | `smbshare` | Group every share user belongs to |
| `samba_share_gid` | `3000` | Its gid |
| `samba_users` | `[]`, required | List of `{name, uid, password}`. Created as system users with no shell |
| `samba_hosts_allow` | `[]`, required | Addresses or CIDRs allowed to connect |

The role asserts `samba_users` and `samba_hosts_allow` are non-empty.

### Passwords

Accounts are created with `smbpasswd` only when they don't exist yet. A
password changed in the vault does **not** propagate on a re-run, because
there is no way to test an existing hash against a new plaintext. Rotate with
`smbpasswd` on the host.

## Vault variables

One per user, referenced from `samba_users`, for example
`vault_samba_password_alice`.

## Example

```yaml
- hosts: fileshare
  roles:
    - role: samba
      vars:
        samba_users:
          - name: alice
            uid: 3000
            password: "{{ vault_samba_password_alice }}"
        samba_hosts_allow:
          - 127.0.0.1
          - 192.0.2.0/24
```
