.PHONY: help setup launch deploy build-rust build-android clean

# Colors
BOLD := \033[1m
RESET := \033[0m
CYAN := \033[36m
YELLOW := \033[33m
GRAY := \033[90m

##@ help
help: ## Show this help message
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  $(BOLD)Amaru Wear$(RESET)                                                      ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  $(CYAN)help$(RESET)                  Show this help message"
	@echo ""
	@echo "$(BOLD)Setup$(RESET)"
	@echo "  $(CYAN)setup$(RESET)                 Initialize project environment (Java, Rust, Android SDK, NDK)"
	@echo ""
	@echo "$(BOLD)Development$(RESET)"
	@echo "  $(CYAN)launch$(RESET)                Build and launch APK on emulator"
	@echo ""
	@echo "$(BOLD)Deployment$(RESET)"
	@echo "  $(CYAN)deploy$(RESET)                Build and deploy APK to real WearOS watch"
	@echo ""
	@echo "$(BOLD)Build$(RESET)"
	@echo "  $(CYAN)build-rust$(RESET)            Build Rust library for Android targets"
	@echo "  $(CYAN)build-android$(RESET)         Build Debug Android APK"
	@echo ""
	@echo "$(BOLD)Maintenance$(RESET)"
	@echo "  $(CYAN)clean$(RESET)                 Remove all build artifacts"
	@echo ""

##@ setup
setup: ## Initialize project environment (Java, Rust, Android SDK, NDK)
	./scripts/setup.sh

##@ development
launch: setup ## Build and launch APK on emulator
	./scripts/build-and-launch.sh

launch-clean: setup ## Build and launch APK on emulator, clearing ledger/consensus files
	./scripts/build-and-launch.sh --clear-data

##@ deployment
deploy: setup ## Build and deploy APK to real WearOS watch
	./scripts/build-and-deploy.sh

##@ build
build-rust: ## Build Rust library for Android targets
	./scripts/build-rust.sh

##@ build
build-android: ## Build Debug Android APK
	./gradlew assembleDebug

##@ maintenance
clean: ## Remove all build artifacts
	@echo "Cleaning build artifacts..."
	./gradlew clean
	cd rust && cargo clean
	rm -rf app/src/main/jniLibs

