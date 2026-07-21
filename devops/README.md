# Web3 Security Audit VM

Reproducible, single-command provisioning of a Fedora 44 KVM guest with a full Web3 security auditing toolchain.

## Quick start

```bash
make up
```

Destroys any existing VM, creates a fresh one, waits for cloud-init, and runs Ansible. That's it.

## What's inside

| Category | Tools |
|---|---|
| Shell | zsh + Oh My Zsh |
| Languages | Rust, Go, Node.js (via mise), Python (uv) |
| Package managers | mise, pnpm, uv |
| Ethereum | Foundry (forge, cast, anvil), solc-select |
| Document processing | typst-cli, pandoc |
| Code analysis | scc |
| AI | Goose AI (configured for LiteLLM proxy) |

## Architecture

```
make up
  ├─ virt-install (KVM + cloud-init)
  │     ├─ packages: zsh, git, gcc, golang, openssl-devel, …
  │     ├─ user: web3 (wheel, passwordless sudo, SSH key)
  │     └─ dnf.conf: resilient mirror selection
  └─ ansible-playbook
        ├─ zsh, Oh My Zsh
        ├─ Rust, mise, Node.js, pnpm
        ├─ uv, scc, Goose AI
        ├─ typst-cli, pandoc
        ├─ Foundry, solc-select
        └─ LiteLLM env vars → ~/.zshrc
```

## Other targets

```bash
make sync             # rsync neovim config to guest
make llm-proxy-start  # start LiteLLM proxy on host (background)
make llm-proxy-stop   # stop LiteLLM proxy
make destroy          # nuke the VM
make all              # up + sync + llm-proxy-start
```

## Prerequisites

- `virt-install` and libvirt (KVM)
- `ansible` (for playbook)
- `litellm` + `DEEPSEEK_API_KEY` exported (for LLM proxy)
- SSH access configured (`ssh web3@web3`)
