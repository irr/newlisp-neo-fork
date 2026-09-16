# newLISP Spark

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Regression Tests](https://img.shields.io/badge/qa--dot-100%25%20Passing-brightgreen.svg)](qa-dot)
[![Tail Call Optimization](https://img.shields.io/badge/TCO-O(1)%20Stack-blueviolet.svg)](#3-tail-call-optimization-tco-and-mutual-recursion)
[![Speed vs Python](https://img.shields.io/badge/Speed%20vs%20Python%203.14-2.02x%20Faster-orange.svg)](#performance-benchmarks-newlisp-spark-vs-python-314)

**newLISP Spark** is a modernized, high-performance distribution of [newLISP](http://www.newlisp.org) — an elegant, lightweight, LISP-like scripting language originally created by **Lutz Mueller** for general programming, artificial intelligence, data manipulation, and statistical computing.

This enhanced release overhauls the newLISP engine with a **Direct-Threaded Bytecode Virtual Machine**, full **Tail Call Optimization (TCO)**, achieving order-of-magnitude speedups in recursion and iterative loops — and now runs the **complete regression suite** (`make testall`) cleanly on **x86_64 and aarch64/ARM64**, including NVIDIA **DGX Spark**.

**Maintained for this fork by Ivan Rocha** — Copyright (C) 2026 Ivan Rocha. Originally enhanced by KIM Taegyoon; created by Lutz Mueller.

---

## Key Enhancements

- **Direct-Threaded Bytecode Virtual Machine (`nl-vm.c`, `nl-vm.h`)**:
  - **Computed-Goto Dispatch**: Employs GCC/Clang `&&label` jump tables to eliminate branch mispredictions and loop branching overhead inherent in traditional `switch/case` interpreters.
  - **Specialized Super-Instructions**: Immediate opcode specializations (`OP_LOAD_LOCAL_0..3`, `OP_STORE_LOCAL_0..3`, `OP_CONST_0..2`, `OP_ADD_1`, `OP_SUB_1`, `OP_SUB_2`) bypass operand fetches and optimize frequent variable access and loop arithmetic.
  - **Non-Recursive Call Frame Execution**: Employs a flat frame stack (`vm_frames`) and operand stack (`vm_stack`), completely removing C call-stack recursion overhead during function evaluation.
  - **Transparent JIT/AST Fallback**: Functions and lambdas containing dynamic binding, metaprogramming, or constructs outside pure bytecode semantics fall back automatically and transparently to newLISP's classic tree-walking evaluator.

- **Full Tail Call Optimization (TCO) (`nl-vm.c`, `nl-vm.h`)**:
  - **Guaranteed $O(1)$ Stack Space**: Eliminates call stack overflow hazards for arbitrarily deep and infinite recursions by reusing execution frames in-place.
  - **Self-Tail Recursion (`OP_TAIL_CALL_SELF`)**: Directly reuses the caller's frame via zero-overhead stack argument copying and local variable clearing. Over **100,000,000 recursive steps** execute in **~1.02 seconds** with zero stack growth.
  - **Mutual & General Tail Calls (`OP_TAIL_CALL`)**: Reuses the active frame for calls to other compiled functions, enabling clean, idiomatic state machines and mutual recursion (`my-even?` / `my-odd?` 10,000,000 steps in **~167 ms**).
  - **Comprehensive Tail Position Analysis**: Automatically propagates tail positions through control-flow constructs: `if`, `when`, `cond`, `begin`, `let`, `local`, `and`, and `or`.

- **High-Throughput Generational Garbage Collector (`newlisp.c`, `newlisp.h`)**:
  - **64 MB Gen 0 Nursery**: Ultra-fast bump-pointer allocation (`cell = gen0_ptr++`) eliminates pool searching and per-cell free overhead for short-lived intermediate objects.
  - **Cheney-Style Evacuation**: Live objects surviving nursery collections are promoted (`gcEvacuate`) to the tenured Gen 1 heap.
  - **Comprehensive Root Scanning**: Traverses symbol trees, context tables, runtime stacks (`envStack`, `resultStack`, `lambdaStack`), and active VM execution frames.
  - **Safety first — nursery disabled by default in s1**: the tree-walking evaluator holds raw C-stack pointers into Gen 0 during expression evaluation; evacuating cells mid-evaluation can corrupt live expressions under heavy churn (reproduced with the `qa-factorfibo` prime sieve at N = 1,000,000 and `qa-bench`). By default all cells are allocated from the proven non-moving free-list allocator; set `NEWLISP_ENABLE_GEN0=1` to experiment with the nursery.

- **Native aarch64 / ARM64 Support (e.g. NVIDIA DGX Spark)**:
  - **Auto-detecting build**: plain `make` now detects aarch64 (`uname -m`) and selects the new `makefile_dgx_spark_utf8_ffi` (64-bit UTF-8 + libffi, tuned with `-mcpu=native` for the Grace CPU); x86_64 keeps its previous makefile. No manual makefile selection needed on ARM Linux.
  - **libffi correctness on ARM**: FFI `char` returns are now read as `signed char` — plain `char` is unsigned on aarch64, which corrupted signed 8-bit FFI return values.
  - **Portable FFI test suite**: `qa-libffi` no longer hardcodes `cc -m64` and macOS `.dylib` names — it picks the right flags/extension per platform, so the full FFI/struct/callback battery passes on ARM Linux.
  - **Verified on DGX Spark**: the complete extended suite (`make testall` — 21 tests incl. Cilk process API, FOOP, bigint, libffi, network, pipes) passes end-to-end, with a **0.73–0.76 qa-bench performance ratio** (vs. the 2016 MacBook reference calibration, i.e. faster than the reference machine).

- **Bytecode VM Correctness Fixes (s1)**:
  - **Cilk process API fixed** (`spawn`/`sync`/`abort`): the compiler turned `let`/`local`-bound variables into VM slots, but `spawn` writes results through the *symbol* (newLISP's dynamic binding) — spawned results were invisible to compiled code. Calls passing a quoted local symbol (e.g. `(spawn 'a ...)`, `(set 'a ...)`) now force fallback to the tree-walking evaluator, restoring correct semantics.
  - **FOOP fixed** (`:` dispatch, `self`, segfault removed): symbols merely *named* `self` are no longer miscompiled as self-recursion; VM frame entry now maintains the FOOP `objSymbol` (so `(self n)` works in compiled methods); `(: method obj ...)` compiles with the raw method-name symbol and `p_colon` accepts `(quote sym)`.
  - **Zero compiler warnings**: the build is clean under `-Wall` on aarch64 GCC (fixed `-Wunused-value`, `-Wmisleading-indentation`, `-Wunused-result`, `-Wstringop-truncation`, `-Wrestrict`, `-Wformat-truncation`/`-Wformat-overflow`, `-Walloca-larger-than`).

- **Memory Safety & Rock-Solid Compatibility**:
  - **Magic-Tagged Bytecode Handles**: Bytecode objects are tagged with `BYTECODE_MAGIC` (`0xBEEC0DE0`) in `cell->aux`, preserving newLISP's native last-element pointer optimization on standard lists and eliminating memory corruption hazards.
  - **100% Test Suite Pass**: All 396 built-in primitives, contexts as objects, and scoping tests in the `qa-dot` suite pass with **0 errors** — and the complete extended suite (`make testall`, 21 tests incl. Cilk/FOOP/libffi/bigint/network) passes end-to-end on x86_64 **and aarch64/ARM64 (DGX Spark)**.

- **Modernized Interactive REPL (`newlisp.c`)**:
  - **Automatic Multi-Line Input**: Automatically detects incomplete expressions (unclosed parentheses `(...)`, double-quoted strings `"..."`, `{...}` braced strings with nesting, and `[text]...[/text]` tags) and seamlessly collects continuation lines until brackets are balanced, then evaluates immediately.
  - **Clean Line & Interrupt Handling**: Hitting `[Enter]` on an empty line returns a fresh prompt instead of entering legacy batch mode. `Ctrl+C` cleanly resets partial input buffers, and multi-line code can be piped directly from scripts/stdin without syntax errors.

---

## Performance Benchmarks: newLISP Spark vs. Python 3.14

All benchmarks were evaluated under identical conditions on the same x86_64 host (originally recorded on Windows; ratios are platform-independent relative measurements).

### 1. Recursive Fibonacci: `(fib 30)`

Lisp code ([`bench_fib.lsp`](bench_fib.lsp)):
```lisp
(define (fib n)
  (if (< n 2)
      n
      (+ (fib (- n 1)) (fib (- n 2)))))
```

Python reference code ([`bench.py`](bench.py)):
```python
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
```

| Runtime Engine | Execution Time | Speedup vs Original newLISP | Comparison vs Python 3.14 |
|---|---|---|---|
| **Original newLISP 10.7.6** (Tree-Walker) | 592.5 ms | 1.00x | 6.89x slower |
| **CPython 3.12.3** (Standard Python VM) | 186.9 ms | 3.17x faster | 2.17x slower |
| **CPython 3.14.4** (Optimized Python VM) | 86.0 ms | 6.89x faster | 1.00x (baseline) |
| **newLISP Spark** (Direct-Threaded VM + TCO + GenGC) | **42.6 ms** | **13.9x faster** | **2.02x FASTER than Python 3.14** |

---

### 2. 1-Million Iteration Loop: `(loop-test 1000000)`

Lisp code ([`bench_loop.lsp`](bench_loop.lsp)):
```lisp
;; 1. Iterative While Loop
(define (loop-test n)
  (let (s 0 i 0)
    (while (< i n)
      (set 's (+ s i))
      (set 'i (+ i 1)))
    s))

;; 2. Tail-Recursive Loop (TCO)
(define (loop-tco-acc n s i)
  (if (< i n)
      (loop-tco-acc n (+ s i) (+ i 1))
      s))
(define (loop-tco n)
  (loop-tco-acc n 0 0))
```

Python reference code ([`bench.py`](bench.py)):
```python
def loop_test(n):
    s = 0
    i = 0
    while i < n:
        s += i
        i += 1
    return s
```

| Runtime Engine | Execution Time | Speedup vs Original newLISP | Comparison vs Python 3.14 |
|---|---|---|---|
| **Original newLISP 10.7.6** (Tree-Walker, `while`) | 190.2 ms | 1.00x | 5.11x slower |
| **Original newLISP 10.7.6** (Tail Recursion) | Stack Overflow | — | — |
| **CPython 3.12.3** (Standard Python VM, `while`) | 78.8 ms | 2.41x faster | 2.12x slower |
| **CPython 3.14.4** (Optimized Python VM, `while`) | 37.2 ms | 5.11x faster | 1.00x (baseline) |
| **CPython 3.14.4** (Tail Recursion) | RecursionError | — | — |
| **newLISP Spark** (Direct-Threaded VM, `while` loop) | **31.3 ms** | **6.08x faster** | **1.19x FASTER than Python 3.14** |
| **newLISP Spark** (TCO Engine, Tail-Recursive loop) | **17.3 ms** | **11.0x faster** | **2.15x FASTER than Python 3.14** |

---

### 3. Tail Call Optimization (TCO) and Mutual Recursion

Lisp code ([`bench_tco.lsp`](bench_tco.lsp)):
```lisp
;; 100,000,000 step self-tail recursion
(define (count-down n)
  (if (<= n 0) "done" (count-down (- n 1))))

;; 10,000,000 step mutual tail recursion
(define (my-even? n)
  (if (= n 0) true (my-odd? (- n 1))))

(define (my-odd? n)
  (if (= n 0) nil (my-even? (- n 1))))
```

Python reference:
> *Python does not support tail call optimization. Deep recursions trigger `RecursionError: maximum recursion depth exceeded` (default limit 1,000).*

| Benchmark Task | Original newLISP 10.7.6 | Python 3.14 | newLISP Spark (TCO Engine) |
|---|---|---|---|
| **Self-Tail Recursion (100M steps)** | Stack Overflow (`ERR: out of call stack`) | `RecursionError` | **1,023 ms** ($O(1)$ stack, constant memory) |
| **Tail Accumulator (10M steps)** | Stack Overflow (`ERR: out of call stack`) | `RecursionError` | **151 ms** ($O(1)$ stack, constant memory) |
| **Mutual Tail Recursion (10M steps)** | Stack Overflow (`ERR: out of call stack`) | `RecursionError` | **167 ms** ($O(1)$ stack, constant memory) |
| **Tail Call in `cond` (1M steps)** | Stack Overflow (`ERR: out of call stack`) | `RecursionError` | **21 ms** ($O(1)$ stack, constant memory) |
| **Tail Call in `let` (1M steps)** | Stack Overflow (`ERR: out of call stack`) | `RecursionError` | **12 ms** ($O(1)$ stack, constant memory) |

---

## Building and Installation

### Prerequisites
- GCC or Clang (supporting C99/GNU extensions for computed gotos)
- GNU Make

### Build on Linux and macOS
```bash
# Automatic platform AND architecture detection
# (aarch64/ARM64 — e.g. NVIDIA DGX Spark — is auto-detected):
make

# Or configure first:
./configure
make

# Or build with a specific makefile:
make -f makefile_linuxLP64_utf8
make -f makefile_dgx_spark_utf8_ffi   # aarch64/ARM64 Linux (DGX Spark)
make -f makefile_darwinLP64_utf8_ffi
```

### Installation
```bash
# System-wide installation (requires root privileges):
sudo make install

# User home directory install (~/bin, ~/share):
make install_home
```

---

## Verification & Benchmarks

### Running the QA Regression Suite
Verify complete language integrity across all primitive functions, scoping, and context features:
```bash
./newlisp qa-dot
```
Expected summary output:
```text
Testing built-in functions ...
...
Testing contexts as objects and scoping rules ...
total time: ...
>>>>> ALL FUNCTIONS FINISHED SUCCESSFUL: ./newlisp
```

Additional test suites can be executed via:
```bash
make check
# or the complete extended suite (Cilk processes, FOOP, libffi,
# bigint, network, pipes — verified green on x86_64 and aarch64/DGX Spark):
make testall
```

### Running Performance Benchmarks
```bash
./newlisp bench_fib.lsp
./newlisp bench_loop.lsp
./newlisp bench_tco.lsp
python bench.py
```

---

## Repository Structure

```text
.
├── newlisp.c / newlisp.h     # Core interpreter runtime, GenGC, and memory manager
├── nl-vm.c / nl-vm.h         # Direct-threaded bytecode compiler and virtual machine
├── nl-*.c                    # Built-in subsystems (math, string, socket, filesys, etc.)
├── pcre.c / pcre.h           # Bundled PCRE regular expression library
├── makefile_*                # Build definitions for Linux (x86_64 + aarch64/DGX Spark) and macOS
├── bench_fib.lsp             # Recursive Fibonacci benchmark harness
├── bench_loop.lsp            # Arithmetic loop benchmark harness
├── bench_tco.lsp             # Tail Call Optimization (TCO) benchmark harness
├── bench.py                  # Python 3.14 benchmark comparison harness
├── qa-dot / qa-comma         # Complete language regression test suites
├── qa-specific-tests/        # Extended suite: Cilk, FOOP, libffi, bigint, network, pipes (used by `make testall`)
├── modules/                  # Standard library modules (crypto, sqlite3, stat, etc.)
├── examples/                 # Sample applications and scripts
├── doc/
│   ├── ARCHITECTURE.md       # VM bytecode instruction set, memory layout & GC architecture
│   ├── CHANGES.txt           # Version history and detailed changelog
│   ├── newlisp_manual.html   # Full reference manual and language specification
│   ├── MemoryManagement.html # Original ORO memory management documentation
│   └── INSTALL.txt           # Detailed platform installation instructions
└── README-old                # Legacy upstream README by Lutz Mueller
```

---

## Documentation Links

- [**Architecture & VM Internals**](doc/ARCHITECTURE.md) — Comprehensive technical breakdown of bytecode opcodes, computed goto dispatch, frame layout, and generational GC evacuation.
- [**Changelog**](doc/CHANGES.txt) — Chronological record of features, fixes, and optimizations.
- [**newLISP Reference Manual**](doc/newlisp_manual.html) — Complete language manual, functions reference, and syntax guide.
- [**Original Upstream README**](README-old) — Lutz Mueller's original documentation, history, and notes.

---

## License & Credits

- Copyright (C) 2020 Lutz Mueller
- Copyright (C) 2026 KIM Taegyoon
- Copyright (C) 2026 Ivan Rocha (maintainer of this fork; aarch64/DGX Spark support, VM correctness and GC safety fixes)
- **newLISP** was originally designed and implemented by **Lutz Mueller** ([Nuevatec](http://www.newlisp.org)).
- **newLISP Spark** is released under the [GNU General Public License Version 3 (GPLv3)](LICENSE). See [`LICENSE`](LICENSE) or [`doc/COPYING.txt`](doc/COPYING.txt) for the complete license text.
- Documentation files are distributed under the GNU Free Documentation License (GFDL).
