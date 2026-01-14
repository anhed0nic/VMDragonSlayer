local evolutionary_fuzzing = {}

evolutionary_fuzzing.EvolutionaryFuzzer = {}

function evolutionary_fuzzing.EvolutionaryFuzzer:new(population_size)
    local self = setmetatable({}, { __index = evolutionary_fuzzing.EvolutionaryFuzzer })
    self.population_size = population_size or 100
    self.population = {}
    self.generation = 0
    self.fitness_scores = {}
    self.elite_size = math.floor(self.population_size * 0.1)  -- 10% elite
    return self
end

function evolutionary_fuzzing.EvolutionaryFuzzer:initialize_population(seed_inputs)
    self.population = {}

    -- Start with seed inputs
    for _, seed in ipairs(seed_inputs or {}) do
        table.insert(self.population, {
            data = seed,
            fitness = 0,
            age = 0,
            coverage = {},
            crashes_found = 0
        })
    end

    -- Fill remaining population with random inputs
    while #self.population < self.population_size do
        local random_input = self:generate_random_input()
        table.insert(self.population, {
            data = random_input,
            fitness = 0,
            age = 0,
            coverage = {},
            crashes_found = 0
        })
    end
end

function evolutionary_fuzzing.EvolutionaryFuzzer:generate_random_input()
    local length = math.random(1, 1024)  -- Random length up to 1KB
    local input = ""
    for i = 1, length do
        input = input .. string.char(math.random(0, 255))
    end
    return input
end

