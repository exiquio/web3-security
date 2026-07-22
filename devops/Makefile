VM_NAME = web3
MAC_ADDR = 52:54:00:11:22:33
IMAGE_DIR = /home/exiquio/Tools/OSes
IMAGE_NAME = Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
IMAGE_URL = https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/$(IMAGE_NAME)
IMAGE_DEST = $(IMAGE_DIR)/$(IMAGE_NAME)
.PHONY: all prepare up sync llm-proxy-start llm-proxy-stop destroy
all: up sync llm-proxy-start
prepare:
	@echo "Downloading Fedora Cloud Base image..."
	@mkdir -p $(IMAGE_DIR)
	@if [ ! -f $(IMAGE_DEST) ]; then curl -Lf $(IMAGE_URL) -o $(IMAGE_DEST); fi
up: prepare llm-proxy-start
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
	rsync -avz --delete --exclude=.git ~/.config/nvim/ web3@web3:~/.config/nvim/
	rsync -avz --delete ~/.local/share/nvim/site/pack/plugins/start/ web3@web3:~/.local/share/nvim/site/pack/plugins/start/
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
		'Type=simple' \
		'ExecStart=%h/.local/bin/litellm --model deepseek/deepseek-v4-flash --host 0.0.0.0 --port 4000' \
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
