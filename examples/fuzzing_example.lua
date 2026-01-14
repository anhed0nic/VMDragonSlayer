local base_fuzzer = require("dragonslayer.fuzzing.base_fuzzer")
local mutators = require("dragonslayer.fuzzing.mutators")
local coverage = require("dragonslayer.fuzzing.coverage")
local crash_triage = require("dragonslayer.fuzzing.crash_triage")
local corpus_manager = require("dragonslayer.fuzzing.corpus_manager")

-- Simple fuzzing example
local function main()
    print("VMDragonSlayer Fuzzing Example")

    -- Initialize components
    local fuzzer = base_fuzzer.BaseFuzzer:new({max_iterations = 100})
    local cov_tracker = coverage.CoverageTracker:new()
    local crash_analyzer = crash_triage.CrashAnalyzer:new()
    local corpus_mgr = corpus_manager.CorpusManager:new()

    -- Initial corpus
    local initial_inputs = {"hello", "world", "test"}
    for _, input in ipairs(initial_inputs) do
        corpus_mgr:add_entry(input, {source = "initial"})
    end

    -- Fuzzing loop
    for i = 1, 100 do
        local input = fuzzer:select_input(initial_inputs)
        local mutated = mutators.mutate(input, mutators.MutationType.HAVOC)
        local result = fuzzer:execute(mutated)

        -- Update coverage
        local new_cov = cov_tracker:record_execution({edges = {}, blocks = {}})

        -- Check for crashes
        if result.crash then
            crash_analyzer:analyze_crash(mutated, {type = "segfault", location = 0xdeadbeef})
            corpus_mgr:add_entry(mutated, {source = "crash", exploitability = "high"})
        elseif new_cov then
            corpus_mgr:add_entry(mutated, {source = "coverage"})
        end

        if i % 10 == 0 then
            print("Iteration " .. i .. ": " .. fuzzer.stats.executions .. " executions, " .. fuzzer.stats.crashes .. " crashes")
        end
    end

    -- Final stats
    print("Final Stats:")
    print("Coverage: " .. cov_tracker:get_stats().edges_covered .. " edges")
    print("Crashes: " .. crash_analyzer:get_summary().total_crashes .. " total")
    print("Corpus: " .. corpus_mgr:get_stats().total_entries .. " entries")
end

main()