function evolutionary_fuzzing.EvolutionaryFuzzer:evaluate_fitness(individual, execution_result)
    local fitness = 0

    -- Fitness based on code coverage
    if execution_result.coverage then
        fitness = fitness + #execution_result.coverage * 10
    end

    -- Fitness based on crashes found
    if execution_result.crash_found then
        fitness = fitness + 1000
    end

    -- Fitness based on execution speed (shorter is better)
    if execution_result.execution_time then
        fitness = fitness + math.max(0, 100 - execution_result.execution_time)
    end

    -- Fitness based on input diversity (shorter inputs get bonus for being more focused)
    fitness = fitness + math.max(0, 100 - #individual.data / 10)

    -- Age penalty (prefer younger individuals)
    fitness = fitness - individual.age * 0.1

    return fitness
end

function evolutionary_fuzzing.EvolutionaryFuzzer:update_population_fitness(execution_results)
    for i, individual in ipairs(self.population) do
        local result = execution_results[i] or {}
        individual.fitness = self:evaluate_fitness(individual, result)
        individual.age = individual.age + 1

        -- Update coverage and crash tracking
        if result.coverage then
            individual.coverage = result.coverage
        end
        if result.crash_found then
            individual.crashes_found = individual.crashes_found + 1
        end
    end

    -- Sort population by fitness (descending)
    table.sort(self.population, function(a, b) return a.fitness > b.fitness end)
end

function evolutionary_fuzzing.EvolutionaryFuzzer:select_parents()
    local parents = {}

    -- Elite selection (top individuals)
    for i = 1, self.elite_size do
        table.insert(parents, self.population[i])
    end

    -- Tournament selection for remaining parents
    local remaining = self.population_size - self.elite_size
    for i = 1, remaining do
        local tournament_size = 5
        local best = nil
        local best_fitness = -math.huge

        for j = 1, tournament_size do
            local candidate_idx = math.random(#self.population)
            local candidate = self.population[candidate_idx]
            if candidate.fitness > best_fitness then
                best = candidate
                best_fitness = candidate.fitness
            end
        end

        table.insert(parents, best)
    end

    return parents
end

function evolutionary_fuzzing.EvolutionaryFuzzer:crossover(parent1, parent2)
    local child1_data, child2_data

    -- Single-point crossover
    local min_len = math.min(#parent1.data, #parent2.data)
    if min_len > 0 then
        local crossover_point = math.random(min_len)
        child1_data = parent1.data:sub(1, crossover_point) .. parent2.data:sub(crossover_point + 1)
        child2_data = parent2.data:sub(1, crossover_point) .. parent1.data:sub(crossover_point + 1)
    else
        child1_data = parent1.data
        child2_data = parent2.data
    end

    return child1_data, child2_data
end

function evolutionary_fuzzing.EvolutionaryFuzzer:mutate(individual, mutation_rate)
    mutation_rate = mutation_rate or 0.1

    if math.random() < mutation_rate then
        local mutated_data = individual.data

        -- Random mutation types
        local mutation_type = math.random(4)

        if mutation_type == 1 and #mutated_data > 0 then
            -- Bit flip
            local pos = math.random(#mutated_data)
            local byte = string.byte(mutated_data, pos)
            mutated_data = mutated_data:sub(1, pos-1) .. string.char(bit.bxor(byte, 1)) .. mutated_data:sub(pos+1)
        elseif mutation_type == 2 then
            -- Byte insertion
            local pos = math.random(#mutated_data + 1)
            local new_byte = string.char(math.random(0, 255))
            mutated_data = mutated_data:sub(1, pos-1) .. new_byte .. mutated_data:sub(pos)
        elseif mutation_type == 3 and #mutated_data > 1 then
            -- Byte deletion
            local pos = math.random(#mutated_data)
            mutated_data = mutated_data:sub(1, pos-1) .. mutated_data:sub(pos+1)
        elseif mutation_type == 4 then
            -- Arithmetic mutation
            if #mutated_data > 0 then
                local pos = math.random(#mutated_data)
                local byte = string.byte(mutated_data, pos)
                local delta = math.random(-10, 10)
                mutated_data = mutated_data:sub(1, pos-1) .. string.char((byte + delta) % 256) .. mutated_data:sub(pos+1)
            end
        end

        return mutated_data
    end

    return individual.data
end

function evolutionary_fuzzing.EvolutionaryFuzzer:create_next_generation()
    local parents = self:select_parents()
    local new_population = {}

    -- Keep elite individuals
    for i = 1, self.elite_size do
        table.insert(new_population, {
            data = self.population[i].data,
            fitness = 0,
            age = 0,
            coverage = {},
            crashes_found = 0
        })
    end

    -- Create offspring through crossover and mutation
    while #new_population < self.population_size do
        local parent1 = parents[math.random(#parents)]
        local parent2 = parents[math.random(#parents)]

        local child1_data, child2_data = self:crossover(parent1, parent2)

        -- Mutate children
        child1_data = self:mutate({data = child1_data})
        child2_data = self:mutate({data = child2_data})

        table.insert(new_population, {
            data = child1_data,
            fitness = 0,
            age = 0,
            coverage = {},
            crashes_found = 0
        })

        if #new_population < self.population_size then
            table.insert(new_population, {
                data = child2_data,
                fitness = 0,
                age = 0,
                coverage = {},
                crashes_found = 0
            })
        end
    end

    self.population = new_population
    self.generation = self.generation + 1
end

function evolutionary_fuzzing.EvolutionaryFuzzer:get_best_individual()
    if #self.population == 0 then return nil end
    return self.population[1]
end

function evolutionary_fuzzing.EvolutionaryFuzzer:get_population_stats()
    if #self.population == 0 then return {} end

    local total_fitness = 0
    local max_fitness = -math.huge
    local min_fitness = math.huge
    local total_coverage = 0
    local total_crashes = 0

    for _, individual in ipairs(self.population) do
        total_fitness = total_fitness + individual.fitness
        max_fitness = math.max(max_fitness, individual.fitness)
        min_fitness = math.min(min_fitness, individual.fitness)
        total_coverage = total_coverage + (individual.coverage and #individual.coverage or 0)
        total_crashes = total_crashes + individual.crashes_found
    end

    return {
        generation = self.generation,
        population_size = #self.population,
        avg_fitness = total_fitness / #self.population,
        max_fitness = max_fitness,
        min_fitness = min_fitness,
        avg_coverage = total_coverage / #self.population,
        total_crashes = total_crashes,
        best_individual = self:get_best_individual()
    }
end

return evolutionary_fuzzing