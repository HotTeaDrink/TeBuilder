# TeBuilder

This repository provides a small, opinionated **builder** for assembly projects using a single `Makefile`.
It's designed for modular assembly code organized into functional subdirectories, with convenient build, debug, test and analysis commands.

> **Note:** This README is written to match the `Makefile` included in the repository. Run `make help` to show the same targets from the build system.

---

## Project layout (what the Makefile expects)

```
.
├── Makefile          # build system (compile/link/test/analyze)
├── src/              # assembly source
│   ├── main.asm
│   ├── network/
│   ├── process/
│   ├── utils/
│   ├── stealth/      # optional
│   ├── persistence/  # optional
│   └── features/     # optional
├── include/          # assembly includes (syscalls, constants, macros)
│   └── auto/         # auto-generated aggregated include files (*.inc)
├── tests/            # C test code; subdirs allowed (unit/, integration/, ...)
├── docs/             # generated docs / listings
└── build/            # build outputs (object files, binaries) — ignored by VCS
```

---

## Quick start

1. Ensure you have the required toolchain installed:

   * `nasm` (assembler)
   * `ld` (linker)
   * `gcc` (C compiler for tests)
   * `objdump`, `nm`, `objcopy` (analysis helpers)
   * `gdb` (optional, used by the `debug` target)

2. Create the basic layout (idempotent):

```bash
make setup
```

3. Build the project:

```bash
make
```

The default binary is placed at `build/output` (value of `$(BIN)` in the Makefile).

4. Run tests (see Test Runner section below):

```bash
make test-build
```

---

## Auto-generated include files

The Makefile **automatically generates aggregated include files** for each module directory. This allows you to include entire modules with a single line in your `main.asm`.

### Generated files

When you run `make`, the following files are created in `include/auto/`:

* `include/auto/network.inc` — includes all `src/network/*.asm` files
* `include/auto/process.inc` — includes all `src/process/*.asm` files
* `include/auto/utils.inc` — includes all `src/utils/*.asm` files
* `include/auto/stealth.inc` — includes all `src/stealth/*.asm` files
* `include/auto/persistence.inc` — includes all `src/persistence/*.asm` files
* `include/auto/features.inc` — includes all `src/features/*.asm` files

### Usage in main.asm

Instead of manually including each source file, you can now simply:

```nasm
; src/main.asm

%include "auto/network.inc"
%include "auto/process.inc"
%include "auto/utils.inc"
%include "auto/stealth.inc"
%include "auto/persistence.inc"
%include "auto/features.inc"

; Your main code here
global _start
_start:
    ; ...
```

### Build modes

The Makefile supports two build modes controlled by the `BUILD_MODE` variable:

#### **Include mode (default)** — `BUILD_MODE=include`

All code is included in `main.asm` via the auto-generated `.inc` files. Only `main.o` is compiled and linked.

```bash
make                    # uses include mode by default
make BUILD_MODE=include # explicit
```

**Pros:**
- Simple, single-file assembly
- Fast compilation (one assembly pass)
- Easy to understand code flow

**Cons:**
- All code is included (even unused functions)
- Larger binary size
- `--gc-sections` has no effect (all code in one section)

**Use case:** Quick development, prototyping, or when you need all functionality.

#### **Separate mode** — `BUILD_MODE=separate`

Each `.asm` file is compiled separately into its own object file with proper section separation, then all objects are linked together with `--gc-sections` to remove unused functions.

```bash
make BUILD_MODE=separate
```

**Pros:**
- **Only used functions are included** (via `--gc-sections`)
- Smaller binary size
- Better for production/shellcode
- Incremental compilation (only changed files recompile)

**Cons:**
- Slightly slower build (multiple assembly passes)
- Requires proper section naming for optimal garbage collection

**Use case:** Production builds, shellcode, minimal binaries, or when binary size matters.

### Manual header generation

The auto-generated headers are created automatically when you run `make`. To regenerate them explicitly:

```bash
make gen-headers
```

---

## Understanding `--gc-sections` (linker garbage collection)

In `BUILD_MODE=separate`, the Makefile uses the `--gc-sections` linker flag to remove unused functions.

### How it works:

1. **Each function in its own section**: When using separate mode, each `.asm` file should ideally place its functions in separate sections:
   ```nasm
   section .text.function_name
   global function_name
   function_name:
       ; code
   ```

