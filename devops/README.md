# Web3 Security Audit VM

Reproducible, single-command provisioning of a Fedora 44 KVM guest with a full Web3 security auditing toolchain.

## Quick start

```bash
make all
```

Destroys any existing VM, creates a fresh one, waits for cloud-init, runs Ansible, syncs your Neovim config, and ensures the LiteLLM proxy is running. That's it.

## Architecture

```
Host (your machine)
  └─ litellm-proxy.service (systemd user service)
       ├─ Listens on 0.0.0.0:4000
       ├─ Proxies requests to DeepSeek API
       ├─ Auto-restarts on failure, survives reboots
       └─ API key never leaves the host

Guest VM (web3)
  ├─ virt-install (KVM + cloud-init)
  │     ├─ packages: fish, git, gcc, golang, openssl-devel, …
  │     ├─ user: web3 (wheel, passwordless sudo, SSH key)
  │     └─ dnf.conf: resilient mirror selection
  ├─ ansible-playbook
  │     ├─ fish shell with sane defaults
  │     ├─ Rust, mise, Node.js, pnpm
  │     ├─ uv, scc, Goose AI
  │     ├─ typst-cli, pandoc
  │     ├─ Foundry, solc-select
  │     └─ Goose config (LiteLLM provider → host proxy)
  └─ Neovim config (rsynced from host)
```

## What's inside

| Category | Tools |
|---|---|
| Shell | fish + Starship (Tokyo Night theme) + web3 audit aliases |
| Languages | Rust, Go, Node.js (via mise), Python (uv) |
| Package managers | mise, pnpm, uv |
| Ethereum | Foundry (forge, cast, anvil), solc-select |
| Document processing | typst-cli, pandoc |
| Code analysis | scc |
| AI | Goose AI → LiteLLM proxy → DeepSeek |

## Targets

```bash
make all              # everything: proxy + fresh VM + ansible + nvim sync
make up               # fresh VM + ansible only (proxy must already be running)
make sync             # rsync Neovim config and plugins to guest
make llm-proxy-start  # install and enable LiteLLM systemd user service
make llm-proxy-stop   # stop the LiteLLM proxy service
make destroy          # nuke the VM
```

`make all` is always safe to run — the proxy step is idempotent and the sync is fast.

### Routine workflow

```bash
make llm-proxy-start   # once — proxy persists across reboots and VM rebuilds
make all               # fresh VM for a new project
make sync              # push Neovim changes to a running VM
make destroy           # clean up when done
```

### Checking the proxy

```bash
systemctl --user status litellm-proxy     # service status
journalctl --user -u litellm-proxy -f     # follow logs
```

## How the proxy works

The host runs a LiteLLM proxy as a systemd user service bound to `0.0.0.0:4000`. The guest's Goose CLI is configured with the built-in LiteLLM provider, pointing at `http://192.168.122.1:4000` (the libvirt gateway). Goose connects through the proxy; the proxy forwards to DeepSeek using `DEEPSEEK_API_KEY` from the host. The API key is never exposed to the guest.

Firewall port 4000 is opened automatically in the libvirt zone by `make llm-proxy-start`.

## Prerequisites

- `virt-install` and libvirt (KVM)
- `ansible` (for playbook)
- `DEEPSEEK_API_KEY` exported in your shell environment
- `litellm` on PATH (installed automatically via `uv tool install` if missing)
- SSH access configured (`ssh web3@web3`)
- `sudo` access (for firewall-cmd, one-time per `llm-proxy-start`)