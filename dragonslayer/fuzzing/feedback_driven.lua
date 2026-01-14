local feedback_driven = {}

feedback_driven.FeedbackMutator = {}

function feedback_driven.FeedbackMutator:new()
    local self = setmetatable({}, { __index = feedback_driven.FeedbackMutator })
    self.feedback_history = {}
    self.effectiveness_scores = {}
    self.mutation_strategies = {
        "bit_flip",
        "byte_flip",
        "arithmetic",
        "block_insert",
        "block_delete",
        "dictionary_based"
    }
    return self
end

function feedback_driven.FeedbackMutator:analyze_feedback(execution_results)
    -- Analyze execution results to update mutation effectiveness
    for _, result in ipairs(execution_results) do
        local mutation_type = result.mutation_type or "unknown"
        local score = self:calculate_effectiveness_score(result)

        if not self.effectiveness_scores[mutation_type] then
            self.effectiveness_scores[mutation_type] = {}
        end

        table.insert(self.effectiveness_scores[mutation_type], score)

        -- Keep only recent scores (sliding window)
        if #self.effectiveness_scores[mutation_type] > 100 then
            table.remove(self.effectiveness_scores[mutation_type], 1)
        end
    end

    -- Update strategy weights based on effectiveness
    self:update_strategy_weights()
end

function feedback_driven.FeedbackMutator:calculate_effectiveness_score(result)
    local score = 0

    -- Score based on coverage increase
    if result.new_coverage then
        score = score + result.new_coverage * 10
    end

    -- Score based on crash discovery
    if result.crash_found then
        score = score + 100
    end

    -- Score based on execution time (shorter is better)
    if result.execution_time then
        score = score + math.max(0, 10 - result.execution_time)
    end

    -- Penalty for invalid inputs
    if result.invalid_input then
        score = score - 20
    end

    return score
end

function feedback_driven.FeedbackMutator:update_strategy_weights()
    self.strategy_weights = {}

    for _, strategy in ipairs(self.mutation_strategies) do
        local scores = self.effectiveness_scores[strategy] or {}
        if #scores > 0 then
            local avg_score = 0
            for _, score in ipairs(scores) do
                avg_score = avg_score + score
            end
            avg_score = avg_score / #scores

            -- Weight based on average score, with minimum weight
            self.strategy_weights[strategy] = math.max(1, avg_score / 10)
        else
            self.strategy_weights[strategy] = 1  -- Default weight
        end
    end
end

function feedback_driven.FeedbackMutator:select_mutation_strategy()
    -- Select strategy based on weights (roulette wheel selection)
    local total_weight = 0
    for _, weight in pairs(self.strategy_weights) do
        total_weight = total_weight + weight
    end

    local selection = math.random() * total_weight
    local cumulative = 0

    for strategy, weight in pairs(self.strategy_weights) do
        cumulative = cumulative + weight
        if selection <= cumulative then
            return strategy
        end
    end

    -- Fallback to random strategy
    return self.mutation_strategies[math.random(#self.mutation_strategies)]
end

function feedback_driven.FeedbackMutator:generate_feedback_driven_mutations(base_input, num_mutations)
    num_mutations = num_mutations or 10
    local mutations = {}

    for i = 1, num_mutations do
        local strategy = self:select_mutation_strategy()
        local mutation = self:generate_mutation_by_strategy(base_input, strategy)

        if mutation then
            table.insert(mutations, {
                data = mutation,
                strategy = strategy,
                generation = i
            })
        end
    end

    return mutations
end

function feedback_driven.FeedbackMutator:generate_mutation_by_strategy(input, strategy)
    if strategy == "bit_flip" then
        return self:bit_flip_mutation(input)
    elseif strategy == "byte_flip" then
        return self:byte_flip_mutation(input)
    elseif strategy == "arithmetic" then
        return self:arithmetic_mutation(input)
    elseif strategy == "block_insert" then
        return self:block_insert_mutation(input)
    elseif strategy == "block_delete" then
        return self:block_delete_mutation(input)
    elseif strategy == "dictionary_based" then
        return self:dictionary_mutation(input)
    else
        return self:random_mutation(input)
    end
end

function feedback_driven.FeedbackMutator:bit_flip_mutation(input)
    if #input == 0 then return input end
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    local flipped = bit.bxor(byte, 1)  -- Flip least significant bit
    return input:sub(1, pos-1) .. string.char(flipped) .. input:sub(pos+1)
end

function feedback_driven.FeedbackMutator:byte_flip_mutation(input)
    if #input == 0 then return input end
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    local flipped = bit.bxor(byte, 0xFF)  -- Flip all bits
    return input:sub(1, pos-1) .. string.char(flipped) .. input:sub(pos+1)
end

function feedback_driven.FeedbackMutator:arithmetic_mutation(input)
    if #input == 0 then return input end
    local pos = math.random(#input)
    local byte = string.byte(input, pos)
    local delta = math.random(-32, 32)
    local mutated = (byte + delta) % 256
    return input:sub(1, pos-1) .. string.char(mutated) .. input:sub(pos+1)
end

function feedback_driven.FeedbackMutator:block_insert_mutation(input)
    local insert_pos = math.random(#input + 1)
    local block_size = math.random(1, 8)
    local block = ""
    for i = 1, block_size do
        block = block .. string.char(math.random(0, 255))
    end
    return input:sub(1, insert_pos-1) .. block .. input:sub(insert_pos)
end

function feedback_driven.FeedbackMutator:block_delete_mutation(input)
    if #input < 2 then return input end
    local start_pos = math.random(#input - 1)
    local delete_size = math.min(math.random(1, 8), #input - start_pos + 1)
    return input:sub(1, start_pos-1) .. input:sub(start_pos + delete_size)
end

function feedback_driven.FeedbackMutator:dictionary_mutation(input)
    -- Simple dictionary-based mutation (would use actual dictionary in real impl)
    local tokens = {"AAAA", "BBBB", "CCCC", "\x00\x00\x00\x00", "test"}
    local token = tokens[math.random(#tokens)]
    local pos = math.random(#input + 1)
    return input:sub(1, pos-1) .. token .. input:sub(pos)
end

function feedback_driven.FeedbackMutator:random_mutation(input)
    -- Fallback random mutation
    return self:bit_flip_mutation(input)
end

function feedback_driven.FeedbackMutator:get_feedback_stats()
    return {
        total_feedback_entries = #self.feedback_history,
        strategy_effectiveness = self.effectiveness_scores,
        strategy_weights = self.strategy_weights,
        best_strategy = self:get_best_strategy()
    }
end

function feedback_driven.FeedbackMutator:get_best_strategy()
    local best_score = -math.huge
    local best_strategy = nil

    for strategy, scores in pairs(self.effectiveness_scores) do
        if #scores > 0 then
            local avg_score = 0
            for _, score in ipairs(scores) do
                avg_score = avg_score + score
            end
            avg_score = avg_score / #scores

            if avg_score > best_score then
                best_score = avg_score
                best_strategy = strategy
            end
        end
    end

    return best_strategy
end

return feedback_driven