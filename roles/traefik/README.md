# traefik

Installs Traefik as a systemd service (binary release, not Docker) and
configures it as a reverse proxy with wildcard certificates from Let's Encrypt
via the Cloudflare DNS challenge.

Each entry in `traefik_services` is routed as `<name>.<domain>` for every
domain in `traefik_base_domains`. The dashboard is at `traefik.<domain>`.
HTTP redirects to HTTPS.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `traefik_version` | pinned in `defaults/main.yml` | Release to install from GitHub |
| `traefik_acme_staging` | `false` | Use the Let's Encrypt staging CA while testing |
| `traefik_acme_email` | none, required | Let's Encrypt account email |
| `traefik_base_domains` | none, required | Domains to serve. Each gets a wildcard certificate |
| `traefik_services` | none, required | List of `{name, url}` backends |

The role asserts the required variables are set.

## Vault variables

| Variable | Required |
| --- | --- |
| `vault_cloudflare_dns_api_token` | yes. A Cloudflare API token with `Zone:DNS:Edit` on the domains |

## Example

```yaml
- hosts: proxy
  roles:
    - role: traefik
      vars:
        traefik_acme_email: admin@example.com
        traefik_base_domains:
          - example.com
        traefik_services:
          - name: jellyfin
            url: http://jellyfin.home.arpa:8096
          - name: chat
            url: http://ai-gateway.home.arpa:3000
```
