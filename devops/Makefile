VM_NAME = web3
MAC_ADDR = 52:54:00:11:22:33
IMAGE_DIR = /home/exiquio/Tools/OSes
IMAGE_NAME = Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
IMAGE_URL = https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/$(IMAGE_NAME)
IMAGE_DEST = $(IMAGE_DIR)/$(IMAGE_NAME)
.PHONY: all prepare up sync sync-goose sync-fish llm-proxy-start llm-proxy-stop destroy
all: up sync sync-goose llm-proxy-start
prepare:
	@echo "Downloading Fedora Cloud Base image..."
	@mkdir -p $(IMAGE_DIR)
	@if [ ! -f $(IMAGE_DEST) ]; then curl -Lf $(IMAGE_URL) -o $(IMAGE_DEST); fi
up: prepare
	@echo "Destroying existing VM if present..."
	@virsh destroy $(VM_NAME) 2>/dev/null || true
	@virsh undefine $(VM_NAME) --remove-all-storage 2>/dev/null || true
	@echo "Provisioning KVM Instance..."
	virt-install \
		--name $(VM_NAME) \
		--memory 16384 \
		--vcpus 8 \
		--disk size=80,backing_store=$(IMAGE_DEST),bus=virtio \
		--network network=default,model=virtio,mac=$(MAC_ADDR) \
		--os-variant fedora43 \
		--graphics none \
		--cloud-init user-data=cloud-init/user-data,meta-data=cloud-init/meta-data,disable=on \
		--import \
		--noautoconsole
	@echo "Waiting for SSH to become available..."
	@while ! ssh -q web3@web3 exit 2>/dev/null; do sleep 2; done
	@echo "Applying Ansible Configuration..."
	ansible-playbook -i "web3," playbook.yml
sync:
	@echo "Syncing Neovim configuration..."
	ssh web3 mkdir -p /home/web3/.config/nvim /home/web3/.local/share/nvim/site/pack/plugins/start
	rsync -avz --delete --exclude=.git ~/Code/Personal/nvim-configs/ web3@web3:~/.config/nvim/
	@echo "  Syncing dracula_pro theme..."
	rsync -avz --delete --exclude=.git ~/.local/share/nvim/site/pack/plugins/start/dracula_pro/ web3@web3:~/.local/share/nvim/site/pack/plugins/start/dracula_pro/
	@echo "  Patching codecompanion for guest proxy..."
	@ssh web3 'sed -i \
		-e "s|DEEPSEEK_API_KEY|sk-dummy-key-does-not-matter|" \
		-e "/extend(\"deepseek\", {/a\\            url = \"http://192.168.122.1:4000/v1/chat/completions\"," \
		~/.config/nvim/lua/custom/plugins/codecompanion.lua'
	@echo "  Syncing scripts..."
	@ssh web3 mkdir -p /home/web3/scripts
	rsync -avz --delete --exclude=.expert --chmod=u=rwx,go=rx ~/Code/Personal/web3-security/scripts/ web3@web3:~/scripts/
	@echo "  Done."
	@$(MAKE) sync-goose
	@$(MAKE) sync-fish

sync-goose:
	@# Ensure host symlinks are in place
	@test -f $(HOME)/Code/Personal/goose-configs/Makefile && \
		$(MAKE) -C $(HOME)/Code/Personal/goose-configs install || true
	@echo "Syncing Goose configuration..."
	@echo "  Creating config directories..."
	@ssh web3 mkdir -p /home/web3/.config/goose /home/web3/.agents/agents
	@echo "  Syncing agent profiles..."
	@rsync -avz --delete /home/exiquio/Code/Personal/goose-configs/agents/ web3@web3:~/.agents/agents/
	@echo "  Syncing recipes..."
	@rsync -avz --delete /home/exiquio/Code/Personal/goose-configs/recipes/ web3@web3:~/.config/goose/recipes/
	@echo "  Syncing goosehints..."
	@rsync -avz /home/exiquio/Code/Personal/goose-configs/goosehints web3@web3:~/.config/goose/goosehints
	@echo "  Syncing guardrails.md..."
	@rsync -avz /home/exiquio/Code/Personal/goose-configs/guardrails.md web3@web3:~/.config/goose/guardrails.md
	@echo "  Syncing and adapting config.yaml for litellm proxy..."
	@sed 's/^active_provider: custom_deepseek/active_provider: litellm/; s/^  custom_deepseek:/  litellm:/; s/model: deepseek-v4-pro[[:space:]]*$$/model: deepseek\/deepseek-v4-pro/' /home/exiquio/Code/Personal/goose-configs/config.yaml | ssh web3 'cat > ~/.config/goose/config.yaml'
	@echo "  Syncing permission.yaml..."
	@rsync -avz /home/exiquio/Code/Personal/goose-configs/permission.yaml web3@web3:~/.config/goose/permission.yaml
	@echo "  Syncing NotebookLM MCP auth..."
	@ssh web3 mkdir -p /home/web3/.notebooklm-mcp-cli/profiles/default
	@test -f /home/exiquio/.notebooklm-mcp-cli/profiles/default/cookies.json && rsync -avz /home/exiquio/.notebooklm-mcp-cli/profiles/default/ web3@web3:~/.notebooklm-mcp-cli/profiles/default/
	@test -f /home/exiquio/.notebooklm-mcp-cli/chrome-port-map.json && rsync -avz /home/exiquio/.notebooklm-mcp-cli/chrome-port-map.json web3@web3:~/.notebooklm-mcp-cli/chrome-port-map.json
	@echo "  Validating VM config..."
	@ssh web3 'grep -q "active_provider: litellm" ~/.config/goose/config.yaml && grep -q "model: deepseek/deepseek-v4-pro" ~/.config/goose/config.yaml' || { echo "  ✗ FAILED: config.yaml transform did not apply correctly!"; exit 1; }
	@echo "  ✓ VM config validated"
	@echo "  Done."

