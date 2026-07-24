# Web3 Security Audit VM

> Reproducible, single-command Web3 security auditing environment powered by KVM, cloud-init, Ansible, and AI-assisted analysis.

Provision a disposable Fedora 44 KVM guest with a full Web3 security toolchain — Foundry, Slither, solc-select, Goose AI — all configured to route LLM requests through a host-side LiteLLM proxy. The API key never leaves the host.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│  HOST (your machine)                                               │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │  LiteLLM Proxy  (systemd --user service)                │     │
│  │  ─────────────────────────────────────────────────────  │     │
│  │  0.0.0.0:4000  ───  deepseek/deepseek-v4-flash         │     │
│  │                    ├── deepseek/deepseek-v4-pro         │     │
│  │                    └── openai/qwen3.6-flash (DashScope) │     │
│  │                        ▲ API key env var                │     │
│  └───────────────────────┬───────────────────────────────┘     │
│                          │ libvirt: 192.168.122.1:4000          │
│  ┌───────────────────────┴───────────────────────────────┐     │
│  │  GUEST VM  (Fedora 44 · KVM)                         │     │
│  │  ─────────────────────────────────────────────────── │     │
│  │  16 GB RAM · 8 vCPUs · 80 GB disk                    │     │
│  │                                                       │     │
│  │  ┌──────────────────────────────────────────────┐    │     │
│  │  │  Toolchain                                    │    │     │
│  │  │  ├── Foundry  (forge · cast · anvil)          │    │     │
│  │  │  ├── Slither  (static analysis)               │    │     │
│  │  │  ├── solc-select  (compiler version mgmt)     │    │     │
│  │  │  ├── Goose AI  (→ LiteLLM provider)          │    │     │
│  │  │  ├── Node.js / pnpm / Rust / Go / Python     │    │     │
│  │  │  └── fish + Starship prompt                  │    │     │
│  │  └──────────────────────────────────────────────┘    │     │
│  │         ▲                                            │     │
│  │         │ provisioned via:                           │     │
│  │         │ 1. cloud-init (base OS + packages)         │     │
│  │         │ 2. Ansible (toolchain + config)            │     │
│  │         │ 3. rsync (Neovim · Goose · fish funcs)   │     │
│  └──────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start

```bash
make llm-proxy-start   # one-time: start LiteLLM proxy (persists across reboots)
make all               # provision fresh VM + install everything
make sync              # push config changes to a running VM
make destroy           # tear down the VM
```

> **`make all` is always safe to run** — the proxy step is idempotent, and a stale VM is destroyed before provisioning a fresh one.

---

## Directory Structure

```
web3-security/
├── README.md                  # ← this file: project overview
├── devops/
│   ├── README.md              # detailed operational documentation
│   ├── Makefile               # provisioning targets
│   ├── playbook.yml           # Ansible playbook (toolchain install)
│   ├── litellm-config.yaml    # LLM model routing config
│   └── cloud-init/
│       ├── user-data          # cloud-init user/package config
│       ├── meta-data          # cloud-init VM metadata
│       └── network-config     # (reserved) networking overrides
└── scripts/
    ├── README.md              # script usage notes
    └── report-from-slither.exs # Slither JSON → Markdown audit report
```

> **See [`devops/README.md`](devops/README.md)** for the full operational reference — Makefile targets, proxy management, troubleshooting.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **KVM / libvirt** | `virt-install`, `virsh`, `virt-viewer` |
| **Ansible** | `dnf install ansible` or `pip install ansible` |
| **SSH key** | Default: `~/.ssh/id_ed25519` (adjust in `cloud-init/user-data` if needed) |
| **DeepSeek API key** | Exported as `DEEPSEEK_API_KEY` in your shell |
| **DashScope API key** | (Optional) Exported as `DASHSCOPE_API_KEY` for Qwen model |
| **sudo access** | Needed once for `firewall-cmd` during `make llm-proxy-start` |

---

## LLM Models

