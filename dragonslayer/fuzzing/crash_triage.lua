local crash_triage = {}

crash_triage.CrashAnalyzer = {}

function crash_triage.CrashAnalyzer:new()
    local self = setmetatable({}, { __index = crash_triage.CrashAnalyzer })
    self.crashes = {}
    self.unique_crashes = {}
    return self
end

function crash_triage.CrashAnalyzer:analyze_crash(input, crash_info)
    local crash_hash = self:hash_crash(crash_info)
    if not self.unique_crashes[crash_hash] then
        self.unique_crashes[crash_hash] = {
            input = input,
            info = crash_info,
            count = 1,
            first_seen = os.time(),
            exploitability = self:assess_exploitability(crash_info)
        }
        table.insert(self.crashes, self.unique_crashes[crash_hash])
        return true  -- New crash
    else
        self.unique_crashes[crash_hash].count = self.unique_crashes[crash_hash].count + 1
        return false
    end
end

function crash_triage.CrashAnalyzer:hash_crash(crash_info)
    -- Simple hash based on crash type and location
    return tostring(crash_info.type) .. "_" .. tostring(crash_info.location or 0)
end

function crash_triage.CrashAnalyzer:assess_exploitability(crash_info)
    -- Dummy exploitability assessment
    if crash_info.type == "segfault" then
        return "high"
    elseif crash_info.type == "assertion" then
        return "low"
    else
        return "medium"
    end
end

function crash_triage.CrashAnalyzer:get_summary()
    return {
        total_crashes = #self.crashes,
        unique_crashes = self.unique_crashes,
        stats = self:compute_stats()
    }
end

function crash_triage.CrashAnalyzer:compute_stats()
    local stats = {high = 0, medium = 0, low = 0}
    for _, crash in pairs(self.unique_crashes) do
        stats[crash.exploitability] = stats[crash.exploitability] + 1
    end
    return stats
end

return crash_triage