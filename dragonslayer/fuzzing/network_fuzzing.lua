-- OSHA COMPLIANCE NOTICE (29 CFR 1910.120 - Hazardous Waste Operations)
-- WARNING: Network fuzzing can cause network security hazards, data breaches, and system compromise.
-- PPE Required: Network isolation, firewall monitoring, intrusion detection systems.
-- Containment: Operate in isolated network segments with no production connectivity.
-- Emergency Response: Immediate network isolation if security breaches detected.

local network_fuzzing = {}

network_fuzzing.NetworkFuzzer = {}

function network_fuzzing.NetworkFuzzer:new(target_host, target_port)
    local self = setmetatable({}, { __index = network_fuzzing.NetworkFuzzer })
    self.host = target_host
    self.port = target_port
    self.socket = require("socket")
    self.test_cases = {}
    self.responses = {}
    return self
end

function network_fuzzing.NetworkFuzzer:add_test_case(data, description)
    table.insert(self.test_cases, {
        data = data,
        description = description or "test case",
        id = #self.test_cases + 1
    })
end

function network_fuzzing.NetworkFuzzer:fuzz_network(max_iterations)
    max_iterations = max_iterations or 100
    local results = {}

    for i = 1, max_iterations do
        local test_case = self.test_cases[math.random(#self.test_cases)]
        local mutated = self:mutate_network_data(test_case.data)

        local response = self:send_receive(mutated)
        local result = {
            test_id = test_case.id,
            input = mutated,
            response = response,
            success = response ~= nil,
            iteration = i
        }

        table.insert(results, result)
        table.insert(self.responses, result)

        if i % 10 == 0 then
            print("Network fuzzing: " .. i .. "/" .. max_iterations .. " iterations")
        end
    end

    return results
end

function network_fuzzing.NetworkFuzzer:mutate_network_data(data)
    -- Network-specific mutations
    local mutations = {
        function(d) return d .. "\x00" end,  -- Null termination
        function(d) return string.rep(d, 2) end,  -- Duplication
        function(d) return d:sub(1, #d//2) end,  -- Truncation
        function(d) return d .. string.char(math.random(0, 255)) end,  -- Append random
    }

    local mutation = mutations[math.random(#mutations)]
    return mutation(data)
end

function network_fuzzing.NetworkFuzzer:send_receive(data)
    local client = self.socket.tcp()
    client:settimeout(5)

    local success, err = client:connect(self.host, self.port)
    if not success then
        return nil, err
    end

    client:send(data)
    local response, err = client:receive()
    client:close()

    return response, err
end

function network_fuzzing.NetworkFuzzer:get_fuzz_stats()
    local stats = {
        total_tests = #self.responses,
        successful_connections = 0,
        failed_connections = 0,
        unique_responses = {}
    }

    for _, resp in ipairs(self.responses) do
        if resp.success then
            stats.successful_connections = stats.successful_connections + 1
            stats.unique_responses[resp.response or "nil"] = true
        else
            stats.failed_connections = stats.failed_connections + 1
        end
    end

    stats.unique_response_count = 0
    for _ in pairs(stats.unique_responses) do
        stats.unique_response_count = stats.unique_response_count + 1
    end

    return stats
end

return network_fuzzing