The LiteLLM proxy (configured in [`devops/litellm-config.yaml`](devops/litellm-config.yaml)) exposes three models:

| Model ID | Provider | Use Case |
|---|---|---|
| `deepseek-v4-flash` | DeepSeek | Fast, cost-effective for routine analysis |
| `deepseek-v4-pro` | DeepSeek | Deep reasoning, complex vulnerability analysis |
| `qwen3.6-flash` | Alibaba DashScope | Supplementary model (multi-language, alternative reasoning) |

The guest VM's Goose AI is pre-configured with the `LiteLLM` provider, pointing at `http://192.168.122.1:4000` (the host via libvirt gateway). **No API keys are stored on the guest.**

---

## Workflow

### 1. Start the LLM proxy (once per host session, survives reboots)

```bash
make llm-proxy-start
```

Installs the LiteLLM systemd user service, opens port 4000 in the libvirt firewall, and starts proxying. Subsequent `make all` runs will skip this step.

### 2. Provision a fresh VM

```bash
make all
```

Destroys any existing `web3` VM, downloads the Fedora 44 Cloud image (if missing), boots the guest with cloud-init, waits for SSH, runs the Ansible playbook, and syncs Neovim/Goose/fish configs.

### 3. Audit

SSH into the guest (`ssh web3@web3`) and use the toolchain:

```bash
forge build
slither . --json results.json
elixir ~/scripts/report-from-slither.exs results.json > audit-report.md
goose run
```

### 4. Sync changed configs

```bash
make sync
```

Pushes Neovim config, Goose profiles, fish functions, and audit scripts from the host to the running VM without rebuilding.

### 5. Tear down

```bash
make destroy
```

Nukes the VM and its disk. The LLM proxy continues running and can be reused on the next `make all`.

---

## Security Note

**The API key stays on the host at all times.** The host runs a LiteLLM proxy bound to `0.0.0.0:4000`. The guest connects to it over the libvirt isolated network (`192.168.122.0/24`). The guest's Goose CLI is configured with the `LiteLLM` provider — no actual API keys are ever copied into the VM. The `DEEPSEEK_API_KEY` environment variable is stored in `~/.config/environment.d/deepseek.conf` on the host (mode 0600), read by the systemd service.

---

## What's Inside the Guest

| Category | Tools |
|---|---|
| **Ethereum** | Foundry (`forge`, `cast`, `anvil`), `solc-select` |
| **Static Analysis** | Slither (Python), custom Elixir report generator |
| **AI Assistant** | Goose AI (LiteLLM provider → host proxy) |
| **Shell** | fish + Starship prompt + audit-focused aliases |
| **Languages** | Rust (rustup), Go, Node.js (via mise), Python (uv) |
| **Package Mgmt** | mise, pnpm, uv |
| **Editing** | Neovim (Dracula Pro theme, CodeCompanion patched for proxy) |
| **Documents** | typst-cli, pandoc |
| **Code Stats** | scc (cloc-like) |

---

## Targets Reference

| Target | Action |
|---|---|
| `make all` | Proxy check + fresh VM + Ansible + config sync |
| `make up` | Fresh VM + Ansible only (proxy must be running) |
| `make sync` | rsync Neovim config, Goose profiles, fish functions, scripts |
| `make sync-goose` | Sync and adapt Goose config for LiteLLM proxy |
| `make sync-fish` | Sync and adapt fish functions for guest proxy |
| `make llm-proxy-start` | Install/enable LiteLLM systemd service |
| `make llm-proxy-stop` | Stop the LiteLLM service |
| `make destroy` | Nuke VM (disk + definition) |
| `make prepare` | Download Fedora Cloud image (idempotent) |

---

## See Also

- [`devops/README.md`](devops/README.md) — detailed operational docs, proxy management, troubleshooting
- [`scripts/report-from-slither.exs`](scripts/report-from-slither.exs) — Slither JSON-to-Markdown report converter (Elixir)
