## Plan: Lua JIT Compiler and VMDragonSlayer Transpilation

This is a two-phase project to build a simple Lua JIT compiler leveraging LuaJIT's existing capabilities, then transpile VMDragonSlayer's 62 Python files to Lua. The project is a VM-based binary protector analysis framework using advanced techniques (symbolic execution, taint tracking, fuzzing) with heavy Python features (async/await, dataclasses, ABC, multiprocessing).

### Steps

1. **Design and implement minimal Lua JIT compiler** - Create `lua_jit_compiler/` with core modules: lexer/parser for Lua 5.1+ syntax, bytecode emitter targeting LuaJIT format, simple register allocator, and FFI bridge to leverage existing LuaJIT optimization, storing JIT compiler in project root

2. **Transpile core infrastructure files** - Convert `dragonslayer/core/` (4 files: `__init__.lua`, `orchestrator.lua`, `config.lua`, `exceptions.lua`), replacing asyncio with LuaSocket coroutines, dataclasses with metatables, and implementing lazy component loading using Lua patterns

3. **Transpile analysis engine modules** - Convert `dragonslayer/analysis/` (14 files including VM discovery, taint tracking, symbolic execution, pattern analysis), translating z3-solver calls to FFI bindings, replacing ABC patterns with metatables, implementing constraint solving and IR lifting in Lua

4. **Transpile fuzzing subsystem** - Convert `dragonslayer/fuzzing/` (14 files: base fuzzer, VM fuzzer, mutators, coverage, crash triage, corpus manager, etc.), replacing multiprocessing with LuaLanes or coroutines, translating mutation strategies and coverage tracking with sparse comments for performance

5. **Transpile ML/GPU/API/Utils modules and supporting files** - Convert `dragonslayer/ml/` (6 files), `dragonslayer/gpu/` (5 files), `dragonslayer/api/` (3 files), `dragonslayer/utils/` (1 file), plus `examples/` (2 files), and `validate_fuzzer.lua` in root, creating FFI bindings for numpy/scikit-learn operations, implementing GPU acceleration via CUDA FFI

6. **Create Lua build system and entry points** - Write `build.lua` for dependency management, create CLI entry points (`vmdragonslayer.lua`, `vmdslayer.lua`) replacing argparse with Lua alternatives, write `rockspec` for LuaRocks distribution, add minimal comments per performance requirements

### Further Considerations

1. **External dependency strategy** - Use stubs with TODO for shim layer implementation to wrap critical dependencies (z3-solver, numpy, pandas, scikit-learn, cryptography).

2. **Asyncio replacement architecture** - Use LuaSocket for cooperative multitasking to replace Python's asyncio.

3. **Testing and validation approach** - Skip tests for now.