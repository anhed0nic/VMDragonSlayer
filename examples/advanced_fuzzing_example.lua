local orchestrator = require("dragonslayer.core.orchestrator")
local vm_fuzzer = require("dragonslayer.fuzzing.vm_fuzzer")
local coverage = require("dragonslayer.fuzzing.coverage")
local crash_triage = require("dragonslayer.fuzzing.crash_triage")
local corpus_manager = require("dragonslayer.fuzzing.corpus_manager")
local mutators = require("dragonslayer.fuzzing.mutators")
local pattern_analysis = require("dragonslayer.analysis.pattern_analysis")
local anti_evasion = require("dragonslayer.analysis.anti_evasion")

-- Advanced fuzzing example with full pipeline
local function main()
    print("VMDragonSlayer Advanced Fuzzing Example")
    print("=======================================")

    -- Initialize components
    local o = orchestrator.Orchestrator:new()
    local fuzzer = vm_fuzzer.VMFuzzer:new({max_iterations = 100})
    local cov_tracker = coverage.CoverageTracker:new()
    local crash_analyzer = crash_triage.CrashAnalyzer:new()
    local corpus_mgr = corpus_manager.CorpusManager:new()
    local pattern_analyzer = pattern_analysis.PatternAnalyzer:new()
    local anti_evasion_engine = anti_evasion.AntiEvasionEngine:new()

    -- Setup pattern analysis
    pattern_analyzer:add_pattern("vm_handler", "VMProtect", "protection")
    pattern_analyzer:add_pattern("syscall", "\\x0f\\x05", "system_call")
    pattern_analyzer:add_pattern("jmp_indirect", "\\xff\\x25", "control_flow")

    -- Setup anti-evasion
    anti_evasion_engine:default_detectors()

    -- Initial corpus
    local initial_inputs = {
        "\x90\x90\x90",  -- NOP sled
        "test_input_123",
        string.rep("A", 100),  -- Long string
        "\x00\x01\x02\x03",  -- Binary data
    }

    for _, input in ipairs(initial_inputs) do
        corpus_mgr:add_entry(input, {source = "initial"})
    end

    -- Main fuzzing loop
    local total_iterations = 500
    for iteration = 1, total_iterations do
        -- Select input from corpus
        local corpus_entries = {}
        for id, entry in pairs(corpus_mgr.entries) do
            table.insert(corpus_entries, entry.input)
        end
        local input = fuzzer:select_input(corpus_entries)

        -- Apply multiple mutations
        local mutated = input
        for i = 1, math.random(1, 3) do
            mutated = mutators.mutate(mutated, mutators.MutationType.HAVOC)
        end

        -- Check for anti-evasion
        local evasion_results = anti_evasion_engine:detect_evasion(mutated, {execution_time = math.random()})
        if #evasion_results > 0 then
            print("Evasion detected in iteration " .. iteration .. ": " .. evasion_results[1].technique)
        end

        -- Execute
        local result = fuzzer:execute(mutated)

        -- Analyze patterns
        local patterns = pattern_analyzer:analyze(mutated)
        if #patterns > 0 then
            result.patterns_found = patterns
        end

        -- Update coverage
        local new_cov = cov_tracker:record_execution({edges = {}, blocks = {}})

        -- Handle results
        if result.crash then
            local crash_info = {type = "segfault", location = math.random(0x1000, 0xFFFF)}
            crash_analyzer:analyze_crash(mutated, crash_info)
            corpus_mgr:add_entry(mutated, {source = "crash", exploitability = "high"})
        elseif new_cov then
            corpus_mgr:add_entry(mutated, {source = "coverage"})
        end

        -- Periodic reporting
        if iteration % 50 == 0 then
            local stats = fuzzer.stats
            print(string.format("Iteration %d/%d: %d executions, %d crashes, corpus size: %d",
                iteration, total_iterations, stats.executions, stats.crashes, corpus_mgr:get_stats().total_entries))
        end
    end

    -- Final analysis
    print("\nFinal Results:")
    print("==============")

    local cov_stats = cov_tracker:get_stats()
    print("Coverage: " .. cov_stats.edges_covered .. " edges covered")

    local crash_stats = crash_analyzer:get_summary()
    print("Crashes: " .. crash_stats.total_crashes .. " total, " .. crash_stats.unique_crashes .. " unique")

    local corpus_stats = corpus_mgr:get_stats()
    print("Corpus: " .. corpus_stats.total_entries .. " entries, " .. corpus_stats.total_size .. " bytes")

    local pattern_stats = pattern_analyzer:get_statistics()
    print("Patterns: " .. pattern_stats.total_matches .. " matches across " .. pattern_stats.total_patterns .. " patterns")

    local evasion_stats = anti_evasion_engine:get_detection_stats()
    print("Anti-evasion: " .. evasion_stats.total_detections .. " detections")

    -- Run full orchestrator analysis
    print("\nRunning full orchestrator analysis...")
    local analysis_result = o:analyze_binary("dummy_target.exe", "hybrid")
    print("Orchestrator result: " .. (analysis_result.success and "SUCCESS" or "FAILED"))

    print("\nAdvanced fuzzing example completed!")
end

main()