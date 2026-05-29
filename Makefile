# ============================================================
#  Local Development Setup — Docker + Kubernetes
#
#  Tool choices:
#    - Rancher Desktop  : container runtime (dockerd) + k3s Kubernetes
#                         fully open-source, no licensing restrictions
#    - kubectl          : Kubernetes CLI
#    - helm             : Kubernetes package manager
#    - k9s              : terminal UI for cluster management
#    - kubectx / kubens : fast context and namespace switching
#
#  Supported platforms: macOS (Homebrew), Ubuntu/Debian, RHEL/Fedora
# ============================================================

.DEFAULT_GOAL := help

OS   := $(shell uname -s)
ARCH := $(shell uname -m)

# ── Colours ──────────────────────────────────────────────────────────────────
BOLD  := \033[1m
GREEN := \033[0;32m
CYAN  := \033[0;36m
RESET := \033[0m

# ── Helpers ──────────────────────────────────────────────────────────────────
define log
	@printf "$(CYAN)$(BOLD)▶ $(1)$(RESET)\n"
endef

define ok
	@printf "$(GREEN)$(BOLD)✔ $(1)$(RESET)\n"
endef

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@printf "\nUsage: make <target>\n\n"
	@printf "$(BOLD)Targets:$(RESET)\n"
	@printf "  $(CYAN)install$(RESET)           Install all tools (Rancher Desktop + kubectl + helm + extras)\n"
	@printf "  $(CYAN)install-rancher$(RESET)   Install Rancher Desktop (container runtime + Kubernetes)\n"
	@printf "  $(CYAN)install-kubectl$(RESET)   Install kubectl\n"
	@printf "  $(CYAN)install-helm$(RESET)      Install Helm\n"
	@printf "  $(CYAN)install-extras$(RESET)    Install k9s, kubectx, kubens\n"
	@printf "  $(CYAN)verify$(RESET)            Verify installed tools and print versions\n"
	@printf "  $(CYAN)help$(RESET)              Show this message\n\n"

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: install
install: install-rancher install-kubectl install-helm install-extras verify
	$(call ok,All tools installed successfully)

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: install-rancher
install-rancher:
	$(call log,Installing Rancher Desktop …)
ifeq ($(OS),Darwin)
	@brew install --cask rancher 2>/dev/null || (brew upgrade --cask rancher && printf "already up-to-date\n")
else ifeq ($(OS),Linux)
	@if command -v apt-get >/dev/null 2>&1; then \
		$(MAKE) _install-rancher-deb; \
	elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then \
		$(MAKE) _install-rancher-rpm; \
	else \
		printf "Unsupported Linux package manager. Install Rancher Desktop manually:\n"; \
		printf "  https://rancherdesktop.io\n"; \
		exit 1; \
	fi
else
	@printf "Windows detected — download the installer from https://rancherdesktop.io\n"
	@exit 1
endif
	$(call ok,Rancher Desktop installed)

.PHONY: _install-rancher-deb
_install-rancher-deb:
	@printf "Adding Rancher Desktop apt repository …\n"
	@curl -fsSL https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/Release.key \
		| gpg --dearmor \
		| sudo install -o root -g root -m 644 /dev/stdin \
		  /usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg
	@echo 'deb [signed-by=/usr/share/keyrings/isv-rancher-stable-archive-keyring.gpg] https://download.opensuse.org/repositories/isv:/Rancher:/stable/deb/ ./' \
		| sudo tee /etc/apt/sources.list.d/isv-rancher-stable.list > /dev/null
	@sudo apt-get update -qq
	@sudo apt-get install -y rancher-desktop

.PHONY: _install-rancher-rpm
_install-rancher-rpm:
	@printf "Adding Rancher Desktop RPM repository …\n"
	@sudo zypper addrepo \
		https://download.opensuse.org/repositories/isv:/Rancher:/stable/rpm/isv:Rancher:stable.repo \
		2>/dev/null || true
	@if command -v dnf >/dev/null 2>&1; then \
		sudo dnf config-manager --add-repo \
			https://download.opensuse.org/repositories/isv:/Rancher:/stable/rpm/isv:Rancher:stable.repo \
			2>/dev/null || true; \
		sudo dnf install -y rancher-desktop; \
	else \
		sudo yum install -y rancher-desktop; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: install-kubectl
install-kubectl:
	$(call log,Installing kubectl …)
ifeq ($(OS),Darwin)
	@brew install kubectl 2>/dev/null || brew upgrade kubectl
else ifeq ($(OS),Linux)
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get install -y apt-transport-https ca-certificates curl gnupg; \
		curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
			| gpg --dearmor \
			| sudo tee /usr/share/keyrings/kubernetes-apt-keyring.gpg > /dev/null; \
		echo 'deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
			| sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null; \
		sudo apt-get update -qq; \
		sudo apt-get install -y kubectl; \
	elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then \
		cat <<'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null; \
[kubernetes]\n\
name=Kubernetes\n\
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/\n\
enabled=1\n\
gpgcheck=1\n\
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key\n\
EOF\n\
		if command -v dnf >/dev/null 2>&1; then sudo dnf install -y kubectl; else sudo yum install -y kubectl; fi; \
	fi
endif
	$(call ok,kubectl installed)

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: install-helm
install-helm:
	$(call log,Installing Helm …)
ifeq ($(OS),Darwin)
	@brew install helm 2>/dev/null || brew upgrade helm
else ifeq ($(OS),Linux)
	@curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
endif
	$(call ok,Helm installed)

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: install-extras
install-extras:
	$(call log,Installing extras: k9s, kubectx, kubens …)
ifeq ($(OS),Darwin)
	@brew install k9s kubectx 2>/dev/null || brew upgrade k9s kubectx
else ifeq ($(OS),Linux)
	@if command -v brew >/dev/null 2>&1; then \
		brew install k9s kubectx; \
	else \
		printf "Installing k9s via snap (if available) or direct download …\n"; \
		if command -v snap >/dev/null 2>&1; then \
			sudo snap install k9s 2>/dev/null || true; \
		else \
			K9S_VER=$$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
			curl -fsSL "https://github.com/derailed/k9s/releases/download/$${K9S_VER}/k9s_Linux_$(ARCH).tar.gz" \
				| sudo tar -xz -C /usr/local/bin k9s; \
		fi; \
		KUBECTX_VER=$$(curl -fsSL https://api.github.com/repos/ahmetb/kubectx/releases/latest | grep '"tag_name"' | cut -d'"' -f4); \
		curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/$${KUBECTX_VER}/kubectx_$${KUBECTX_VER}_linux_x86_64.tar.gz" \
			| sudo tar -xz -C /usr/local/bin kubectx; \
		curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/$${KUBECTX_VER}/kubens_$${KUBECTX_VER}_linux_x86_64.tar.gz" \
			| sudo tar -xz -C /usr/local/bin kubens; \
	fi
endif
	$(call ok,Extras installed)

# ─────────────────────────────────────────────────────────────────────────────
.PHONY: verify
verify:
	$(call log,Verifying installed tools …)
	@printf "\n"
	@for cmd in docker kubectl helm k9s kubectx kubens; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			printf "  $(GREEN)✔$(RESET) %-12s %s\n" "$$cmd" "$$($$cmd version --short 2>/dev/null || $$cmd version 2>/dev/null | head -1 || $$cmd --version 2>/dev/null | head -1)"; \
		else \
			printf "  $(BOLD)✘$(RESET) %-12s not found\n" "$$cmd"; \
		fi; \
	done
	@printf "\n"
	@printf "$(BOLD)Note:$(RESET) Start Rancher Desktop and enable 'dockerd (moby)' in Preferences → Container Engine\n"
	@printf "      to make the 'docker' CLI available. Kubernetes (k3s) starts automatically.\n\n"