sync-fish:
	@echo "Syncing fish functions..."
	@echo "  Adapting for VM (litellm provider)..."
	@ssh web3 mkdir -p /home/web3/.config/fish/functions
	@sed -e 's/set -lx GOOSE_PROVIDER custom_deepseek/set -lx GOOSE_PROVIDER litellm/' \
	     -e 's/set -lx GOOSE_MODEL deepseek-v4-pro/set -lx GOOSE_MODEL deepseek\/deepseek-v4-pro/' \
	     -e 's|cat ~/.config/goose/guardrails.md ~/Code/Personal/goose-configs/STATE.md > /tmp/goose-moim-context.txt|cat ~/.config/goose/guardrails.md > /tmp/goose-moim-context.txt|' \
	     /home/exiquio/Code/Personal/fish-functions/agentic-team.fish | \
	     ssh web3 'cat > ~/.config/fish/functions/agentic-team.fish'
	@echo "  Done."

LITELLM_SERVICE = $(HOME)/.config/systemd/user/litellm-proxy.service

$(LITELLM_SERVICE):
	@echo "Installing LiteLLM proxy systemd user service..."
	@mkdir -p $(HOME)/.config/systemd/user
	@printf '%s\n' \
		'[Unit]' \
		'Description=LiteLLM Proxy for DeepSeek' \
		'After=network-online.target' \
		'' \
		'[Service]' \
		'EnvironmentFile=%h/.config/environment.d/deepseek.conf' \
		'Type=simple' \
		'ExecStart=%h/.local/bin/litellm --config $(HOME)/Code/Personal/web3-security/devops/litellm-config.yaml --host 0.0.0.0 --port 4000' \
		'Restart=on-failure' \
		'RestartSec=5' \
		'' \
		'[Install]' \
		'WantedBy=default.target' \
		> $@
	@systemctl --user daemon-reload

llm-proxy-start: $(LITELLM_SERVICE)
	@echo "Ensuring DEEPSEEK_API_KEY is set..."
	@test -n "$$DEEPSEEK_API_KEY" || { echo "✗ DEEPSEEK_API_KEY not exported! Set it and retry."; exit 1; }
	@echo "Ensuring credential env file exists..."
	@mkdir -p $(HOME)/.config/environment.d
	@if [ ! -f $(HOME)/.config/environment.d/deepseek.conf ]; then \
		echo "DEEPSEEK_API_KEY=$$DEEPSEEK_API_KEY" > $(HOME)/.config/environment.d/deepseek.conf; \
		chmod 0600 $(HOME)/.config/environment.d/deepseek.conf; \
		echo "✓ Created $(HOME)/.config/environment.d/deepseek.conf"; \
	fi
	@echo "Opening port 4000 in libvirt firewall zone..."
	sudo firewall-cmd --zone=libvirt --add-port=4000/tcp --permanent 2>/dev/null || true
	sudo firewall-cmd --reload 2>/dev/null || true
	@echo "Ensuring litellm is installed..."
	@which litellm >/dev/null 2>&1 || uv tool install litellm[proxy]
	@echo "Starting LiteLLM proxy service..."
	systemctl --user enable --now litellm-proxy.service
	@sleep 3
	@if curl -s http://127.0.0.1:4000/v1/models > /dev/null 2>&1; then \
		echo "✓ Proxy running on http://0.0.0.0:4000"; \
		echo "  systemctl --user status litellm-proxy.service  → check status"; \
		echo "  journalctl --user -u litellm-proxy.service -f  → follow logs"; \
	else \
		echo "✗ Proxy failed to start. Check logs:"; \
		journalctl --user -u litellm-proxy.service --no-pager -n 10; \
	fi

llm-proxy-stop:
	@systemctl --user stop litellm-proxy.service 2>/dev/null && echo "Proxy stopped" || echo "No proxy running"
destroy:
	@echo "Nuking the environment..."
	virsh destroy $(VM_NAME) || true
	virsh undefine $(VM_NAME) --remove-all-storage
	@rm -f "$(PWD)/web3-cloudinit.iso"