2. **Linker traces dependencies**: The linker starts from `_start` and follows all function calls to determine what's actually used.

3. **Unused sections removed**: Any section not reachable from the entry point is discarded from the final binary.

### Important notes:

- `--gc-sections` **only works** in `BUILD_MODE=separate`
- In `BUILD_MODE=include`, all code is in one `.text` section, so the linker must keep everything
- For maximum size reduction, ensure each function has its own section

### Example: Verify garbage collection

```bash
# Build with separate mode
make BUILD_MODE=separate

# Check what functions are in the binary
nm build/output | grep function

# Compare with include mode
make BUILD_MODE=include
nm build/output | grep function

# You'll see more functions in include mode!
```

---

## Useful Makefile targets

Run `make help` for a short menu; below are the main targets and what they do.

* `make` — generate auto-includes and build the project (`all`)
* `make gen-headers` — explicitly generate the aggregated `.inc` files in `include/auto/`
* `make re` — clean (including auto-generated headers) and rebuild
* `make debug` — build a separate debug binary (`$(BIN)-dbg`) with DWARF debug info and launch `gdb` on it
* `make test-build` — compile and run C tests under `tests/` (see Test Runner notes)
* `make disassemble` — disassemble `.text` of the resulting binary using `objdump`
* `make info` — show build configuration, discovered source files, and auto-generated headers
* `make list-sources` — list discovered assembly sources by category
* `make shellcode` — extract `.text` section into `build/shellcode/shellcode.bin` using `objcopy`
* `make analyze` — simple null-byte analysis of the binary
* `make clean` — remove files inside `build/` and auto-generated headers
* `make fclean` — remove the entire `build/` directory and `include/auto/`

---

## Test runner behavior

The test runner (`make test-build`) follows this flow:

1. Rebuilds the project (`re`).
2. **Compiles all** C test files found recursively under `tests/*.c` into executables placed next to their sources (e.g. `tests/unit/foo.c` → `tests/unit/foo`).
3. Runs the tests **grouped by directory**, in sorted order (skipping the top-level `tests/` directory itself).
4. By default the runner **stops on the first failing test**. To continue running remaining tests even after failures, set the environment variable:

```bash
CONTINUE_ON_TEST_FAILURE=1 make test-build
```

Output is colorized and prints per-test pass/fail messages.

---

## Debugging

* The `debug` target builds a debug binary with `DBG_FLAGS` appended to `ASMFLAGS` (the Makefile sets `DBG_FLAGS ?= -g -F dwarf`) and launches `gdb` on it:

```bash
make debug
```

This creates `build/output-dbg` with DWARF information generated by NASM. Use GEF or GDB to inspect sources, symbols, and step through assembly.

---

## Shellcode extraction & analysis

* Extract raw `.text` bytes:

```bash
make shellcode
# -> build/shellcode/shellcode.bin
```

* Quick null-byte check:

```bash
make analyze
```

This counts zero bytes in the full binary and prints the first occurrences if any are found.

---

## Build flags and customization

* `ASMFLAGS` — NASM assembler flags. Default: `-f elf64 -I include/`
* `DBG_FLAGS` — default debug flags: `-g -F dwarf`
* `LDFLAGS` — linker flags for include mode (default: `-nostdlib`)
* `LDFLAGS_GC` — linker flags for separate mode (default: `-nostdlib --gc-sections`)
* `BUILD_MODE` — build strategy: `include` (default) or `separate`
* Override or extend flags from the command line:

```bash
make ASMFLAGS="$(ASMFLAGS) -DDEBUG"      # example
make LDFLAGS="-nostdlib -static"
make BUILD_MODE=separate                 # use separate compilation with --gc-sections
```

---

## Example workflow

### Development workflow (include mode):

```bash
# prepare layout (creates directories including include/auto/)
make setup

# build with include mode (fast, all functions included)
make

# run tests
make test-build

# build & debug with GDB
make debug

# get disassembly
make disassemble
```

### Production workflow (separate mode):

```bash
# build optimized binary with garbage collection
make BUILD_MODE=separate

# verify size reduction
ls -lh build/output

# check which functions are included
nm build/output | grep -E "function|socket"

# extract shellcode
make shellcode

# analyze for null bytes
make analyze

# cleanup
make clean    # remove generated files in build/ and auto-generated headers
make fclean   # remove build/ directory and include/auto/ entirely
```

---

## Example: Using auto-generated includes

