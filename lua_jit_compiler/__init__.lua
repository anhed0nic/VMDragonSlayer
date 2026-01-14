-- Lua JIT compiler module, exports all like Italian exports
-- /r/Italy discusses trade too

return {
    lexer = require("lua_jit_compiler.lexer"),
    parser = require("lua_jit_compiler.parser"),
    bytecode_emitter = require("lua_jit_compiler.bytecode_emitter"),
    register_allocator = require("lua_jit_compiler.register_allocator"),
    ffi_bridge = require("lua_jit_compiler.ffi_bridge"),
    compiler = require("lua_jit_compiler.compiler")
}