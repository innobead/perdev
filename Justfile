# Justfile — command runner for the provisioning workflow
# Install just via Nix (included in home.nix packages), then run: just <recipe>

# Show available recipes
default:
    @just --list

# Full provisioning: all steps in one shot (idempotent — safe to re-run)
setup:
    bash setup.sh

# Remove all components installed by setup.sh (prompts for confirmation)
uninstall:
    bash uninstall.sh

# Bootstrap: install Nix and apply Home Manager (auto-detects Ubuntu vs macOS)
install:
    bash scripts/install.sh

# Install Docker CE via official apt repo — Ubuntu only
docker:
    bash scripts/docker-setup.sh

# Start Colima + verify Apple Container — macOS only
docker-mac:
    bash scripts/docker-mac-setup.sh

# Install AI tools (Claude Code, Gemini CLI, Copilot, LLM plugins, RTK)
ai:
    bash scripts/ai-tools-setup.sh

# Full setup: provision everything
all: install
    @echo ""
    @if [ "$(uname -s)" = "Darwin" ]; then \
        echo "Open a new shell, then run: just docker-mac && just ai"; \
    else \
        echo "Open a new shell, then run: just docker && just ai"; \
    fi

# Update flake inputs to latest versions
update:
    nix flake update

# Apply updated Home Manager configuration (auto-detects platform)
switch:
    @if [ "$(uname -s)" = "Darwin" ]; then \
        nix run nixpkgs#home-manager -- switch --flake .#mac --impure -v; \
    else \
        nix run nixpkgs#home-manager -- switch --flake .#ubuntu --impure -v; \
    fi

# Roll back to the previous Home Manager generation
rollback:
    home-manager generations

# List installed Home Manager generations
generations:
    home-manager generations

# Run provisioning verification inside an Ubuntu container
test-ubuntu:
    bash tests/test-ubuntu.sh

# Run test with a specific Ubuntu version (e.g. just test-ubuntu-version 22.04)
test-ubuntu-version version:
    UBUNTU_IMAGE="ubuntu:{{version}}" bash tests/test-ubuntu.sh

# Run provisioning verification directly on macOS (no container — macOS containers don't exist)
test-mac:
    bash tests/test-mac.sh

# Pull recommended local LLM models via Ollama
ollama-models:
    ollama pull llama3.2
    ollama pull deepseek-coder-v2

# Check that key tools are working
verify:
    @echo "=== Shell ==="
    @nu --version
    @carapace --version
    @echo "=== Dev tools ==="
    @go version
    @rustup show active-toolchain
    @python3 --version
    @bun --version
    @echo "=== Containers / Kubernetes ==="
    @kubectl version --client --short 2>/dev/null || kubectl version --client
    @helm version --short
    @kind version
    @tilt version
    @echo "=== Containers (platform-specific) ==="
    @if [ "$(uname -s)" = "Darwin" ]; then \
        colima status 2>/dev/null || echo "colima: not running (run: just docker-mac)"; \
        docker version --format '{{.Client.Version}}' 2>/dev/null || echo "docker: needs colima"; \
        container --version 2>/dev/null || echo "container: not installed (Apple Silicon only)"; \
    else \
        podman --version; \
        docker --version 2>/dev/null || echo "docker: not installed (run: just docker)"; \
    fi
    @echo "=== AI tools ==="
    @llm --version
    @ollama --version
    @claude --version 2>/dev/null || echo "claude: not installed (run: just ai)"
    @echo "=== Done ==="