Here's a complete example of how to structure your `main.asm`:

```nasm
; src/main.asm
BITS 64

; Include syscall definitions (constants only, no code)
%include "syscalls.inc"

; Include all modules via auto-generated aggregated headers
%include "auto/network.inc"
%include "auto/process.inc"
%include "auto/utils.inc"
%include "auto/stealth.inc"
%include "auto/persistence.inc"
%include "auto/features.inc"

section .text
global _start

_start:
    ; Call functions from any included module
    call socket_create        ; from network/socket.asm
    call process_enumerate    ; from process/enum.asm
    call string_length        ; from utils/string.asm
    
    ; Exit
    mov rax, 60
    xor rdi, rdi
    syscall
```

### What happens during build:

**Include Mode (`BUILD_MODE=include`):**
1. Discovers all `.asm` files in each subdirectory
2. Generates `include/auto/*.inc` files that include the discovered sources
3. Assembles `main.asm` (which includes all modules via the `.inc` files)
4. Links only `main.o` into the final binary
5. **Result:** Single binary with ALL functions included

**Separate Mode (`BUILD_MODE=separate`):**
1. Generates `include/auto/*.inc` files (for reference, not used in assembly)
2. Assembles `main.asm` separately
3. Assembles each module file (`network/*.asm`, etc.) separately into individual `.o` files
4. Links all `.o` files together with `--gc-sections`
5. **Result:** Optimized binary with ONLY used functions

---

## Comparing build modes

```bash
# Build with both modes and compare
make BUILD_MODE=include
ls -lh build/output
nm build/output | wc -l  # count symbols

make clean
make BUILD_MODE=separate
ls -lh build/output
nm build/output | wc -l  # fewer symbols = smaller binary

# The separate mode binary should be smaller!
```

---

## Notes & best practices

* The builder is intentionally simple and modular: add/remove module directories under `src/` and the Makefile automatically discovers sources and regenerates include files.
* Keep `include/` for shared constants, syscall numbers, macros, and structure definitions (like `syscalls.inc`).
* The auto-generated files in `include/auto/` are regenerated on every build — don't edit them manually.
* **For development:** Use `BUILD_MODE=include` (default) for faster builds and simpler debugging.
* **For production/shellcode:** Use `BUILD_MODE=separate` for smaller binaries via `--gc-sections`.
* To maximize `--gc-sections` effectiveness in separate mode, place each function in its own section:
  ```nasm
  section .text.function_name
  ```
* Use the `tests/` directory for portable C tests; the test-runner compiles and runs them automatically.
* The repository uses `build/` and `include/auto/` for generated files — include them in `.gitignore`.

---

## Migration guide

If you're upgrading from the previous version of this Makefile:

1. **No changes required to existing code** — the new system is backward compatible
2. **Optional:** Modify your `main.asm` to use the new auto-generated includes instead of manual includes
3. **Auto-generated files:** Add `include/auto/` to your `.gitignore`
4. The default `BUILD_MODE` is `include` — the old behavior without auto-includes would be equivalent to separate mode
5. For minimal binary size, switch to `BUILD_MODE=separate`

**Example .gitignore update:**
```gitignore
build/
include/auto/
```

---

## FAQ

**Q: Should I use include mode or separate mode?**

A: Use `include` mode for development (faster, simpler). Use `separate` mode for production (smaller binaries via `--gc-sections`).

**Q: Why doesn't `--gc-sections` work in include mode?**

A: Because all code is assembled into a single `.text` section in `main.o`. The linker operates on section granularity, so it must keep the entire section. In separate mode, each function is in its own section, allowing fine-grained removal.

**Q: Do the auto-generated `.inc` files add extra bytes to my binary?**

A: In `include` mode, yes — all code is included. In `separate` mode, the `.inc` files are generated but not used during assembly, so only functions you call are linked into the final binary.

**Q: Can I include `syscalls.inc` safely without bloating my binary?**

A: Yes! `syscalls.inc` contains only `%define` directives (constants), which don't generate any bytes. They're just text substitutions during assembly.

**Q: How do I verify that unused functions are removed?**

A: Use `nm build/output | grep function_name` to check which symbols are in the final binary. Compare between include and separate modes.

**Q: Does `make re` clean the auto-generated headers?**

A: Yes! `make re` calls `clean`, which removes both build artifacts and auto-generated `.inc` files, then rebuilds everything fresh.