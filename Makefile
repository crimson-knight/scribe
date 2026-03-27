PROJECT_DIR := $(shell pwd)
CRYSTAL := crystal-alpha
BIN := bin/scribe

# Bridge object files
AP_BRIDGE := $(PROJECT_DIR)/lib/asset_pipeline/src/ui/native/objc_bridge.o
AP_BRIDGE_SRC := $(PROJECT_DIR)/lib/asset_pipeline/src/ui/native/objc_bridge.m
SCRIBE_BRIDGE := $(PROJECT_DIR)/src/platform/macos/ext/scribe_platform_bridge.o
SCRIBE_BRIDGE_SRC := $(PROJECT_DIR)/src/platform/macos/ext/scribe_platform_bridge.m

# crystal-audio native extensions
CA_EXT_DIR := $(PROJECT_DIR)/lib/crystal-audio/ext
# Use wildcard to pick up all crystal-audio extension objects
CA_EXT_OBJS := $(wildcard $(CA_EXT_DIR)/*.o)
# If no .o files exist yet, list them explicitly for dependency tracking
ifeq ($(CA_EXT_OBJS),)
CA_EXT_OBJS := $(CA_EXT_DIR)/block_bridge.o $(CA_EXT_DIR)/objc_helpers.o $(CA_EXT_DIR)/system_audio_tap.o $(CA_EXT_DIR)/appkit_helpers.o $(CA_EXT_DIR)/audio_write_helper.o
endif

# whisper.cpp libraries (from homebrew whisper-cpp)
WHISPER_LIB_DIR := /opt/homebrew/Cellar/whisper-cpp/1.8.3/libexec/lib
WHISPER_LIBS := -L$(WHISPER_LIB_DIR) -lwhisper \
	-Wl,-rpath,@executable_path/../Frameworks \
	-Wl,-rpath,$(WHISPER_LIB_DIR)

# Framework flags for macOS
MACOS_FRAMEWORKS := -framework AppKit -framework Foundation -framework Carbon \
	-framework AVFoundation -framework AudioToolbox -framework CoreAudio \
	-framework CoreFoundation -framework CoreMedia \
	-framework ScreenCaptureKit -framework ApplicationServices \
	-framework UserNotifications \
	-framework Metal -framework MetalKit -framework Accelerate \
	-framework ServiceManagement \
	-framework UniformTypeIdentifiers \
	-lobjc -lc++

# Full link flags for macOS
MACOS_LINK_FLAGS := $(AP_BRIDGE) $(SCRIBE_BRIDGE) $(CA_EXT_OBJS) $(WHISPER_LIBS) $(MACOS_FRAMEWORKS)

# --- Distribution variables ---
APP_NAME := Scribe
BUNDLE_ID := com.scribeapp.scribe
APP_DIR := dist/$(APP_NAME).app
DMG_NAME := $(APP_NAME)-Installer.dmg
VERSION := 1.0.0
BUILD_NUMBER := 1

# Signing identities
DEVID_APP ?= "Developer ID Application: AgentC Consulting LLC (PXDF92M2T4)"
DEVID_INST ?= "Developer ID Installer: AgentC Consulting LLC (PXDF92M2T4)"
NOTARY_PROFILE ?= scribe-notarytool

.PHONY: all setup macos macos-release ext ext-scribe ext-ap ext-audio run clean clean-all \
	bundle sign notarize dmg dist clean-dist

all: macos

# --- First-time setup ---

setup:
	shards-alpha install || true
	@# crystal-audio shard name has a hyphen but source uses underscore
	@# Crystal's require resolution needs the underscore directory
	@if [ ! -e lib/crystal_audio ]; then \
		ln -sf crystal-audio lib/crystal_audio; \
		echo "Created lib/crystal_audio symlink"; \
	fi

# --- Build targets ---

macos: ext
	$(CRYSTAL) build src/scribe.cr -o $(BIN) -Dmacos \
		--link-flags="$(MACOS_LINK_FLAGS)"

macos-release: ext
	$(CRYSTAL) build src/scribe.cr -o $(BIN) -Dmacos --release \
		--link-flags="$(MACOS_LINK_FLAGS)"

# --- Native extensions ---

ext: ext-ap ext-scribe ext-audio

# Asset Pipeline bridge
ext-ap:
	@if [ ! -f "$(AP_BRIDGE)" ]; then \
		if [ -f "$(AP_BRIDGE_SRC)" ]; then \
			echo "Compiling Asset Pipeline ObjC bridge..."; \
			clang -c "$(AP_BRIDGE_SRC)" -o "$(AP_BRIDGE)" -fno-objc-arc; \
		else \
			echo "ERROR: $(AP_BRIDGE) not found and source $(AP_BRIDGE_SRC) missing."; \
			echo "Run: clang -c <path-to-objc_bridge.m> -o $(AP_BRIDGE) -fno-objc-arc"; \
			exit 1; \
		fi \
	fi

# Scribe platform bridge
ext-scribe: $(SCRIBE_BRIDGE)

WHISPER_INCLUDE_DIR := /opt/homebrew/Cellar/whisper-cpp/1.8.3/libexec/include

$(SCRIBE_BRIDGE): $(SCRIBE_BRIDGE_SRC)
	clang -c $< -o $@ -fno-objc-arc -I$(WHISPER_INCLUDE_DIR)

# crystal-audio extensions
ext-audio:
	@if [ ! -f "$(CA_EXT_DIR)/block_bridge.o" ]; then \
		echo "Compiling crystal-audio native extensions..."; \
		cd $(PROJECT_DIR)/lib/crystal-audio && make ext; \
	fi

# --- Utilities ---

run: macos
	./$(BIN)

clean:
	rm -f $(BIN) $(BIN).dwarf $(SCRIBE_BRIDGE)

clean-all: clean
	rm -f $(AP_BRIDGE)
	cd $(PROJECT_DIR)/lib/crystal-audio && make clean 2>/dev/null || true

# === Distribution targets ===

# Crystal runtime homebrew dependencies
LIBYAML   := $(shell readlink -f /opt/homebrew/opt/libyaml/lib/libyaml-0.2.dylib)
LIBSSL    := $(shell readlink -f /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib)
LIBCRYPTO := $(shell readlink -f /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib)
LIBPCRE2  := $(shell readlink -f /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib)
LIBGC     := $(shell readlink -f /opt/homebrew/opt/bdw-gc/lib/libgc.1.dylib)

FW = $(APP_DIR)/Contents/Frameworks
EXE = $(APP_DIR)/Contents/MacOS/scribe

# Build the .app bundle structure with all dependencies
bundle: macos-release
	@echo "==> Creating .app bundle..."
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	mkdir -p "$(FW)"
	cp bin/scribe "$(EXE)"
	cp packaging/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@if [ -f public/AppIcon.icns ]; then \
		cp public/AppIcon.icns "$(APP_DIR)/Contents/Resources/AppIcon.icns"; \
	else \
		echo "Warning: public/AppIcon.icns not found — bundle will have no icon"; \
	fi
	echo -n "APPL????" > "$(APP_DIR)/Contents/PkgInfo"
	@echo "==> Bundling whisper libraries..."
	cp $(WHISPER_LIB_DIR)/libwhisper.1.8.3.dylib "$(FW)/libwhisper.1.dylib"
	cp $(WHISPER_LIB_DIR)/libggml.0.9.5.dylib "$(FW)/libggml.0.dylib"
	cp $(WHISPER_LIB_DIR)/libggml-base.0.9.5.dylib "$(FW)/libggml-base.0.dylib"
	cp $(WHISPER_LIB_DIR)/libggml-cpu.0.9.5.dylib "$(FW)/libggml-cpu.0.dylib"
	cp $(WHISPER_LIB_DIR)/libggml-metal.0.9.5.dylib "$(FW)/libggml-metal.0.dylib"
	cp $(WHISPER_LIB_DIR)/libggml-blas.0.9.5.dylib "$(FW)/libggml-blas.0.dylib"
	@echo "==> Bundling Crystal runtime libraries..."
	cp "$(LIBYAML)"   "$(FW)/libyaml-0.2.dylib"
	cp "$(LIBSSL)"    "$(FW)/libssl.3.dylib"
	cp "$(LIBCRYPTO)" "$(FW)/libcrypto.3.dylib"
	cp "$(LIBPCRE2)"  "$(FW)/libpcre2-8.0.dylib"
	cp "$(LIBGC)"     "$(FW)/libgc.1.dylib"
	@echo "==> Fixing library install names..."
	@# --- Fix whisper dylib IDs and inter-references ---
	install_name_tool -id @rpath/libwhisper.1.dylib "$(FW)/libwhisper.1.dylib"
	install_name_tool -id @rpath/libggml.0.dylib "$(FW)/libggml.0.dylib"
	install_name_tool -id @rpath/libggml-base.0.dylib "$(FW)/libggml-base.0.dylib"
	install_name_tool -id @rpath/libggml-cpu.0.dylib "$(FW)/libggml-cpu.0.dylib"
	install_name_tool -id @rpath/libggml-metal.0.dylib "$(FW)/libggml-metal.0.dylib"
	install_name_tool -id @rpath/libggml-blas.0.dylib "$(FW)/libggml-blas.0.dylib"
	@# libwhisper references all ggml libs
	install_name_tool -change @rpath/libggml.0.dylib @rpath/libggml.0.dylib "$(FW)/libwhisper.1.dylib"
	install_name_tool -change @rpath/libggml-base.0.dylib @rpath/libggml-base.0.dylib "$(FW)/libwhisper.1.dylib"
	install_name_tool -change @rpath/libggml-cpu.0.dylib @rpath/libggml-cpu.0.dylib "$(FW)/libwhisper.1.dylib"
	install_name_tool -change @rpath/libggml-metal.0.dylib @rpath/libggml-metal.0.dylib "$(FW)/libwhisper.1.dylib"
	install_name_tool -change @rpath/libggml-blas.0.dylib @rpath/libggml-blas.0.dylib "$(FW)/libwhisper.1.dylib"
	@# ggml libs reference libggml-base
	install_name_tool -change @rpath/libggml-base.0.dylib @rpath/libggml-base.0.dylib "$(FW)/libggml.0.dylib"
	install_name_tool -change @rpath/libggml-base.0.dylib @rpath/libggml-base.0.dylib "$(FW)/libggml-cpu.0.dylib"
	install_name_tool -change @rpath/libggml-base.0.dylib @rpath/libggml-base.0.dylib "$(FW)/libggml-metal.0.dylib"
	install_name_tool -change @rpath/libggml-base.0.dylib @rpath/libggml-base.0.dylib "$(FW)/libggml-blas.0.dylib"
	@# --- Fix Crystal runtime dylib IDs ---
	install_name_tool -id @rpath/libyaml-0.2.dylib "$(FW)/libyaml-0.2.dylib"
	install_name_tool -id @rpath/libssl.3.dylib "$(FW)/libssl.3.dylib"
	install_name_tool -id @rpath/libcrypto.3.dylib "$(FW)/libcrypto.3.dylib"
	install_name_tool -id @rpath/libpcre2-8.0.dylib "$(FW)/libpcre2-8.0.dylib"
	install_name_tool -id @rpath/libgc.1.dylib "$(FW)/libgc.1.dylib"
	@# libssl references libcrypto (use both opt symlink and Cellar real path)
	install_name_tool -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @rpath/libcrypto.3.dylib "$(FW)/libssl.3.dylib"
	install_name_tool -change $(shell readlink -f /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib) @rpath/libcrypto.3.dylib "$(FW)/libssl.3.dylib"
	@echo "==> Fixing binary to use @rpath for all bundled libs..."
	@# --- Rewrite binary's absolute homebrew paths to @rpath ---
	install_name_tool \
		-change /opt/homebrew/opt/whisper-cpp/libexec/lib/libwhisper.1.dylib @rpath/libwhisper.1.dylib \
		-change /opt/homebrew/opt/whisper-cpp/libexec/lib/libggml.0.dylib @rpath/libggml.0.dylib \
		-change /opt/homebrew/opt/whisper-cpp/libexec/lib/libggml-base.0.dylib @rpath/libggml-base.0.dylib \
		-change /opt/homebrew/opt/libyaml/lib/libyaml-0.2.dylib @rpath/libyaml-0.2.dylib \
		-change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib @rpath/libssl.3.dylib \
		-change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib @rpath/libcrypto.3.dylib \
		-change /opt/homebrew/opt/pcre2/lib/libpcre2-8.0.dylib @rpath/libpcre2-8.0.dylib \
		-change /opt/homebrew/opt/bdw-gc/lib/libgc.1.dylib @rpath/libgc.1.dylib \
		"$(EXE)"
	@echo "==> Bundling whisper model..."
	@MODEL_SRC="$$HOME/Library/Application Support/Scribe/models/ggml-base.en.bin"; \
	if [ -f "$$MODEL_SRC" ]; then \
		cp "$$MODEL_SRC" "$(APP_DIR)/Contents/Resources/ggml-base.en.bin"; \
		echo "Model bundled ($$( du -h "$$MODEL_SRC" | cut -f1 ))"; \
	else \
		echo "Warning: Whisper model not found at $$MODEL_SRC — bundle without model"; \
	fi
	@echo "==> Verifying library references..."
	@otool -L "$(EXE)" | grep -c '/opt/homebrew' && echo "ERROR: Binary still references homebrew paths!" && exit 1 || echo "All references use @rpath — OK"
	@echo "==> Bundle created at $(APP_DIR)"
	@du -sh "$(APP_DIR)"


# Code sign the bundle (Developer ID for direct distribution)
sign: bundle
	@echo "==> Signing with Developer ID..."
	codesign --force --options runtime --timestamp \
		--entitlements packaging/Scribe.entitlements \
		--sign $(DEVID_APP) \
		"$(APP_DIR)/Contents/MacOS/scribe"
	codesign --force --options runtime --timestamp \
		--entitlements packaging/Scribe.entitlements \
		--sign $(DEVID_APP) \
		"$(APP_DIR)"
	@echo "==> Verifying signature..."
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"

# Notarize the app (submit to Apple, wait, staple)
notarize: sign
	@echo "==> Creating zip for notarization..."
	ditto -c -k --keepParent "$(APP_DIR)" "dist/$(APP_NAME).zip"
	@echo "==> Submitting for notarization (this may take a few minutes)..."
	xcrun notarytool submit "dist/$(APP_NAME).zip" \
		--keychain-profile "$(NOTARY_PROFILE)" --wait
	@echo "==> Stapling notarization ticket..."
	xcrun stapler staple "$(APP_DIR)"
	rm -f "dist/$(APP_NAME).zip"

# Create DMG installer with drag-to-Applications layout
dmg: notarize
	@echo "==> Creating DMG installer..."
	rm -f "dist/$(DMG_NAME)"
	@if command -v create-dmg >/dev/null 2>&1; then \
		create-dmg \
			--volname "$(APP_NAME)" \
			--window-pos 200 120 \
			--window-size 600 400 \
			--icon-size 100 \
			--icon "$(APP_NAME).app" 150 190 \
			--hide-extension "$(APP_NAME).app" \
			--app-drop-link 450 190 \
			--no-internet-enable \
			"dist/$(DMG_NAME)" \
			"$(APP_DIR)"; \
	else \
		echo "create-dmg not found, using hdiutil fallback..."; \
		mkdir -p dist/dmg-staging; \
		cp -R "$(APP_DIR)" dist/dmg-staging/; \
		ln -sf /Applications dist/dmg-staging/Applications; \
		hdiutil create -volname "$(APP_NAME)" -srcfolder dist/dmg-staging \
			-ov -format UDZO "dist/$(DMG_NAME)"; \
		rm -rf dist/dmg-staging; \
	fi
	codesign --force --timestamp --sign $(DEVID_APP) "dist/$(DMG_NAME)"
	xcrun notarytool submit "dist/$(DMG_NAME)" \
		--keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "dist/$(DMG_NAME)"
	@echo "==> Distribution DMG ready: dist/$(DMG_NAME)"

# Full distribution build: release → bundle → sign → notarize → DMG
dist: dmg
	@echo ""
	@echo "==> Distribution complete!"
	@echo "    DMG: dist/$(DMG_NAME)"
	@echo "    App: $(APP_DIR)"

clean-dist:
	rm -rf dist/
