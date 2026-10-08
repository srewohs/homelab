# ai_stack

Runs Open WebUI and a LiteLLM gateway (with its Postgres database) under
Docker Compose. LiteLLM holds the real provider keys. Open WebUI and any other
client only get budgeted LiteLLM virtual keys.

The full design, build order, and security notes are in
[`docs/ai-stack/`](../../docs/ai-stack/README.md).

## Requirements

The `docker` role (or an existing Docker Engine with the compose plugin), and
collection `community.docker`.

## Variables

| Variable | Default | Description |
| --- | --- | --- |
| `ai_stack_dir` | `/opt/ai-stack` | Compose project directory |
| `ai_stack_open_webui_image` | pinned tag | Open WebUI image |
| `ai_stack_open_webui_port` | `3000` | Host port for Open WebUI |
| `ai_stack_open_webui_url` | none, required | Public URL, e.g. `https://chat.example.com` |
| `open_webui_enable_signup` | `false` | Open WebUI also stores this in its database after first launch |
| `ai_stack_open_webui_api_base_url` | `http://litellm:4000/v1` | Open WebUI talks to LiteLLM over the compose network |
| `ai_stack_litellm_image` | pinned tag and digest | See the comment in `defaults/main.yml` for how to bump it |
| `ai_stack_litellm_port` | `4000` | Host port for LiteLLM, reachable on the LAN |
| `ai_stack_litellm_db_image` | pinned tag | Postgres image |
| `ai_stack_litellm_disable_env_credential_login` | `false` | Refuse Admin UI sign-in with the master key. Set `true` once a `proxy_admin` user with a password exists; otherwise nobody can sign in. API calls with the master key are unaffected |
| `litellm_chat_model` | OpenRouter slug | Model behind the `chat` alias |
| `ai_stack_litellm_deepseek_flash_model` | OpenRouter slug | Model behind `deepseek-flash` |
| `ai_stack_litellm_deepseek_direct_model` | DeepSeek slug | Used only when a DeepSeek key is set |

There are no fallbacks between aliases, on purpose. See the comment in
`templates/litellm/config.yaml.j2`.

## Vault variables

| Variable | Required |
| --- | --- |
| `vault_webui_secret_key` | yes. Random; keeps logins valid across restarts |
| `vault_openrouter_key_gateway` | yes |
| `vault_litellm_master_key` | yes. Must start with `sk-` |
| `vault_litellm_salt_key` | yes. Encrypts stored credentials; set once, never change |
| `vault_litellm_db_password` | yes |
| `vault_litellm_vkey_webui` | yes. Virtual key created in the LiteLLM UI |
| `vault_deepseek_api_key` | no. Empty skips the direct DeepSeek alias |

## Example

```yaml
- hosts: ai_gateway
  roles:
    - docker
    - role: ai_stack
      vars:
        ai_stack_open_webui_url: https://chat.example.com
```
