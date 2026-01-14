local pattern_analysis = {}

pattern_analysis.PatternAnalyzer = {}

function pattern_analysis.PatternAnalyzer:new()
    local self = setmetatable({}, { __index = pattern_analysis.PatternAnalyzer })
    self.patterns = {}
    self.database = {}
    return self
end

function pattern_analysis.PatternAnalyzer:add_pattern(name, pattern, category)
    self.patterns[name] = {
        regex = pattern,
        category = category,
        matches = 0
    }
end

function pattern_analysis.PatternAnalyzer:analyze(data)
    local results = {}
    for name, pattern_info in pairs(self.patterns) do
        local matches = {}
        local start = 1
        while true do
            local s, e = string.find(data, pattern_info.regex, start)
            if not s then break end
            table.insert(matches, {start = s, end_pos = e, match = string.sub(data, s, e)})
            start = e + 1
        end

        if #matches > 0 then
            pattern_info.matches = pattern_info.matches + #matches
            table.insert(results, {
                pattern = name,
                category = pattern_info.category,
                matches = matches,
                count = #matches
            })
        end
    end
    return results
end

function pattern_analysis.PatternAnalyzer:cluster_patterns()
    -- Dummy clustering
    local clusters = {}
    for name, info in pairs(self.patterns) do
        local category = info.category
        if not clusters[category] then
            clusters[category] = {}
        end
        table.insert(clusters[category], name)
    end
    return clusters
end

function pattern_analysis.PatternAnalyzer:get_statistics()
    local stats = {
        total_patterns = 0,
        total_matches = 0,
        categories = {}
    }

    for name, info in pairs(self.patterns) do
        stats.total_patterns = stats.total_patterns + 1
        stats.total_matches = stats.total_matches + info.matches

        local cat = info.category
        if not stats.categories[cat] then
            stats.categories[cat] = {count = 0, matches = 0}
        end
        stats.categories[cat].count = stats.categories[cat].count + 1
        stats.categories[cat].matches = stats.categories[cat].matches + info.matches
    end

    return stats
end

function pattern_analysis.PatternAnalyzer:export_patterns()
    return self.patterns
end

return pattern_analysis