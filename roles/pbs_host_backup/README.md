# pbs_host_backup

Backs up directories on a host (for example a Proxmox VE node's data
pools and `/etc`) to Proxmox Backup Server with `proxmox-backup-client`,
from a systemd timer. Guest backups (`vzdump`) never include bind mounts,
so data served into containers from the host needs a job like this one.

What it installs:

- `/etc/pbs-host-backup/env` (mode `0600`): repository, token secret,
  certificate fingerprint and the optional failure webhook.
- `/usr/local/sbin/pbs-host-backup`: the backup command. Safe to run by
  hand; it reads the env file itself.
- `pbs-host-backup.service` and `.timer`, plus `pbs-host-backup-failed.service`,
  which posts to a Discord-compatible webhook when a run fails (only when
  `pbs_host_backup_failure_webhook` is set).

Retention, verify and garbage collection are not set here: configure them
on the PBS side (a prune job on the datastore or namespace).

## Requirements

- A Debian-based host with `proxmox-backup-client` available from apt.
  Proxmox VE nodes have it already.
- On PBS: a user and API token with `DatastoreBackup` on the datastore (or
  the namespace), and the namespace created if you use one. Backup-only
  permissions mean a compromised host can't delete its own backups.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `pbs_host_backup_repository` | `""`, required | `user@realm!token@host:datastore` |
| `pbs_host_backup_token_secret` | `""`, required | The API token's secret. From the vault |
| `pbs_host_backup_fingerprint` | `""` | PBS certificate SHA-256 fingerprint, for a self-signed certificate |
| `pbs_host_backup_namespace` | `""` | Namespace on the datastore. Empty is the root namespace |
| `pbs_host_backup_archives` | `[]`, required | List of `{name, path}`, one `.pxar` archive each. Names: letters, digits, `_`, `-` |
| `pbs_host_backup_include_dev` | `[]` | Mount points under an archive path to include. The client stays on one file system per archive unless told otherwise |
| `pbs_host_backup_keyfile` | `""` | Client-side encryption key file. Empty means unencrypted |
| `pbs_host_backup_change_detection_mode` | `metadata` | `metadata`, `data` or `legacy` |
| `pbs_host_backup_schedule` | `*-*-* 02:30:00` | systemd `OnCalendar` |
| `pbs_host_backup_failure_webhook` | `""` | Discord-compatible webhook URL for failures. From the vault |

The role asserts the three required variables, the archive names and the
change detection mode.

### Proxmox VE notes

- `/etc/pve` is a FUSE mount. Back up `/etc` with
  `pbs_host_backup_include_dev: [/etc/pve]`, or the archive holds an empty
  `pve` directory. Check with a test restore after the first run (below).
- If the node's guest backups are encrypted, its key is in
  `/etc/pve/priv/storage/<storage-id>.enc`, and pointing
  `pbs_host_backup_keyfile` at it keeps one key for everything. Keep a copy
  of that key off the node: without it, nothing can be restored.
- Schedule the job after the node's `vzdump` job.

## Testing a restore

Restore one archive to a scratch directory and compare it with the live
files. Giving the group (`host/<hostname>`) uses the latest snapshot.

```bash
set -a; . /etc/pbs-host-backup/env; set +a
proxmox-backup-client restore --ns pve-host --keyfile /etc/pve/priv/storage/pbs.enc \
  "host/$(hostname)" etc.pxar /var/tmp/restore-test/etc
diff -rq --no-dereference /etc /var/tmp/restore-test/etc
```

The copy holds the host's secrets, so delete it when done.

## Vault variables

`pbs_host_backup_token_secret` and `pbs_host_backup_failure_webhook`
should reference vault variables, for example
`vault_pbs_host_backup_token_secret` and `vault_pbs_host_backup_webhook`.

## Example

```yaml
- hosts: pve_nodes
  roles:
    - role: pbs_host_backup
      vars:
        pbs_host_backup_repository: "host@pbs!backup@pbs.home.arpa:main"
        pbs_host_backup_token_secret: "{{ vault_pbs_host_backup_token_secret }}"
        pbs_host_backup_namespace: pve-host
        pbs_host_backup_archives:
          - name: etc
            path: /etc
          - name: root
            path: /root
          - name: share
            path: /tank/share
        pbs_host_backup_include_dev:
          - /etc/pve
        pbs_host_backup_keyfile: /etc/pve/priv/storage/pbs.enc
```

To run the first backup now instead of waiting for the timer:
`systemctl start pbs-host-backup` and follow it with
`journalctl -fu pbs-host-backup`.
