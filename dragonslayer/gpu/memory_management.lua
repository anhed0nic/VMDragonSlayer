local gpu = require("dragonslayer.gpu.engine")

local memory_management = {}

memory_management.MemoryManager = setmetatable({}, { __index = gpu.GPUEngine })

function memory_management.MemoryManager:new()
    local self = gpu.GPUEngine:new()
    setmetatable(self, { __index = memory_management.MemoryManager })
    self.allocated_blocks = {}
    self.cache = {}
    return self
end

function memory_management.MemoryManager:allocate(size, persistent)
    local block = gpu.GPUEngine.allocate_memory(self, size)
    if persistent then
        table.insert(self.allocated_blocks, block)
    end
    return block
end

function memory_management.MemoryManager:deallocate(block)
    gpu.GPUEngine.free_memory(self, block)
    for i, b in ipairs(self.allocated_blocks) do
        if b == block then
            table.remove(self.allocated_blocks, i)
            break
        end
    end
end

function memory_management.MemoryManager:cache_data(key, data)
    self.cache[key] = data
end

function memory_management.MemoryManager:get_cached(key)
    return self.cache[key]
end

function memory_management.MemoryManager:clear_cache()
    self.cache = {}
end

function memory_management.MemoryManager:optimize_memory()
    -- Dummy optimization: free non-persistent blocks
    local new_pool = {}
    for _, block in ipairs(self.memory_pool) do
        local is_persistent = false
        for _, p_block in ipairs(self.allocated_blocks) do
            if p_block == block then
                is_persistent = true
                break
            end
        end
        if is_persistent then
            table.insert(new_pool, block)
        end
    end
    self.memory_pool = new_pool
end

function memory_management.MemoryManager:get_fragmentation_stats()
    -- Dummy fragmentation analysis
    return {
        fragmentation_ratio = math.random(),
        largest_free_block = math.random(100000, 1000000),
        total_free_memory = math.random(100000, 500000)
    }
end

return memory_management