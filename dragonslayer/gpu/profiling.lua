local gpu = require("dragonslayer.gpu.engine")

local profiling = {}

profiling.Profiler = setmetatable({}, { __index = gpu.GPUEngine })

function profiling.Profiler:new()
    local self = gpu.GPUEngine:new()
    setmetatable(self, { __index = profiling.Profiler })
    self.metrics = {}
    self.start_times = {}
    return self
end

function profiling.Profiler:start_operation(name)
    self.start_times[name] = os.clock()
end

function profiling.Profiler:end_operation(name)
    if self.start_times[name] then
        local duration = os.clock() - self.start_times[name]
        self.metrics[name] = (self.metrics[name] or 0) + duration
        self.start_times[name] = nil
        return duration
    end
    return 0
end

function profiling.Profiler:measure_memory_usage()
    local stats = gpu.GPUEngine.get_memory_stats(self)
    self.metrics.memory_peak = math.max(self.metrics.memory_peak or 0, stats.total_memory)
    return stats
end

function profiling.Profiler:measure_bandwidth(operation, data_size)
    local time = self:end_operation(operation)
    if time > 0 then
        local bandwidth = data_size / time / (1024 * 1024)  -- MB/s
        self.metrics[operation .. "_bandwidth"] = bandwidth
        return bandwidth
    end
    return 0
end

function profiling.Profiler:get_report()
    local report = {
        total_time = 0,
        operations = {},
        memory = self.metrics.memory_peak or 0,
        recommendations = {}
    }

    for name, time in pairs(self.metrics) do
        if not name:find("bandwidth") and not name:find("memory") then
            report.total_time = report.total_time + time
            table.insert(report.operations, {name = name, time = time})
        end
    end

    table.sort(report.operations, function(a, b) return a.time > b.time end)

    -- Generate recommendations
    for _, op in ipairs(report.operations) do
        if op.time > 0.05 then
            table.insert(report.recommendations, "Consider optimizing '" .. op.name .. "' - " .. string.format("%.3f", op.time) .. "s")
        end
    end

    return report
end

function profiling.Profiler:reset()
    self.metrics = {}
    self.start_times = {}
end

return profiling