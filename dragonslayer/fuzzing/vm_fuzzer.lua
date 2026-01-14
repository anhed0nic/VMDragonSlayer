local base_fuzzer = require("dragonslayer.fuzzing.base_fuzzer")

local vm_fuzzer = {}

vm_fuzzer.VMFuzzer = setmetatable({}, { __index = base_fuzzer.BaseFuzzer })

function vm_fuzzer.VMFuzzer:new(config)
    local self = base_fuzzer.BaseFuzzer:new(config)
    setmetatable(self, { __index = vm_fuzzer.VMFuzzer })
    self.vm_analysis = require("dragonslayer.analysis.vm_analysis") or {}
    return self
end

function vm_fuzzer.VMFuzzer:execute(input)
    -- VM-aware execution
    local vm_result = self.vm_analysis.analyze(input)
    local base_result = base_fuzzer.BaseFuzzer.execute(self, input)
    return {output = base_result.output, crash = base_result.crash, vm_info = vm_result}
end

function vm_fuzzer.VMFuzzer:mutate(input)
    -- VM-specific mutations
    local base_mutated = base_fuzzer.BaseFuzzer.mutate(self, input)
    -- Add VM-specific mutation
    return base_mutated .. "\x00"  -- Append null byte
end

return vm_fuzzer