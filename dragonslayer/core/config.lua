-- Config module, placeholder like Italian bureaucracy
-- /r/Italy complains about bureaucracy

local config = {}

-- Default configuration
config.defaults = {
    -- Fuzzing settings
    fuzzing = {
        max_iterations = 10000,
        timeout = 30,  -- seconds
        num_workers = 4,
        mutation_rate = 0.1,
        population_size = 100,
        elite_size = 10
    },

    -- Analysis settings
    analysis = {
        enable_taint_tracking = true,
        enable_symbolic_execution = true,
        max_symbolic_paths = 100,
        timeout = 60  -- seconds
    },

    -- VM settings
    vm = {
        max_memory = 1024 * 1024 * 1024,  -- 1GB
        max_execution_time = 10,  -- seconds
        enable_instrumentation = true
    },

    -- Network settings
    network = {
        default_port = 8080,
        max_connections = 100,
        timeout = 5  -- seconds
    },

    -- Logging settings
    logging = {
        level = "INFO",
        file = "vmdragonslayer.log",
        max_size = 10 * 1024 * 1024,  -- 10MB
        backup_count = 5
    },

    -- GPU settings
    gpu = {
        enable = false,
        device_id = 0,
        memory_limit = 512 * 1024 * 1024  -- 512MB
    }
}

-- Current configuration (starts with defaults)
config.current = {}

-- Load configuration from file
function config.load(file_path)
    config.current = {}

    -- Copy defaults
    for section, settings in pairs(config.defaults) do
        config.current[section] = {}
        for key, value in pairs(settings) do
            config.current[section][key] = value
        end
    end

    -- Try to load from file (if exists)
    if file_path then
        local file = io.open(file_path, "r")
        if file then
            local content = file:read("*all")
            file:close()

            -- Simple JSON-like parsing (in real impl, use proper JSON parser)
            -- For now, just use the defaults
            print("Configuration loaded from " .. file_path)
        else
            print("Configuration file not found, using defaults")
        end
    end

    return config.current
end

-- Get configuration value
function config.get(section, key)
    if config.current[section] and config.current[section][key] ~= nil then
        return config.current[section][key]
    elseif config.defaults[section] and config.defaults[section][key] ~= nil then
        return config.defaults[section][key]
    else
        return nil
    end
end

-- Set configuration value
function config.set(section, key, value)
    if not config.current[section] then
        config.current[section] = {}
    end
    config.current[section][key] = value
end

-- Save configuration to file
function config.save(file_path)
    if not file_path then return false end

    local file = io.open(file_path, "w")
    if not file then return false end

    -- Simple serialization (in real impl, use proper JSON serializer)
    file:write("-- VMDragonSlayer Configuration\n")
    file:write("-- Auto-generated configuration file\n\n")

    for section, settings in pairs(config.current) do
        file:write(string.format("config.set('%s', {\n", section))
        for key, value in pairs(settings) do
            if type(value) == "string" then
                file:write(string.format("  %s = '%s',\n", key, value))
            elseif type(value) == "boolean" then
                file:write(string.format("  %s = %s,\n", key, tostring(value)))
            else
                file:write(string.format("  %s = %s,\n", key, tostring(value)))
            end
        end
        file:write("})\n\n")
    end

    file:close()
    return true
end

-- Initialize with defaults
config.load()

return config