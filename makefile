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

# Auto-generated includes subdirectory
AUTO_INC_DIR := $(INC_DIR)/auto

# Output binary
BIN = $(BUILD_DIR)/output

# Build mode: 'include' or 'separate'
# - include: Everything included in main.asm via auto/*.inc (only main.o linked)
# - separate: Each .asm compiled separately and linked together
BUILD_MODE ?= include

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

# Auto-generated header files
AUTO_HEADERS := $(AUTO_INC_DIR)/network.inc \
                $(AUTO_INC_DIR)/process.inc \
                $(AUTO_INC_DIR)/utils.inc \
                $(AUTO_INC_DIR)/stealth.inc \
                $(AUTO_INC_DIR)/persistence.inc \
                $(AUTO_INC_DIR)/features.inc

# Convert .asm -> .o (place objects under build/ mirroring src path)
ASM_TO_OBJ = $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(1))
NETWORK_OBJS  := $(call ASM_TO_OBJ,$(NETWORK_SRCS))
PROCESS_OBJS  := $(call ASM_TO_OBJ,$(PROCESS_SRCS))
UTILS_OBJS    := $(call ASM_TO_OBJ,$(UTILS_SRCS))
STEALTH_OBJS  := $(call ASM_TO_OBJ,$(STEALTH_SRCS))
PERSIST_OBJS  := $(call ASM_TO_OBJ,$(PERSIST_SRCS))
FEATURES_OBJS := $(call ASM_TO_OBJ,$(FEATURES_SRCS))

CORE_OBJS := $(NETWORK_OBJS) $(PROCESS_OBJS) $(UTILS_OBJS)
ALL_OBJS  := $(CORE_OBJS) $(STEALTH_OBJS) $(PERSIST_OBJS) $(FEATURES_OBJS)

# Conditional object files based on build mode
ifeq ($(BUILD_MODE),include)
    LINK_OBJS := $(BUILD_DIR)/main.o
else
    LINK_OBJS := $(BUILD_DIR)/main.o $(ALL_OBJS)
endif

# Test runner behavior
CONTINUE_ON_TEST_FAILURE ?= 0

.PHONY: all re clean fclean setup dirs info list-sources disassemble test-build help shellcode analyze debug gen-headers

# -----------------------------------------------------------------------------
# Top level targets
# -----------------------------------------------------------------------------
all: gen-headers $(BIN)

# Rebuild
re: clean all

# Debug build: rebuild with DBG_FLAGS appended to ASMFLAGS (DWARF debug info)
debug:
	@echo -e "$(BLUE)Building debug binary: $(BIN)-dbg$(NC)"
	$(MAKE) BIN=$(BIN)-dbg ASMFLAGS="$(ASMFLAGS) $(DBG_FLAGS)" re
	@echo -e "$(GREEN)✓ Debug build complete: $(BIN)-dbg (contains DWARF info)$(NC)"
	gdb $(BIN)-dbg

# -----------------------------------------------------------------------------
# Auto-generate aggregated include files
# -----------------------------------------------------------------------------
gen-headers: $(AUTO_HEADERS)

