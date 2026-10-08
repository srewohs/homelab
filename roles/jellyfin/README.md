# jellyfin

Installs Jellyfin from its apt repository in an LXC container with an Intel
GPU passed through for hardware transcoding.

What it owns: apt sources (including `contrib`/`non-free` for the Intel media
driver), packages, render group membership, directory ownership, and service
state.

What it does not own:

- `/etc/jellyfin/*.xml`. Jellyfin rewrites these whenever a setting changes in
  the dashboard, so templating them would silently revert UI changes on the
  next run. `playbooks/capture-jellyfin-config.yml` copies them back into the
  inventory repo read-only instead.
- `/var/lib/jellyfin` contents. That is state; back it up with snapshots.

## Requirements

The render device must be passed into the container, for example in the
container's `.conf` on the Proxmox host:

```
dev0: /dev/dri/renderD128,gid=<render gid>
```

The gid depends on the Debian release (992 on trixie, 104 on bookworm). The
role reads the device's actual group and creates a `render` group on that gid
if nothing claims it, so a mismatch shows up as a warning rather than a
failure.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `jellyfin_render_device` | `/dev/dri/renderD128` | Must exist or the role fails early |
| `jellyfin_install_gpu_tools` | `true` | Install `vainfo` and `intel_gpu_top` for diagnostics. Jellyfin's bundled ffmpeg ships its own driver, so these don't affect transcoding |
| `jellyfin_gpu_packages` | see `defaults/main.yml` | Diagnostic packages |
| `jellyfin_enable_nonfree` | `true` | Add `contrib`/`non-free`. Needed for `intel-media-va-driver-non-free` |
| `jellyfin_service_enabled` | `true` | Enable the service at boot |
| `jellyfin_transcode_path` | `/transcode` | Transcode scratch directory, chowned to `jellyfin`. Empty string to skip |

If the transcode directory isn't owned by `jellyfin`, playback fails before
ffmpeg starts, because Jellyfin writes a marker file there first.

## Example

```yaml
- hosts: media
  roles:
    - baseline
    - tailscale
    - jellyfin
```
