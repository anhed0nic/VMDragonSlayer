local mutators = {}

mutators.MutationType = {
    BIT_FLIP = "bit_flip",
    BYTE_FLIP = "byte_flip",
    ARITHMETIC = "arithmetic",
    HAVOC = "havoc"
}

function mutators.bit_flip(input)
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    local bit = math.random(0, 7)
    byte = bit.bxor(byte, bit.lshift(1, bit))
    return input:sub(1, pos-1) .. string.char(byte) .. input:sub(pos+1)
end

function mutators.byte_flip(input)
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    byte = bit.bxor(byte, 0xFF)
    return input:sub(1, pos-1) .. string.char(byte) .. input:sub(pos+1)
end

function mutators.arithmetic(input)
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    local delta = math.random(-35, 35)
    byte = (byte + delta) % 256
    return input:sub(1, pos-1) .. string.char(byte) .. input:sub(pos+1)
end

function mutators.havoc(input)
    local mutated = input
    for i = 1, math.random(1, 16) do
        local mutation_type = ({mutators.bit_flip, mutators.byte_flip, mutators.arithmetic})[math.random(3)]
        mutated = mutation_type(mutated)
    end
    return mutated
end

function mutators.mutate(input, strategy)
    strategy = strategy or mutators.MutationType.BIT_FLIP
    if strategy == mutators.MutationType.BIT_FLIP then
        return mutators.bit_flip(input)
    elseif strategy == mutators.MutationType.BYTE_FLIP then
        return mutators.byte_flip(input)
    elseif strategy == mutators.MutationType.ARITHMETIC then
        return mutators.arithmetic(input)
    elseif strategy == mutators.MutationType.HAVOC then
        return mutators.havoc(input)
    end
    return input
end

return mutators