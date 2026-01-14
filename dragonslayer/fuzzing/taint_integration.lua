local taint_integration = {}

taint_integration.TaintGuidedMutator = {}

function taint_integration.TaintGuidedMutator:new()
    local self = setmetatable({}, { __index = taint_integration.TaintGuidedMutator })
    self.taint_engine = require("dragonslayer.analysis.taint_tracking").TaintEngine:new()
    self.mutations = {}
    return self
end

function taint_integration.TaintGuidedMutator:track_execution(input, coverage_hint)
    -- Track taint during execution
    self.taint_engine:taint_memory(0, #input)  -- Taint input data

    -- Simulate execution and taint propagation
    for i = 1, #input do
        if self.taint_engine:is_tainted_memory(i) then
            self.taint_engine:taint_register("eax")  -- Example propagation
        end
    end

    local taint_info = {
        tainted_memory = {},
        tainted_registers = {},
        propagation_paths = {}
    }

    -- Collect tainted locations
    for addr = 0, #input do
        if self.taint_engine:is_tainted_memory(addr) then
            table.insert(taint_info.tainted_memory, addr)
        end
    end

    for reg, tainted in pairs(self.taint_engine.tainted_registers) do
        if tainted then
            table.insert(taint_info.tainted_registers, reg)
        end
    end

    return taint_info
end

function taint_integration.TaintGuidedMutator:generate_mutations(taint_info, base_input)
    local mutations = {}

    -- Generate mutations based on tainted locations
    for _, addr in ipairs(taint_info.tainted_memory) do
        if addr > 0 and addr <= #base_input then
            -- Flip byte at tainted location
            local mutated = base_input:sub(1, addr-1) .. string.char(bit.bxor(string.byte(base_input, addr), 0xFF)) .. base_input:sub(addr+1)
            table.insert(mutations, {
                data = mutated,
                type = "taint_guided_flip",
                location = addr
            })
        end
    end

    -- Generate mutations for tainted registers (conceptual)
    for _, reg in ipairs(taint_info.tainted_registers) do
        local mutated = base_input .. "_reg_" .. reg  -- Dummy mutation
        table.insert(mutations, {
            data = mutated,
            type = "register_influence",
            register = reg
        })
    end

    self.mutations = mutations
    return mutations
end

function taint_integration.TaintGuidedMutator:analyze_crash_taint(crash_info, input_data)
    -- Analyze taint in crash context
    local crash_taint = {
        crash_relevant_taint = {},
        propagation_to_crash = {},
        exploitability_hints = {}
    }

    -- Check if crash location was tainted
    if crash_info.address then
        local addr_num = tonumber(crash_info.address, 16) or 0
        if self.taint_engine:is_tainted_memory(addr_num) then
            table.insert(crash_taint.crash_relevant_taint, {
                type = "memory",
                address = crash_info.address,
                tainted = true
            })
            table.insert(crash_taint.exploitability_hints, "Crash location controllable via input")
        end
    end

    return crash_taint
end

function taint_integration.TaintGuidedMutator:get_mutation_stats()
    return {
        total_mutations = #self.mutations,
        mutation_types = self:count_mutation_types(),
        taint_coverage = self.taint_engine:get_summary()
    }
end

function taint_integration.TaintGuidedMutator:count_mutation_types()
    local types = {}
    for _, mutation in ipairs(self.mutations) do
        types[mutation.type] = (types[mutation.type] or 0) + 1
    end
    return types
end

return taint_integration