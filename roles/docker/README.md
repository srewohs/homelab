# docker

Installs Docker Engine and the compose plugin from Docker's apt repository,
then fails if Docker fell back to an unsuitable storage driver.

The check matters in LXC: when no overlay-capable driver works (historically a
ZFS-backed rootfs before ZFS 2.2), Docker falls back to `vfs`, which copies
every image layer in full and fills the disk. The role stops instead of
running on it.

The container needs `nesting=1,keyctl=1` in its Proxmox features.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `docker_packages` | `docker-ce`, `docker-ce-cli`, `containerd.io`, buildx, compose plugins | Packages to install |
| `docker_allowed_storage_drivers` | `overlay2`, `overlayfs` | Drivers accepted by the check. `overlayfs` is what the containerd image store reports |

## Example

```yaml
- hosts: docker_hosts
  roles:
    - docker
```
