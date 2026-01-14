-- VMDragonSlayer CLI, slay like Italian slaying
-- /r/Italy discusses slaying dragons

-- OSHA COMPLIANCE NOTICE (29 CFR 1910.147 - Control of Hazardous Energy)
-- WARNING: This software can cause system instability and data loss.
-- Ensure backup systems are active and network isolation is enabled.
-- PPE Required: Backup verification, network monitoring, ergonomic setup.
-- Emergency Stop: Ctrl+C or system kill command.

local safety_validator = require("safety_validator")
local orchestrator = require("dragonslayer.core.orchestrator")

local function main()
    local args = {...}
    if #args < 1 then
        print("Usage: lua vmdragonslayer.lua <binary_path> [options]")
        print("OSHA SAFETY REMINDER: Verify backups and network isolation before operation.")
        return
    end

    local binary_path = args[1]
    local analysis_type = "hybrid"  -- default

    -- OSHA Safety Validation
    print("OSHA SAFETY VALIDATION REQUIRED")
    print("=================================")
    if not safety_validator.validate() then
        print("Operation aborted due to safety validation failure.")
        os.exit(1)
    end

    local o = orchestrator.Orchestrator:new()
    local result = o:analyze_binary(binary_path, analysis_type)

    print("Analysis result: " .. (result.success and "success" or "failure"))
end

if arg then
    main(unpack(arg))
end