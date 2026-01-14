local input_generation = {}

input_generation.InputGenerator = {}

function input_generation.InputGenerator:new()
    local self = setmetatable({}, { __index = input_generation.InputGenerator })
    self.generators = {
        random = self.generate_random,
        grammar = self.generate_grammar,
        template = self.generate_template
    }
    return self
end

function input_generation.InputGenerator:generate(generation_type, params)
    local generator = self.generators[generation_type]
    if generator then
        return generator(self, params)
    else
        return self:generate_random(params)
    end
end

function input_generation.InputGenerator:generate_random(params)
    params = params or {}
    local length = params.length or math.random(1, 100)
    local data = ""
    for i = 1, length do
        data = data .. string.char(math.random(0, 255))
    end
    return data
end

function input_generation.InputGenerator:generate_grammar(params)
    params = params or {}
    local grammar = params.grammar or {
        start = {"expr"},
        expr = {"num", "num op num"},
        num = {"0", "1", "42"},
        op = {"+", "-", "*"}
    }

    local function expand(symbol)
        local rules = grammar[symbol]
        if not rules then return symbol end
        local rule = rules[math.random(#rules)]
        local parts = {}
        for part in rule:gmatch("%S+") do
            table.insert(parts, expand(part))
        end
        return table.concat(parts, " ")
    end

    return expand("start")
end

function input_generation.InputGenerator:generate_template(params)
    params = params or {}
    local template = params.template or "PREFIX_DATA_SUFFIX"
    local placeholders = {
        PREFIX = "PRE",
        DATA = string.rep("X", math.random(5, 20)),
        SUFFIX = "END"
    }

    for placeholder, value in pairs(placeholders) do
        template = template:gsub(placeholder, value)
    end

    return template
end

function input_generation.InputGenerator:batch_generate(count, generation_type, params)
    local inputs = {}
    for i = 1, count do
        table.insert(inputs, self:generate(generation_type, params))
    end
    return inputs
end

return input_generation