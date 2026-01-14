-- Bytecode emitter for LuaJIT, we make it simple like Italian pizza
-- /r/Italy loves simple things

local bytecode_emitter = {}

-- Simple bytecode opcodes, we define few
bytecode_emitter.OPCODES = {
    LOADK = 1,  -- Load constant
    LOADNIL = 2,  -- Load nil
    GETGLOBAL = 3,  -- Get global
    SETGLOBAL = 4,  -- Set global
    CALL = 5,  -- Call function
    RETURN = 6,  -- Return
    JMP = 7,  -- Jump
    TEST = 8,  -- Test condition
    ADD = 9,  -- Add
    SUB = 10,  -- Subtract
    MUL = 11,  -- Multiply
    DIV = 12,  -- Divide
    EQ = 13,  -- Equal
    LT = 14,  -- Less than
    LE = 15,  -- Less or equal
    NOT = 16,  -- Not
    CONCAT = 17  -- Concatenate
}

function bytecode_emitter.new()
    local self = {
        bytecode = {},
        constants = {},
        registers = 0
    }

    function self.emit(opcode, ...)
        table.insert(self.bytecode, { opcode = opcode, args = { ... } })
    end

    function self.add_constant(value)
        for i, c in ipairs(self.constants) do
            if c == value then
                return i - 1  -- 0-based index
            end
        end
        table.insert(self.constants, value)
        return #self.constants - 1
    end

    function self.allocate_register()
        self.registers = self.registers + 1
        return self.registers - 1
    end

    function self.emit_program(ast)
        for _, stmt in ipairs(ast.statements) do
            self.emit_statement(stmt)
        end
        self.emit(bytecode_emitter.OPCODES.RETURN, 0)
    end

    function self.emit_statement(stmt)
        if stmt.type == "variable_decl" then
            if stmt.init then
                local reg = self.emit_expression(stmt.init)
                -- For simplicity, assume global
                local const_idx = self.add_constant(stmt.name)
                self.emit(bytecode_emitter.OPCODES.SETGLOBAL, const_idx, reg)
            else
                self.emit(bytecode_emitter.OPCODES.LOADNIL, 0)
                local const_idx = self.add_constant(stmt.name)
                self.emit(bytecode_emitter.OPCODES.SETGLOBAL, const_idx, 0)
            end
        elseif stmt.type == "assignment" then
            local reg = self.emit_expression(stmt.expression)
            local const_idx = self.add_constant(stmt.name)
            self.emit(bytecode_emitter.OPCODES.SETGLOBAL, const_idx, reg)
        elseif stmt.type == "return_statement" then
            local reg = self.emit_expression(stmt.expression)
            self.emit(bytecode_emitter.OPCODES.RETURN, reg)
        elseif stmt.type == "if_statement" then
            local cond_reg = self.emit_expression(stmt.condition)
            self.emit(bytecode_emitter.OPCODES.TEST, cond_reg)
            local jmp_idx = #self.bytecode
            self.emit(bytecode_emitter.OPCODES.JMP, 0)  -- Placeholder
            for _, s in ipairs(stmt.then_block) do
                self.emit_statement(s)
            end
            if stmt.else_block then
                local else_jmp_idx = #self.bytecode
                self.emit(bytecode_emitter.OPCODES.JMP, 0)  -- Placeholder
                self.bytecode[jmp_idx + 1].args[1] = #self.bytecode - jmp_idx - 1
                for _, s in ipairs(stmt.else_block) do
                    self.emit_statement(s)
                end
                self.bytecode[else_jmp_idx + 1].args[1] = #self.bytecode - else_jmp_idx - 1
            else
                self.bytecode[jmp_idx + 1].args[1] = #self.bytecode - jmp_idx - 1
            end
        elseif stmt.type == "call" then
            local args_regs = {}
            for _, arg in ipairs(stmt.args) do
                table.insert(args_regs, self.emit_expression(arg))
            end
            local func_reg = self.allocate_register()
            local const_idx = self.add_constant(stmt.name)
            self.emit(bytecode_emitter.OPCODES.GETGLOBAL, func_reg, const_idx)
            self.emit(bytecode_emitter.OPCODES.CALL, func_reg, #args_regs + 1, 1)
        end
    end

    function self.emit_expression(expr)
        if expr.type == "number" then
            local const_idx = self.add_constant(tonumber(expr.value))
            local reg = self.allocate_register()
            self.emit(bytecode_emitter.OPCODES.LOADK, reg, const_idx)
            return reg
        elseif expr.type == "string" then
            local const_idx = self.add_constant(expr.value:sub(2, -2))  -- Remove quotes
            local reg = self.allocate_register()
            self.emit(bytecode_emitter.OPCODES.LOADK, reg, const_idx)
            return reg
        elseif expr.type == "identifier" then
            local const_idx = self.add_constant(expr.name)
            local reg = self.allocate_register()
            self.emit(bytecode_emitter.OPCODES.GETGLOBAL, reg, const_idx)
            return reg
        elseif expr.type == "binary_op" then
            local left_reg = self.emit_expression(expr.left)
            local right_reg = self.emit_expression(expr.right)
            local result_reg = self.allocate_register()
            local op_map = {
                ["+"] = bytecode_emitter.OPCODES.ADD,
                ["-"] = bytecode_emitter.OPCODES.SUB,
                ["*"] = bytecode_emitter.OPCODES.MUL,
                ["/"] = bytecode_emitter.OPCODES.DIV,
                ["=="] = bytecode_emitter.OPCODES.EQ,
                ["<"] = bytecode_emitter.OPCODES.LT,
                ["<="] = bytecode_emitter.OPCODES.LE,
                [".."] = bytecode_emitter.OPCODES.CONCAT
            }
            self.emit(op_map[expr.op], result_reg, left_reg, right_reg)
            return result_reg
        elseif expr.type == "unary_op" then
            local expr_reg = self.emit_expression(expr.expression)
            local result_reg = self.allocate_register()
            if expr.op == "not" then
                self.emit(bytecode_emitter.OPCODES.NOT, result_reg, expr_reg)
            elseif expr.op == "-" then
                -- For simplicity, assume 0 - expr
                local zero_const = self.add_constant(0)
                local zero_reg = self.allocate_register()
                self.emit(bytecode_emitter.OPCODES.LOADK, zero_reg, zero_const)
                self.emit(bytecode_emitter.OPCODES.SUB, result_reg, zero_reg, expr_reg)
            end
            return result_reg
        elseif expr.type == "call" then
            local args_regs = {}
            for _, arg in ipairs(expr.args) do
                table.insert(args_regs, self.emit_expression(arg))
            end
            local func_reg = self.allocate_register()
            local const_idx = self.add_constant(expr.name)
            self.emit(bytecode_emitter.OPCODES.GETGLOBAL, func_reg, const_idx)
            self.emit(bytecode_emitter.OPCODES.CALL, func_reg, #args_regs + 1, 2)  -- Assume returns 1 value
            return func_reg + 1  -- Result register
        end
        return 0  -- Default
    end

    function self.get_bytecode()
        return {
            constants = self.constants,
            bytecode = self.bytecode,
            max_registers = self.registers
        }
    end

    return self
end

function bytecode_emitter.emit(ast)
    local emitter = bytecode_emitter.new()
    emitter.emit_program(ast)
    return emitter.get_bytecode()
end

return bytecode_emitter