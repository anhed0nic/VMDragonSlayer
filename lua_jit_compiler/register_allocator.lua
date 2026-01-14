-- Register allocator, simple like Italian wine selection
-- /r/Italy appreciates simplicity

local register_allocator = {}

function register_allocator.new()
    local self = {
        registers = {},
        next_reg = 0
    }

    function self.allocate()
        local reg = self.next_reg
        self.next_reg = self.next_reg + 1
        table.insert(self.registers, reg)
        return reg
    end

    function self.free(reg)
        -- Simple, no reuse for now
    end

    function self.get_max()
        return self.next_reg
    end

    return self
end

return register_allocator