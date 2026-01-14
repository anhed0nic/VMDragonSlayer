-- VMDragonSlayer CLI, slay like Italian slaying
-- /r/Italy discusses slaying dragons

local orchestrator = require("dragonslayer.core.orchestrator")

local function main()
    local args = {...}
    if #args < 1 then
        print("Usage: lua vmdragonslayer.lua <binary_path> [options]")
        return
    end

    local binary_path = args[1]
    local analysis_type = "hybrid"  -- default

    local o = orchestrator.Orchestrator:new()
    local result = o:analyze_binary(binary_path, analysis_type)

    print("Analysis result: " .. (result.success and "success" or "failure"))
end

if arg then
    main(unpack(arg))
end