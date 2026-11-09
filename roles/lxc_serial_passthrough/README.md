# lxc_serial_passthrough

Passes USB serial devices (a Zigbee or Z-Wave stick, say) into unprivileged
Proxmox containers in a way that survives the device reconnecting.

Runs on the Proxmox node, not in the container.

## Why

The usual recipe bind-mounts the device node itself:

```
lxc.mount.entry: /dev/ttyUSB0 dev/ttyUSB0 none bind,optional,create=file
```

That binds the node that existed when the container started. If the device
drops off USB and comes back (a loose cable, a bumped port, a power blip),
the kernel makes a new node and the container keeps the old, deleted one.
It shows up inside as `c---------` with a link count of 0, the app gets
`Permission denied`, and nothing recovers until the container restarts.
Proxmox's own `devN:` option has the same limit.

This role binds a directory instead, and a udev rule keeps one node in that
directory up to date. New entries in a bind-mounted directory are visible
in the container straight away, so the app's own restart loop picks the
device up again.

## What it sets up

| Where | What |
| --- | --- |
| `/etc/udev/rules.d/90-lxc-serial-passthrough.rules` | On add/remove of each device (matched by `ID_SERIAL_SHORT`), calls the helper |
| `/usr/local/sbin/lxc-serial-passthrough` | Creates or deletes the node in `<base_dir>/<name>/` |
| `/etc/tmpfiles.d/lxc-serial-passthrough.conf` | Creates `<base_dir>/<name>/` early at boot, so the mount never misses it |
| `/etc/pve/lxc/<vmid>.conf` | `lxc.cgroup2.devices.allow` for the major number, and the directory bind mount |

Inside the container the node appears at `container_path`. Pointing that at
the path the app already uses (a `/dev/serial/by-id/...` name, say) means
the app's config doesn't change.

The role never restarts a container. When it changes a container's config
it prints which ones need `pct reboot`.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `lxc_serial_passthrough_devices` | `[]` | List of devices; fields below |
| `lxc_serial_passthrough_base_dir` | `/dev/lxc-serial` | Host directory for the per-device directories. Must allow device nodes: `/dev` does, `/run` (`nodev`) doesn't |

Device fields:

| Field | Required | Description |
| --- | --- | --- |
| `name` | yes | Label; also the directory name on the host |
| `vmid` | yes | Container ID |
| `serial` | yes | `ID_SERIAL_SHORT` from `udevadm info /dev/ttyUSB0` |
| `container_path` | yes | Absolute node path in the container, under `/dev` |
| `major` | no | Major number to allow; `188` (ttyUSB) by default, `166` for ttyACM |
| `mode` | no | Node mode, `"0666"` by default. The container sees the node as `nobody:nogroup`, so a tighter mode needs an owner from the container's mapped range |
| `remove_mount_entries` | no | Host source paths of older `lxc.mount.entry` lines to drop, such as a hand-made bind of the same device. Must go in the same run: a file bind inside the new directory bind would create a stray file in the host directory |

## Example

```yaml
- hosts: pve_nodes
  roles:
    - role: lxc_serial_passthrough
      vars:
        lxc_serial_passthrough_devices:
          - name: zigbee
            vmid: 200
            serial: 0123456789abcdef0123456789abcdef
            container_path: /dev/serial/by-id/usb-Example_Dongle-if00-port0
            remove_mount_entries:
              - /dev/ttyUSB0
              - /dev/serial/by-id/usb-Example_Dongle-if00-port0
```

## Limits

- One node per device. A USB device with several serial interfaces would
  match more than once; add an interface match before using it with one.
- A VM with the same device passed through by USB takes it away from the
  host entirely, and so from the container. Only one can hold it.
