local coverage = {}

coverage.CoverageTracker = {}

function coverage.CoverageTracker:new()
    local self = setmetatable({}, { __index = coverage.CoverageTracker })
    self.edges = {}
    self.blocks = {}
    self.total_edges = 0
    self.total_blocks = 0
    return self
end

function coverage.CoverageTracker:record_execution(trace)
    local new_edges = 0
    local new_blocks = 0
    for _, edge in ipairs(trace.edges or {}) do
        if not self.edges[edge] then
            self.edges[edge] = true
            new_edges = new_edges + 1
        end
    end
    for _, block in ipairs(trace.blocks or {}) do
        if not self.blocks[block] then
            self.blocks[block] = true
            new_blocks = new_blocks + 1
        end
    end
    self.total_edges = self.total_edges + new_edges
    self.total_blocks = self.total_blocks + new_blocks
    return new_edges > 0 or new_blocks > 0  -- New coverage
end

function coverage.CoverageTracker:get_stats()
    return {
        edges_covered = self.total_edges,
        blocks_covered = self.total_blocks,
        edge_map = self.edges,
        block_map = self.blocks
    }
end

return coverage