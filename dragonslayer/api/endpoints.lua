local api = require("dragonslayer.api.server")
local orchestrator = require("dragonslayer.core.orchestrator")

local endpoints = {}

function endpoints.setup_routes(server)
    -- Status endpoint
    server:add_route("/status", "GET", function()
        local o = orchestrator.Orchestrator:new()
        local status = o:get_status()
        return require("json").encode(status)  -- Assuming json library
    end)

    -- Analyze endpoint
    server:add_route("/analyze", "POST", function()
        -- Dummy POST handling
        local o = orchestrator.Orchestrator:new()
        local result = o:analyze_binary("dummy.exe")
        return require("json").encode({
            success = result.success,
            analysis_type = result.analysis_type,
            errors = result.errors,
            metrics = result.metrics
        })
    end)

    -- Fuzz endpoint
    server:add_route("/fuzz", "POST", function()
        local fuzzer = require("dragonslayer.fuzzing.vm_fuzzer").VMFuzzer:new()
        local stats = fuzzer:fuzz({"test_input"}, 10)
        return require("json").encode(stats)
    end)

    -- Results endpoint
    server:add_route("/results", "GET", function()
        return require("json").encode({
            total_analyses = 42,
            crashes_found = 7,
            patterns_detected = 15
        })
    end)
end

function endpoints.create_server(port)
    local server = api.APIServer:new(port)
    endpoints.setup_routes(server)
    return server
end

return endpoints