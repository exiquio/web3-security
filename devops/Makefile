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
	@echo "Syncing Neovim configuration via rsync..."
	rsync -avz --delete ~/.config/nvim/ web3@web3:~/.config/nvim/
llm-proxy-start:
	@echo "Starting LiteLLM API Proxy on Host in background..."
	@echo "Ensure DEEPSEEK_API_KEY is exported on your host!"
	nohup litellm --model deepseek/deepseek-chat --host 192.168.122.1 --port 4000 > /tmp/litellm.log 2>&1 &
	@echo "Proxy PID: $$!"
	@echo "Logs: /tmp/litellm.log"

llm-proxy-stop:
	@pkill -f "litellm --model deepseek" 2>/dev/null && echo "Proxy stopped" || echo "No proxy running"
destroy:
	@echo "Nuking the environment..."
	virsh destroy $(VM_NAME) || true
	virsh undefine $(VM_NAME) --remove-all-storage
	@rm -f "$(PWD)/web3-cloudinit.iso"
