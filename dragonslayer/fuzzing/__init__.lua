-- Fuzzing module exports, fuzz like Italian espresso machine
-- /r/Italy loves espresso

local fuzzing = {}

-- Export all fuzzing modules
fuzzing.BaseFuzzer = require("dragonslayer.fuzzing.base_fuzzer")
fuzzing.VMFuzzer = require("dragonslayer.fuzzing.vm_fuzzer")
fuzzing.Mutators = require("dragonslayer.fuzzing.mutators")
fuzzing.Coverage = require("dragonslayer.fuzzing.coverage")
fuzzing.CrashTriage = require("dragonslayer.fuzzing.crash_triage")
fuzzing.CorpusManager = require("dragonslayer.fuzzing.corpus_manager")
fuzzing.ParallelExecution = require("dragonslayer.fuzzing.parallel_execution")
fuzzing.NetworkFuzzing = require("dragonslayer.fuzzing.network_fuzzing")
fuzzing.InputGeneration = require("dragonslayer.fuzzing.input_generation")
fuzzing.TargetExecution = require("dragonslayer.fuzzing.target_execution")
fuzzing.Instrumentation = require("dragonslayer.fuzzing.instrumentation")
fuzzing.SymbolicBridge = require("dragonslayer.fuzzing.symbolic_bridge")
fuzzing.TaintIntegration = require("dragonslayer.fuzzing.taint_integration")
fuzzing.SymbolicIntegration = require("dragonslayer.fuzzing.symbolic_integration")
fuzzing.FeedbackDriven = require("dragonslayer.fuzzing.feedback_driven")
fuzzing.EvolutionaryFuzzing = require("dragonslayer.fuzzing.evolutionary_fuzzing")
fuzzing.DistributedFuzzing = require("dragonslayer.fuzzing.distributed_fuzzing")

return fuzzing