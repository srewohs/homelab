# pi_sandbox

Sets up a container for the [Pi](https://www.npmjs.com/package/@earendil-works/pi-coding-agent)
coding agent: Node.js from NodeSource, an unprivileged `agent` user with no
sudo, and Pi configured to reach models only through the LiteLLM gateway.

Pi runs arbitrary shell commands, so the container is the blast radius. The
only secrets on it are Pi's own: a budgeted LiteLLM virtual key and,
optionally, a GitHub token.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `pi_sandbox_packages` | `git`, `tmux`, `curl`, `ca-certificates` | Base packages |
| `pi_sandbox_node_major` | `24` | NodeSource major version |
| `pi_sandbox_pi_package` | `@earendil-works/pi-coding-agent` | npm package |
| `pi_sandbox_pi_version` | pinned | Pi version |
| `pi_sandbox_user` | `agent` | Unprivileged user Pi runs as |
| `pi_sandbox_home` | `/home/<user>` | Its home |
| `pi_sandbox_npm_prefix` | `<home>/.npm-global` | Global npm prefix, owned by the user |
| `pi_sandbox_workspace` | `<home>/code` | Working directory for repos |
| `pi_sandbox_authorized_key` | controller's `~/.ssh/id_ed25519.pub` | Key allowed to log in as the user |
| `pi_sandbox_litellm_base_url` | none, required | Gateway URL, e.g. `http://ai-gateway.home.arpa:4000/v1` |
| `pi_sandbox_git_name` | none, required | Commit author name for the agent's git identity |
| `pi_sandbox_litellm_models` | `chat`, `deepseek-flash` | Aliases registered in Pi. They must exist in the gateway |

`AGENTS.md` is copied only on the first run and never overwritten, so it can
be edited by hand.

## Vault variables

| Variable | Required |
| --- | --- |
| `vault_litellm_vkey_pi` | yes. Virtual key created in the LiteLLM UI |
| `vault_git_email` | yes. Commit author email |
| `vault_pi_github_token` | no. Empty means no GitHub credentials at all |

## Example

```yaml
- hosts: pi_sandbox
  roles:
    - role: pi_sandbox
      vars:
        pi_sandbox_litellm_base_url: http://ai-gateway.home.arpa:4000/v1
        pi_sandbox_git_name: Alice Example
```
