local anti_evasion = {}

anti_evasion.AntiEvasionEngine = {}

function anti_evasion.AntiEvasionEngine:new()
    local self = setmetatable({}, { __index = anti_evasion.AntiEvasionEngine })
    self.techniques = {}
    self.detections = {}
    return self
end

function anti_evasion.AntiEvasionEngine:add_technique(name, detector)
    self.techniques[name] = detector
end

function anti_evasion.AntiEvasionEngine:detect_evasion(data, context)
    local results = {}
    for name, detector in pairs(self.techniques) do
        local detected = detector(data, context)
        if detected then
            table.insert(results, {
                technique = name,
                detected = true,
                confidence = detected.confidence or 1.0,
                details = detected.details or {}
            })
            self.detections[name] = (self.detections[name] or 0) + 1
        end
    end
    return results
end

function anti_evasion.AntiEvasionEngine:default_detectors()
    -- Timing-based detection
    self:add_technique("timing_anomaly", function(data, context)
        if context and context.execution_time then
            if context.execution_time < 0.001 then  -- Too fast
                return {confidence = 0.8, details = {reason = "execution too fast"}}
            elseif context.execution_time > 10 then  -- Too slow
                return {confidence = 0.6, details = {reason = "execution too slow"}}
            end
        end
        return nil
    end)

    -- Size-based detection
    self:add_technique("size_anomaly", function(data, context)
        local size = #data
        if size < 10 then
            return {confidence = 0.9, details = {reason = "input too small"}}
        elseif size > 1000000 then
            return {confidence = 0.7, details = {reason = "input too large"}}
        end
        return nil
    end)

    -- Entropy-based detection
    self:add_technique("entropy_anomaly", function(data, context)
        local entropy = self:calculate_entropy(data)
        if entropy < 2.0 then
            return {confidence = 0.5, details = {reason = "low entropy", entropy = entropy}}
        elseif entropy > 7.5 then
            return {confidence = 0.4, details = {reason = "high entropy", entropy = entropy}}
        end
        return nil
    end)
end

function anti_evasion.AntiEvasionEngine:calculate_entropy(data)
    local freq = {}
    for i = 1, #data do
        local byte = string.byte(data, i)
        freq[byte] = (freq[byte] or 0) + 1
    end

    local entropy = 0
    local len = #data
    for _, count in pairs(freq) do
        local p = count / len
        entropy = entropy - p * math.log(p) / math.log(2)
    end
    return entropy
end

function anti_evasion.AntiEvasionEngine:get_detection_stats()
    return {
        techniques_active = self:count_keys(self.techniques),
        total_detections = self:sum_values(self.detections),
        detections_by_technique = self.detections
    }
end

function anti_evasion.AntiEvasionEngine:count_keys(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

function anti_evasion.AntiEvasionEngine:sum_values(tbl)
    local sum = 0
    for _, v in pairs(tbl) do sum = sum + v end
    return sum
end

return anti_evasion