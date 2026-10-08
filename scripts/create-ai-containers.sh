#!/usr/bin/env bash
# Creates the two AI stack containers (gateway and Pi sandbox) on a Proxmox
# node. Run it on the Proxmox host as root. Every setting below comes from the
# environment, so keep your values in an env file and send both together:
#
#   scp ~/.ssh/id_ed25519.pub root@pve.home.arpa:/root/ai-stack.pub
#   cat my-lab.env scripts/create-ai-containers.sh | ssh root@pve.home.arpa 'bash -s'
#
# my-lab.env is plain shell, for example:
#
#   ROOTFS_STORAGE=local-zfs
#   GATEWAY=192.168.1.1
#   DNS=192.168.1.53
#   SEARCH_DOMAIN=home.arpa
#   GATEWAY_CTID=135  GATEWAY_IP=192.168.1.135
#   SANDBOX_CTID=136  SANDBOX_IP=192.168.1.136
#
# Safe to re-run: existing CTs are skipped.
set -euo pipefail

# ---- settings (check storage names with: pvesm status) --------------------
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"   # storage that holds CT templates
ROOTFS_STORAGE="${ROOTFS_STORAGE:-}"            # storage for container disks
BRIDGE="${BRIDGE:-vmbr0}"
PREFIX_LEN="${PREFIX_LEN:-24}"                  # subnet prefix length for the CT addresses
GATEWAY="${GATEWAY:-}"                          # LAN gateway (router) address
DNS="${DNS:-}"                                  # LAN DNS server
SEARCH_DOMAIN="${SEARCH_DOMAIN:-}"              # e.g. home.arpa
SSH_PUBKEY_FILE="${SSH_PUBKEY_FILE:-/root/ai-stack.pub}"
GATEWAY_CTID="${GATEWAY_CTID:-}"  GATEWAY_IP="${GATEWAY_IP:-}"
SANDBOX_CTID="${SANDBOX_CTID:-}"  SANDBOX_IP="${SANDBOX_IP:-}"
# ---------------------------------------------------------------------------

missing=()
for v in ROOTFS_STORAGE GATEWAY DNS SEARCH_DOMAIN GATEWAY_CTID GATEWAY_IP SANDBOX_CTID SANDBOX_IP; do
  [ -n "${!v}" ] || missing+=("$v")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Set these before running: ${missing[*]}" >&2
  exit 1
fi

[ -f "$SSH_PUBKEY_FILE" ] || { echo "Missing $SSH_PUBKEY_FILE (scp your public key first)"; exit 1; }

pveam update >/dev/null
TEMPLATE=$(pveam available --section system | awk '/debian-13-standard/ {print $2}' | sort -V | tail -1)
if [ -z "$TEMPLATE" ]; then
  echo "No Debian 13 template found, falling back to Debian 12"
  TEMPLATE=$(pveam available --section system | awk '/debian-12-standard/ {print $2}' | sort -V | tail -1)
fi
pveam list "$TEMPLATE_STORAGE" | grep -q "$TEMPLATE" || pveam download "$TEMPLATE_STORAGE" "$TEMPLATE"
echo "Using template: $TEMPLATE"

create_ct() {
  local id=$1 ip=$2 name=$3 cores=$4 mem=$5 disk=$6 features=$7
  if pct status "$id" &>/dev/null; then
    echo "CT $id already exists, skipping"
    return
  fi
  pct create "$id" "$TEMPLATE_STORAGE:vztmpl/$TEMPLATE" \
    --hostname "$name" \
    --unprivileged 1 \
    --features "$features" \
    --cores "$cores" --memory "$mem" --swap 512 \
    --rootfs "$ROOTFS_STORAGE:$disk" \
    --net0 "name=eth0,bridge=$BRIDGE,ip=$ip/$PREFIX_LEN,gw=$GATEWAY" \
    --nameserver "$DNS" --searchdomain "$SEARCH_DOMAIN" \
    --ssh-public-keys "$SSH_PUBKEY_FILE" \
    --onboot 1 --start 1
  echo "Created CT $id ($name)"
  sleep 5
  # Snapshot as an undo point before any automation touches it.
  pct snapshot "$id" fresh --description "Clean install, before Ansible/Claude" \
    || echo "Snapshot failed for CT $id (storage may not support snapshots)"
}

# id              ip              name       cores mem(MB) disk(GB) features
create_ct "$GATEWAY_CTID" "$GATEWAY_IP" ai-gateway 4     4096    32       "nesting=1,keyctl=1"   # Docker host
create_ct "$SANDBOX_CTID" "$SANDBOX_IP" pi-sandbox 2     4096    32       "nesting=1"            # Pi agent

echo
echo "Done. Check from your workstation:"
echo "  ssh root@$GATEWAY_IP hostname"
echo "  ssh root@$SANDBOX_IP hostname"
