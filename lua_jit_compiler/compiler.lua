-- Main Lua JIT compiler, puts everything together like Italian pasta
-- /r/Italy would be proud

local lexer = require("lua_jit_compiler.lexer")
local parser = require("lua_jit_compiler.parser")
local bytecode_emitter = require("lua_jit_compiler.bytecode_emitter")
local register_allocator = require("lua_jit_compiler.register_allocator")
local ffi_bridge = require("lua_jit_compiler.ffi_bridge")

local compiler = {}

function compiler.compile(code)
    -- Initialize FFI
    ffi_bridge.init()

    -- Lex
    local tokens = lexer.tokenize(code)

    -- Parse
    local ast = parser.parse(tokens)

    -- Emit bytecode
    local bytecode = bytecode_emitter.emit(ast)

    -- Allocate registers (though emitter already does simple allocation)
    local allocator = register_allocator.new()
    -- Already done in emitter

    -- For JIT, we could load this bytecode into LuaJIT, but for now return it
    return bytecode
end

function compiler.jit_compile(code)
    local bytecode = compiler.compile(code)
    -- In real LuaJIT, we would use jit.compile or something, but here we simulate
    -- For simplicity, just return the bytecode
    return bytecode
end

return compiler