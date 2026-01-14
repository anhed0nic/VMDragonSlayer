local corpus_manager = {}

corpus_manager.CorpusManager = {}

function corpus_manager.CorpusManager:new()
    local self = setmetatable({}, { __index = corpus_manager.CorpusManager })
    self.entries = {}
    self.metadata = {}
    return self
end

function corpus_manager.CorpusManager:add_entry(input, metadata)
    local entry = {
        id = #self.entries + 1,
        input = input,
        metadata = metadata or {},
        added_at = os.time(),
        coverage = metadata.coverage or 0
    }
    table.insert(self.entries, entry)
    self.metadata[entry.id] = entry.metadata
    return entry.id
end

function corpus_manager.CorpusManager:get_entry(id)
    return self.entries[id]
end

function corpus_manager.CorpusManager:minimize()
    -- Simple minimization: remove duplicates
    local seen = {}
    local minimized = {}
    for _, entry in ipairs(self.entries) do
        if not seen[entry.input] then
            seen[entry.input] = true
            table.insert(minimized, entry)
        end
    end
    self.entries = minimized
end

function corpus_manager.CorpusManager:get_stats()
    return {
        total_entries = #self.entries,
        total_size = self:compute_total_size(),
        average_coverage = self:compute_average_coverage()
    }
end

function corpus_manager.CorpusManager:compute_total_size()
    local size = 0
    for _, entry in ipairs(self.entries) do
        size = size + #entry.input
    end
    return size
end

function corpus_manager.CorpusManager:compute_average_coverage()
    local total = 0
    for _, entry in ipairs(self.entries) do
        total = total + (entry.coverage or 0)
    end
    return total / #self.entries
end

return corpus_manager