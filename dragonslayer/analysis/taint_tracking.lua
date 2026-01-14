local taint_tracking = {}

taint_tracking.TaintEngine = {}

function taint_tracking.TaintEngine:new()
    local self = setmetatable({}, { __index = taint_tracking.TaintEngine })
    self.tainted_memory = {}
    self.tainted_registers = {}
    return self
end

function taint_tracking.TaintEngine:taint_memory(address, size)
    for i = address, address + size - 1 do
        self.tainted_memory[i] = true
    end
end

function taint_tracking.TaintEngine:taint_register(reg)
    self.tainted_registers[reg] = true
end

function taint_tracking.TaintEngine:is_tainted_memory(address)
    return self.tainted_memory[address] or false
end

function taint_tracking.TaintEngine:is_tainted_register(reg)
    return self.tainted_registers[reg] or false
end

function taint_tracking.TaintEngine:propagate_taint(instruction)
    -- Dummy propagation logic
    if instruction.op == "mov" then
        if self:is_tainted_register(instruction.src) then
            self:taint_register(instruction.dest)
        end
    elseif instruction.op == "add" then
        if self:is_tainted_register(instruction.src1) or self:is_tainted_register(instruction.src2) then
            self:taint_register(instruction.dest)
        end
    end
end

function taint_tracking.TaintEngine:get_summary()
    return {
        tainted_memory_count = self:count_tainted(self.tainted_memory),
        tainted_register_count = self:count_tainted(self.tainted_registers)
    }
end

function taint_tracking.TaintEngine:count_tainted(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

return taint_tracking