$(AUTO_INC_DIR)/network.inc: $(NETWORK_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for network modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(NETWORK_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR)/process.inc: $(PROCESS_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for process modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(PROCESS_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR)/utils.inc: $(UTILS_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for utils modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(UTILS_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR)/stealth.inc: $(STEALTH_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for stealth modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(STEALTH_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR)/persistence.inc: $(PERSIST_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for persistence modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(PERSIST_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR)/features.inc: $(FEATURES_SRCS) | $(AUTO_INC_DIR)
	@echo -e "$(BLUE)Generating $@...$(NC)"
	@echo "; Auto-generated include file for features modules" > $@
	@echo "; Generated on $$(date)" >> $@
	@echo "; BUILD_MODE: $(BUILD_MODE)" >> $@
	@echo "" >> $@
	@for src in $(FEATURES_SRCS); do \
		rel_path=$$(realpath --relative-to=$(INC_DIR) $$src 2>/dev/null || python3 -c "import os.path; print(os.path.relpath('$$src', '$(INC_DIR)'))"); \
		echo "%include \"$$rel_path\"" >> $@; \
	done
	@echo -e "$(GREEN)✓ Generated $@$(NC)"

$(AUTO_INC_DIR):
	@mkdir -p $(AUTO_INC_DIR)

# -----------------------------------------------------------------------------
# Setup / directories / cleaning
# -----------------------------------------------------------------------------
setup: dirs
	@echo -e "$(GREEN)Project layout ensured (src/, include/, tests/, build/, docs/)$(NC)"

dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(SRC_DIR)/network $(SRC_DIR)/process $(SRC_DIR)/utils $(SRC_DIR)/stealth $(SRC_DIR)/persistence $(SRC_DIR)/features
	@mkdir -p $(INC_DIR) $(AUTO_INC_DIR) $(DOC_DIR) $(TST_DIR)/unit $(TST_DIR)/integration
	@touch $(SRC_DIR)/main.asm

# Clean files only (objects, binaries inside build/)
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@if [ -d "$(BUILD_DIR)" ]; then \
	  find "$(BUILD_DIR)" -type f -print -delete; \
	else \
	  echo -e "$(YELLOW)Nothing to clean ($(BUILD_DIR) missing)$(NC)"; \
	fi
	@echo -e "$(YELLOW)Cleaning auto-generated headers...$(NC)"
	@rm -f $(AUTO_HEADERS)
	@echo ""

# Full clean: remove build dir entirely
fclean: clean
	@echo -e "$(YELLOW)Removing $(BUILD_DIR) directory...$(NC)"
	@rm -rf "$(BUILD_DIR)"
	@echo -e "$(YELLOW)Removing auto-generated includes...$(NC)"
	@rm -rf "$(AUTO_INC_DIR)"
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

# Generic rule to compile any .asm file to .o (only used in 'separate' mode)
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm | directories-build
ifeq ($(BUILD_MODE),separate)
	@echo -e "$(BLUE)Assembling $<...$(NC)"
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@
else
	@echo -e "$(YELLOW)Skipping $< (BUILD_MODE=include, assembled via main.asm)$(NC)"
endif

# Rule for main entrypoint (expects src/main.asm)
$(BUILD_DIR)/main.o: $(SRC_DIR)/main.asm $(AUTO_HEADERS) | directories-build
	@echo -e "$(BLUE)Assembling main: $< (BUILD_MODE=$(BUILD_MODE))$(NC)"
	@mkdir -p $(dir $@)
	$(ASM) $(ASMFLAGS) $< -o $@

# Link based on BUILD_MODE
$(BIN): $(LINK_OBJS) | directories-build
	@echo -e "$(GREEN)Linking $(BIN) (BUILD_MODE=$(BUILD_MODE))...$(NC)"
	$(LD) $(LDFLAGS) -o $(BIN) $(LINK_OBJS)
	@echo -e "$(GREEN)✓ Built $(BIN)$(NC)"

# -----------------------------------------------------------------------------
# Utilities & analysis (safe)
# -----------------------------------------------------------------------------
disassemble: $(BIN)
	@echo -e "$(YELLOW)Disassembly of $(BIN) (.text):$(NC)"
	$(OBJDUMP) -D -M intel -j .text $(BIN) | sed -n '1,200p'

info:
	@echo -e "$(YELLOW)Build Configuration:$(NC)"
	@echo "  ASM:         $(ASM)"
	@echo "  LD:          $(LD)"
	@echo "  ASMFLAGS:    $(ASMFLAGS)"
	@echo "  DBG_FLAGS:   $(DBG_FLAGS)"
	@echo "  LDFLAGS:     $(LDFLAGS)"
	@echo "  BUILD_MODE:  $(BUILD_MODE)"
	@echo ""
	@echo -e "$(YELLOW)Source Files:$(NC)"
	@echo "  Network:     $(words $(NETWORK_SRCS)) files"
	@echo "  Process:     $(words $(PROCESS_SRCS)) files"
	@echo "  Utils:       $(words $(UTILS_SRCS)) files"
	@echo "  Stealth:     $(words $(STEALTH_SRCS)) files"
	@echo "  Persist:     $(words $(PERSIST_SRCS)) files"
	@echo "  Features:    $(words $(FEATURES_SRCS)) files"
	@echo ""
	@echo -e "$(YELLOW)Auto-generated Headers:$(NC)"
	@for header in $(AUTO_HEADERS); do echo "  $$header"; done
	@echo ""
	@echo -e "$(YELLOW)Linking Strategy:$(NC)"
ifeq ($(BUILD_MODE),include)
	@echo "  Mode: INCLUDE - All code included via auto/*.inc in main.asm"
	@echo "  Linking: main.o only"
else
	@echo "  Mode: SEPARATE - Each .asm compiled separately"
	@echo "  Linking: main.o + $(words $(ALL_OBJS)) module objects"
endif

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
# Test runner
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
	@echo "  make setup        - Create all directories (including auto-include)"
	@echo ""
	@echo -e "$(YELLOW)Build Commands:$(NC)"
	@echo "  make              - Generate headers and build binary ($(BIN))"
	@echo "  make gen-headers  - Generate aggregated .inc files in $(AUTO_INC_DIR)/"
	@echo "  make re           - Clean and rebuild the project"
	@echo "  make debug        - Rebuild with debug info (DBG_FLAGS = $(DBG_FLAGS))"
	@echo "  make test-build   - Rebuild then compile+run C tests from $(TST_DIR)/"
	@echo ""
	@echo -e "$(YELLOW)Build Modes (set BUILD_MODE variable):$(NC)"
	@echo "  make BUILD_MODE=include   - Include all code in main.asm (default)"
	@echo "  make BUILD_MODE=separate  - Compile each .asm separately and link"
	@echo ""
	@echo -e "$(YELLOW)Information & Analysis:$(NC)"
	@echo "  make info         - Show build config and auto-generated headers"
	@echo "  make list-sources - List discovered source files by category"
	@echo "  make shellcode    - Extract the .text section as a raw binary"
	@echo "  make analyze      - Check the binary for null bytes"
	@echo ""
	@echo -e "$(YELLOW)Cleaning:$(NC)"
	@echo "  make clean        - Remove built files and auto-generated headers"
	@echo "  make fclean       - Remove $(BUILD_DIR) and $(AUTO_INC_DIR) entirely"
	@echo "  make help         - Show this help menu"
	@echo ""
	@echo -e "$(YELLOW)Usage in main.asm (when BUILD_MODE=include):$(NC)"
	@echo "  %include \"auto/network.inc\"     ; Includes all network/*.asm files"
	@echo "  %include \"auto/process.inc\"     ; Includes all process/*.asm files"
	@echo "  %include \"auto/utils.inc\"       ; Includes all utils/*.asm files"
	@echo "  %include \"auto/stealth.inc\"     ; Includes all stealth/*.asm files"
	@echo "  %include \"auto/persistence.inc\" ; Includes all persistence/*.asm files"
	@echo "  %include \"auto/features.inc\"    ; Includes all features/*.asm files"
	@echo ""
	@echo -e "$(YELLOW)Current BUILD_MODE: $(BUILD_MODE)$(NC)"
	@echo ""