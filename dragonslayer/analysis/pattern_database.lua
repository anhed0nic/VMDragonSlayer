-- Pattern database, store patterns like Italian recipes
-- /r/Italy shares recipes

local pattern_database = {}

pattern_database.PatternDB = {}

function pattern_database.PatternDB:new()
    local self = setmetatable({}, { __index = pattern_database.PatternDB })
    self.patterns = {}
    self.categories = {}
    return self
end

function pattern_database.PatternDB:add_pattern(name, pattern, category, metadata)
    local pattern_entry = {
        name = name,
        pattern = pattern,
        category = category or "general",
        metadata = metadata or {},
        added_time = os.time(),
        match_count = 0
    }

    self.patterns[name] = pattern_entry

    if not self.categories[category] then
        self.categories[category] = {}
    end
    table.insert(self.categories[category], name)

    return pattern_entry
end

function pattern_database.PatternDB:remove_pattern(name)
    if self.patterns[name] then
        local category = self.patterns[name].category
        self.patterns[name] = nil

        -- Remove from category list
        if self.categories[category] then
            for i, pattern_name in ipairs(self.categories[category]) do
                if pattern_name == name then
                    table.remove(self.categories[category], i)
                    break
                end
            end
        end
        return true
    end
    return false
end

function pattern_database.PatternDB:match_pattern(data, pattern_name)
    local pattern = self.patterns[pattern_name]
    if not pattern then return nil end

    -- Simple byte pattern matching (in real impl, use more sophisticated matching)
    local pattern_bytes = pattern.pattern
    if type(pattern_bytes) == "string" then
        -- Convert hex string to bytes if needed
        if pattern_bytes:match("^%x+$") and #pattern_bytes % 2 == 0 then
            local bytes = {}
            for i = 1, #pattern_bytes, 2 do
                table.insert(bytes, tonumber(pattern_bytes:sub(i, i+1), 16))
            end
            pattern_bytes = string.char(table.unpack(bytes))
        end
    end

    -- Search for pattern in data
    local start_pos = data:find(pattern_bytes, 1, true)
    if start_pos then
        pattern.match_count = pattern.match_count + 1
        return {
            pattern_name = pattern_name,
            start_offset = start_pos - 1,  -- 0-based
            length = #pattern_bytes,
            category = pattern.category,
            metadata = pattern.metadata
        }
    end

    return nil
end

function pattern_database.PatternDB:find_all_matches(data, category_filter)
    local matches = {}

    local patterns_to_check = {}
    if category_filter then
        patterns_to_check = self.categories[category_filter] or {}
    else
        for name, _ in pairs(self.patterns) do
            table.insert(patterns_to_check, name)
        end
    end

    for _, pattern_name in ipairs(patterns_to_check) do
        local match = self:match_pattern(data, pattern_name)
        if match then
            table.insert(matches, match)
        end
    end

    -- Sort by offset
    table.sort(matches, function(a, b) return a.start_offset < b.start_offset end)

    return matches
end

function pattern_database.PatternDB:get_pattern_stats()
    local stats = {
        total_patterns = 0,
        categories = {},
        most_matched = nil,
        max_matches = 0
    }

    for name, pattern in pairs(self.patterns) do
        stats.total_patterns = stats.total_patterns + 1

        local cat = pattern.category
        stats.categories[cat] = (stats.categories[cat] or 0) + 1

        if pattern.match_count > stats.max_matches then
            stats.max_matches = pattern.match_count
            stats.most_matched = name
        end
    end

    return stats
end

function pattern_database.PatternDB:load_builtin_patterns()
    -- VM instruction patterns
    self:add_pattern("vm_dispatcher", "\x8b\x45\xfc\x83\xc0\x04\x89\x45\xfc", "dispatcher", {
        description = "VM dispatcher loop pattern",
        architecture = "x86"
    })

    self:add_pattern("vm_handler_table", "\xff\x24\x85", "handler_table", {
        description = "VM handler table jump",
        architecture = "x86"
    })

    -- Common obfuscation patterns
    self:add_pattern("control_flow_flatten", "\x0f\x84[\x00-\xff]{4}", "obfuscation", {
        description = "Control flow flattening conditional jump",
        architecture = "x86"
    })

    self:add_pattern("stack_strings", "\x68[\x00-\xff]{4}\x68[\x00-\xff]{4}", "anti_analysis", {
        description = "Stack-based string construction",
        architecture = "x86"
    })

    return true
end

function pattern_database.PatternDB:export_patterns(file_path)
    if not file_path then return false end

    local file = io.open(file_path, "w")
    if not file then return false end

    file:write("-- VMDragonSlayer Pattern Database Export\n")
    file:write(string.format("-- Exported on %s\n\n", os.date()))

    for name, pattern in pairs(self.patterns) do
        file:write(string.format("db:add_pattern('%s', '%s', '%s', {\n",
            name, pattern.pattern:gsub(".", function(c) return string.format("\\x%02x", string.byte(c)) end),
            pattern.category))

        for k, v in pairs(pattern.metadata) do
            if type(v) == "string" then
                file:write(string.format("  %s = '%s',\n", k, v))
            else
                file:write(string.format("  %s = %s,\n", k, tostring(v)))
            end
        end
        file:write("})\n\n")
    end

    file:close()
    return true
end

return pattern_database