# Simple Makefile — single build (no variants)

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# Tools
ASM ?= nasm
LD  ?= ld
CC  ?= gcc
OBJDUMP ?= objdump
NM ?= nm

# Flags
ASMFLAGS ?= -f elf64 -I include/
DBG_FLAGS ?= -g -F dwarf
LDFLAGS ?= -nostdlib

# Directories
SRC_DIR   := src
BUILD_DIR := build
INC_DIR   := include
DOC_DIR   := docs
TST_DIR   := tests

# Output binary
BIN = $(BUILD_DIR)/output

# Colors for output
RED    := \033[0;31m
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
NC     := \033[0m

# Source discovery
NETWORK_SRCS  := $(wildcard $(SRC_DIR)/network/*.asm)
PROCESS_SRCS  := $(wildcard $(SRC_DIR)/process/*.asm)
UTILS_SRCS    := $(wildcard $(SRC_DIR)/utils/*.asm)
STEALTH_SRCS  := $(wildcard $(SRC_DIR)/stealth/*.asm)
PERSIST_SRCS  := $(wildcard $(SRC_DIR)/persistence/*.asm)
FEATURES_SRCS := $(wildcard $(SRC_DIR)/features/*.asm)

# Convert .asm -> .o (place objects under build/ mirroring src path)
# NOTE: patsubst converts src/xxx/yyy.asm -> build/xxx/yyy.o
ASM_TO_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(1))
NETWORK_OBJS  := $(call ASM_TO_OBJ,$(NETWORK_SRCS))
PROCESS_OBJS  := $(call ASM_TO_OBJ,$(PROCESS_SRCS))
UTILS_OBJS    := $(call ASM_TO_OBJ,$(UTILS_SRCS))
STEALTH_OBJS  := $(call ASM_TO_OBJ,$(STEALTH_SRCS))
PERSIST_OBJS  := $(call ASM_TO_OBJ,$(PERSIST_SRCS))
FEATURES_OBJS := $(call ASM_TO_OBJ,$(FEATURES_SRCS))

CORE_OBJS := $(NETWORK_OBJS) $(PROCESS_OBJS) $(UTILS_OBJS)
ALL_OBJS  := $(CORE_OBJS) $(STEALTH_OBJS) $(PERSIST_OBJS) $(FEATURES_OBJS)

# Test runner behavior:
# By default the test-runner stops on first failing test. Set
# CONTINUE_ON_TEST_FAILURE=1 when calling make to run all tests regardless.
CONTINUE_ON_TEST_FAILURE ?= 0

.PHONY: all re clean fclean setup dirs info list-sources disassemble test-build help shellcode analyze debug

# -----------------------------------------------------------------------------
# Top level targets
# -----------------------------------------------------------------------------
all: $(BIN)

# Rebuild
re: clean all

# Debug build: rebuild with DBG_FLAGS appended to ASMFLAGS (DWARF debug info)
debug:
	@echo -e "$(BLUE)Building debug binary: $(BIN)-dbg$(NC)"
	$(MAKE) BIN=$(BIN)-dbg ASMFLAGS="$(ASMFLAGS) $(DBG_FLAGS)" re
	@echo -e "$(GREEN)✓ Debug build complete: $(BIN)-dbg (contains DWARF info)$(NC)"
	gdb $(BIN)-dbg

# -----------------------------------------------------------------------------
# Setup / directories / cleaning
# -----------------------------------------------------------------------------
# Create source and build directories (idempotent)
setup: dirs
	@echo -e "$(GREEN)Project layout ensured (src/, include/, tests/, build/, docs/)$(NC)"

dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(SRC_DIR)/network $(SRC_DIR)/process $(SRC_DIR)/utils $(SRC_DIR)/stealth $(SRC_DIR)/persistence $(SRC_DIR)/features
	@mkdir -p $(INC_DIR) $(DOC_DIR) $(TST_DIR)/unit $(TST_DIR)/integration
	@touch $(SRC_DIR)/main.asm

# Clean files only (objects, binaries inside build/)
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
	  find "$(BUILD_DIR)" -type f -print -delete; \
	else \
	  echo -e "$(YELLOW)Nothing to clean ($(BUILD_DIR) missing)$(NC)"; \
	fi
	@echo ""

# Full clean: remove build dir entirely
fclean: clean
	@echo -e "$(YELLOW)Removing $(BUILD_DIR) directory...$(NC)"
	@rm -rf "$(BUILD_DIR)"
	@echo -e "$(GREEN)fclean complete$(NC)"
	@echo ""

directories-build:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/network
	@mkdir -p $(BUILD_DIR)/process
	@mkdir -p $(BUILD_DIR)/utils
	@mkdir -p $(BUILD_DIR)/stealth
	@mkdir -p $(BUILD_DIR)/persistence
	@mkdir -p $(BUILD_DIR)/features

# Generic rule to compile any .asm file to .o
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm | directories-build
	@echo -e "$(BLUE)Assembling $<...$(NC)"
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@

# Rule for main entrypoint (expects src/main.asm)
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.asm | directories-build
	@echo -e "$(BLUE)Assembling main: $<...$(NC)"
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@

# Link everything into single binary
$(BIN): $(BUILD_DIR)/main.o $(ALL_OBJS) | directories-build
	@echo -e "$(GREEN)Linking $(BIN)...$(NC)"
	$(LD) $(LDFLAGS) -o $(BIN) $(BUILD_DIR)/main.o $(ALL_OBJS)
	@echo -e "$(GREEN)✓ Built $(BIN)$(NC)"

# -----------------------------------------------------------------------------
# Utilities & analysis (safe)
# -----------------------------------------------------------------------------
# Disassemble .text section
disassemble: $(BIN)
	@echo -e "$(YELLOW)Disassembly of $(BIN) (.text):$(NC)"
	$(OBJDUMP) -D -M intel -j .text $(BIN) | sed -n '1,200p'

# Display detailed build information
info:
	@echo -e "$(YELLOW)Build Configuration:$(NC)"
	@echo "  ASM:        $(ASM)"
	@echo "  LD:         $(LD)"
	@echo "  ASMFLAGS:   $(ASMFLAGS)"
	@echo "  DBG_FLAGS:  $(DBG_FLAGS)"
	@echo "  LDFLAGS:    $(LDFLAGS)"
	@echo ""
	@echo -e "$(YELLOW)Source Files:$(NC)"
	@echo "  Network:    $(words $(NETWORK_SRCS)) files"
	@echo "  Process:    $(words $(PROCESS_SRCS)) files"
	@echo "  Utils:      $(words $(UTILS_SRCS)) files"
	@echo "  Stealth:    $(words $(STEALTH_SRCS)) files"
	@echo "  Persist:    $(words $(PERSIST_SRCS)) files"
	@echo "  Features:   $(words $(FEATURES_SRCS)) files"

# Display source files being used
list-sources:
	@echo -e "$(YELLOW)Network Sources:$(NC)"
	@for src in $(NETWORK_SRCS); do echo "  $$src"; done
	@echo ""
	@echo -e "$(YELLOW)Process Sources:$(NC)"
	@for src in $(PROCESS_SRCS); do echo "  $$src"; done
	@echo ""
	@echo -e "$(YELLOW)Utils Sources:$(NC)"
	@for src in $(UTILS_SRCS); do echo "  $$src"; done
	@echo ""
	@echo -e "$(YELLOW)Stealth Sources:$(NC)"
	@for src in $(STEALTH_SRCS); do echo "  $$src"; done
	@echo ""
	@echo -e "$(YELLOW)Persistence Sources:$(NC)"
	@for src in $(PERSIST_SRCS); do echo "  $$src"; done
	@echo ""
	@echo -e "$(YELLOW)Features Sources:$(NC)"
	@for src in $(FEATURES_SRCS); do echo "  $$src"; done

# Extract shellcode from the single binary
shellcode:
	@if [ ! -f "$(BIN)" ]; then \
		echo -e "$(RED)Error: Binary not built. Run 'make' first.$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(BLUE)Extracting shellcode...$(NC)"
	@mkdir -p $(BUILD_DIR)/shellcode
	objcopy -O binary -j .text $(BIN) $(BUILD_DIR)/shellcode/shellcode.bin
	@echo -e "$(GREEN)✓ Shellcode saved to: $(BUILD_DIR)/shellcode/shellcode.bin$(NC)"
	@echo -e "$(BLUE)Size: $$(stat -f%z $(BUILD_DIR)/shellcode/shellcode.bin 2>/dev/null || stat -c%s $(BUILD_DIR)/shellcode/shellcode.bin) bytes$(NC)"
	@echo -e "$(BLUE)Hex dump (first 160 bytes):$(NC)"
	@hexdump -C $(BUILD_DIR)/shellcode/shellcode.bin | head -10

# Analyze binary for null bytes
analyze:
	@if [ ! -f "$(BIN)" ]; then \
		echo -e "$(RED)Error: Binary not built. Run 'make' first.$(NC)"; \
		exit 1; \
	fi
	@echo -e "$(YELLOW)Analyzing $(BIN) for null bytes...$(NC)"
	@null_count=$$(hexdump -C $(BIN) | grep -o " 00" | wc -l); \
	if [ $$null_count -gt 0 ]; then \
		echo -e "$(RED)⚠ Found $$null_count null bytes:$(NC)"; \
		hexdump -C $(BIN) | grep " 00" | head -10; \
	else \
		echo -e "$(GREEN)✓ No null bytes detected$(NC)"; \
	fi

# -----------------------------------------------------------------------------
# Test runner: compile and run each C file under tests/*
# -----------------------------------------------------------------------------
test-build: re
	@echo
	@echo -e "$(GREEN)================================$(NC)"
	@echo -e "$(GREEN)Build complete: $(BIN)$(NC)"
	@echo -e "$(GREEN)================================$(NC)"
	@echo -e "$(BLUE)Compiling and running C tests under $(TST_DIR)/ (ordered by directory)...$(NC)"
	@sh -c '\
	echo  "$(YELLOW)Step 1: Compiling all test sources...$(NC)"; \
	test_files=$$(find $(TST_DIR) -type f -name "*.c" | sort); \
	for src in $$test_files; do \
	  test_bin=$${src%.c}; \
	  echo  "  $(BLUE)Compiling $$src -> $$test_bin$(NC)"; \
	  mkdir -p "$$(dirname "$$test_bin")"; \
	  if ! $(CC) "$$src" -o "$$test_bin" -Iinclude; then \
	    echo  "$(RED)Compilation failed: $$src$(NC)"; exit 1; \
	  fi; \
	done; \
	echo  "$(GREEN)✓ All tests compiled successfully$(NC)"; \
	echo ""; \
	echo  "$(YELLOW)Step 2: Running tests grouped by directory...$(NC)"; \
	dirs=$$(find $(TST_DIR) -type d | sort); \
	for dir in $$dirs; do \
	  if [ "$${dir}" = "$(TST_DIR)" ]; then continue; \
	  fi; \
	  echo  ""; \
	  echo  "$(BLUE)>>> Running tests in $$dir$(NC)"; \
	  for test_bin in $$(find "$$dir" -maxdepth 1 -type f ! -name "*.c" | sort); do \
	    if [ -x "$$test_bin" ]; then \
	      echo  "$(BLUE)Running $$test_bin...$(NC)"; \
	      if ! "$$test_bin"; then \
	        echo  "$(RED)Test failed: $$test_bin$(NC)"; \
	        if [ "$(CONTINUE_ON_TEST_FAILURE)" = "1" ]; then \
	          echo  "$(YELLOW)Continuing despite failure (CONTINUE_ON_TEST_FAILURE=1)$(NC)"; \
	          continue; \
	        else \
	          exit 1; \
	        fi; \
	      fi; \
	      echo  "$(GREEN)✓ Passed $$test_bin$(NC)"; \
	    fi; \
	  done; \
	done; \
	echo  ""; \
	echo  "$(GREEN)All tests finished successfully$(NC)"; \
	'


# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
help:
	@echo -e "$(BLUE)========================================$(NC)"
	@echo -e "$(BLUE)         Assembly Project Build         $(NC)"
	@echo -e "$(BLUE)========================================$(NC)"
	@echo ""
	@echo -e "$(YELLOW)Initial Setup:$(NC)"
	@echo "  make setup        - Create all the directories"
	@echo ""
	@echo -e "$(YELLOW)Build Commands:$(NC)"
	@echo "  make              - Build the target binary ($(BIN))"
	@echo "  make re           - Clean and rebuild the project"
	@echo "  make debug        - Rebuild with debug info (DBG_FLAGS = $(DBG_FLAGS))"
	@echo "  make test-build   - Rebuild then compile+run C tests from $(TST_DIR)/"
	@echo ""
	@echo -e "$(YELLOW)Information & Analysis:$(NC)"
	@echo "  make info         - Show build configuration and source file counts"
	@echo "  make list-sources - List discovered source files by category"
	@echo "  make shellcode    - Extract the .text section as a raw binary"
	@echo "  make analyze      - Check the binary for null bytes"
	@echo ""
	@echo -e "$(YELLOW)Cleaning:$(NC)"
	@echo "  make clean        - Remove all built files (*.o, $(BIN), shellcode) from $(BUILD_DIR)"
	@echo "  make fclean       - Remove the entire $(BUILD_DIR) directory (deep clean)"
	@echo "  make help         - Show this help menu"
	@echo ""
