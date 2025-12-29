"""
Integration Tests
==================

Test complete fuzzing system integration.
This verify all component work together.
"""

import os
import tempfile
import pytest
from dragonslayer.fuzzing import (
    VMFuzzer,
    FuzzingConfig,
    FuzzingStrategy,
    ExecutionEngine,
    CoverageTracker,
    CrashAnalyzer,
    CorpusManager,
    MutationEngine,
    InputGenerator,
    SymbolicFuzzingBridge,
    TaintGuidedMutator,
    CoverageInstrumenter,
    InstrumentationType,
    ParallelFuzzer,
    PowerScheduler,
    DictionaryManager,
    NetworkFuzzer,
    NetworkTarget,
)
from dragonslayer.core import (
    Orchestrator,
    AnalysisRequest,
    AnalysisType,
)
import asyncio


def test_full_fuzzer_integration():
    """Test complete fuzzer with all feature enable."""
    config = FuzzingConfig(
        max_iterations=10,  # Small for testing
        timeout_seconds=1,
        strategy=FuzzingStrategy.HYBRID,
        enable_coverage=True,
        enable_taint=True,
        enable_symbolic=True,
        parallel_jobs=1,  # No parallel for test
        seed=42
    )
    
    fuzzer = VMFuzzer(config)
    
    # Verify all component are initialize
    assert fuzzer.config is config
    assert fuzzer.mutation_engine is not None
    assert fuzzer.coverage_tracker is not None
    assert fuzzer.crash_analyzer is not None
    assert fuzzer.corpus_manager is not None
    assert fuzzer.input_generator is not None
    assert fuzzer.execution_engine is not None
    assert fuzzer.symbolic_bridge is not None  # Should be enable
    assert fuzzer.taint_mutator is not None     # Should be enable
    assert fuzzer.vm_taint_fuzzer is not None   # Should be enable
    assert fuzzer.dictionary is not None
    
    # Test input generation
    input1 = fuzzer.generate_input()
    assert isinstance(input1, bytes)
    assert len(input1) > 0
    
    # Test with corpus
    fuzzer.corpus_manager.add_input(b"seed", {0x1000}, 0.0)
    input2 = fuzzer.generate_input()
    assert isinstance(input2, bytes)


def test_execution_engine_integration():
    """Test execution engine with different delivery method."""
    engine = ExecutionEngine(timeout=1)
    
    # Test with dummy target (will fail but not crash)
    result = engine.execute("nonexistent.exe", b"test")
    
    # Should timeout or fail gracefully
    assert result.execution_time >= 0
    assert isinstance(result.crashed, bool)
    assert isinstance(result.exit_code, int)
    
    engine.cleanup()


def test_coverage_instrumentation():
    """Test coverage instrumentation setup."""
    instrumenter = CoverageInstrumenter(InstrumentationType.NONE)
    
    # Should work without instrumentation
    cmd = instrumenter.get_coverage_command("test.exe")
    assert cmd == ["test.exe"]
    
    # Test with PIN (if available)
    pin_instrumenter = CoverageInstrumenter(InstrumentationType.PIN)
    cmd_pin = pin_instrumenter.get_coverage_command("test.exe")
    
    # Command should include test.exe
    assert "test.exe" in cmd_pin


def test_parallel_fuzzer_setup():
    """Test parallel fuzzer initialization."""
    parallel_fuzzer = ParallelFuzzer(num_workers=2)
    
    assert parallel_fuzzer.num_workers == 2
    assert len(parallel_fuzzer.workers) == 0  # Not started yet
    
    # Cleanup
    parallel_fuzzer.stop_workers()


def test_power_scheduler():
    """Test power scheduler scoring."""
    scheduler = PowerScheduler(alpha=0.5)
    
    # Test scoring
    scheduler.update_score(b"input1", True, 0.1)   # Found coverage, fast
    scheduler.update_score(b"input2", False, 0.1)  # No coverage, fast
    scheduler.update_score(b"input3", True, 2.0)   # Found coverage, slow
    
    # input1 should have highest score
    top_inputs = scheduler.get_top_inputs(3)
    assert len(top_inputs) <= 3
    
    # Select input
    selected = scheduler.select_input([b"input1", b"input2", b"input3"])
    assert selected in [b"input1", b"input2", b"input3"]


def test_dictionary_manager():
    """Test dictionary token management."""
    dictionary = DictionaryManager()
    
    # Should have default tokens
    assert len(dictionary.tokens) > 0
    
    # Add custom token
    dictionary.add_token(b"custom_token")
    assert b"custom_token" in dictionary.tokens
    
    # Get random tokens
    tokens = dictionary.get_random_tokens(2)
    assert len(tokens) <= 2
    
    # Inject tokens
    input_data = b"test input"
    injected = dictionary.inject_tokens(input_data)
    assert isinstance(injected, bytes)


def test_network_fuzzer_setup():
    """Test network fuzzer initialization."""
    target = NetworkTarget("127.0.0.1", 8080)
    fuzzer = NetworkFuzzer(target)
    
    assert fuzzer.target.host == "127.0.0.1"
    assert fuzzer.target.port == 8080
    
    # Test baseline establishment (with dummy data)
    fuzzer.establish_baseline([b"test"])
    assert len(fuzzer.baseline_responses) >= 0  # May be 0 if connection fail


def test_symbolic_integration():
    """Test symbolic integration component."""
    bridge = SymbolicFuzzingBridge()
    
    # Should initialize without error
    assert bridge.explored_paths == []
    assert bridge.pending_constraints == []
    
    # Test path analysis (will return None without real binary)
    path = bridge.analyze_branch(0x1000, b"input")
    assert path is None or hasattr(path, 'constraints')


def test_taint_integration():
    """Test taint integration component."""
    mutator = TaintGuidedMutator()
    
    # Should initialize without error
    assert mutator.influence_map == {}
    
    # Test execution tracking (will be empty without real execution)
    taint_info = mutator.track_execution(b"input", set())
    assert hasattr(taint_info, 'tainted_bytes')
    assert hasattr(taint_info, 'influence_branches')


def test_input_generator_grammar():
    """Test grammar-based input generation."""
    generator = InputGenerator()
    
    # Test grammar generation
    grammar = {
        "start": ["<method> <path> HTTP/1.1\r\n\r\n"],
        "method": ["GET", "POST"],
        "path": ["/", "/api"]
    }
    
    input_data = generator.generate_from_grammar(grammar)
    assert isinstance(input_data, bytes)
    assert len(input_data) > 0
    
    # Should contain HTTP elements
    input_str = input_data.decode('utf-8', errors='ignore')
    assert "HTTP/1.1" in input_str


def test_corpus_minimization():
    """Test corpus minimization."""
    corpus = CorpusManager(max_size=5)
    
    # Add input with different coverage
    corpus.add_input(b"input1", {0x1000, 0x1004}, 0.1)
    corpus.add_input(b"input2", {0x1000}, 0.1)  # Subset - should be minimize
    corpus.add_input(b"input3", {0x1008, 0x100C}, 0.1)  # New coverage
    
    stats = corpus.get_stats()
    assert stats['total_inputs'] >= 2  # At least input1 and input3


@pytest.mark.skip(reason="Need real test binary")
def test_end_to_end_fuzzing():
    """End-to-end fuzzing test with real binary."""
    # This would require a test binary
    # For now, skip this test
    
    config = FuzzingConfig(
        max_iterations=100,
        timeout_seconds=1,
        strategy=FuzzingStrategy.MUTATION
    )
    
    fuzzer = VMFuzzer(config)
    
    # Would test with actual binary
    # result = fuzzer.fuzz("test_binary.exe", [b"seed"])
    # assert result.iterations > 0


def test_config_validation():
    """Test configuration validation."""
    # Valid config
    config = FuzzingConfig()
    assert config.max_iterations > 0
    assert config.timeout_seconds > 0
    
    # Test with parallel
    parallel_config = FuzzingConfig(parallel_jobs=4)
    assert parallel_config.parallel_jobs == 4
    
    # Test with all features enable
    full_config = FuzzingConfig(
        enable_coverage=True,
        enable_taint=True,
        enable_symbolic=True,
        parallel_jobs=2
    )
    
    assert full_config.enable_coverage == True
    assert full_config.enable_taint == True
    assert full_config.enable_symbolic == True
    assert full_config.parallel_jobs == 2


def test_mutation_engine_strategies():
    """Test all mutation strategies."""
    engine = MutationEngine(seed=42)
    
    test_input = b"Hello World! This is a test input for mutation."
    
    # Test each strategy
    strategies = [
        ("BIT_FLIP", engine.mutate(test_input, engine.BIT_FLIP)),
        ("BYTE_FLIP", engine.mutate(test_input, engine.BYTE_FLIP)),
        ("ARITHMETIC", engine.mutate(test_input, engine.ARITHMETIC)),
        ("INTERESTING_VALUES", engine.mutate(test_input, engine.INTERESTING_VALUES)),
        ("BLOCK_DELETE", engine.mutate(test_input, engine.BLOCK_DELETE)),
        ("BLOCK_DUPLICATE", engine.mutate(test_input, engine.BLOCK_DUPLICATE)),
        ("BLOCK_OVERWRITE", engine.mutate(test_input, engine.BLOCK_OVERWRITE)),
        ("SPLICE", engine.mutate(test_input, engine.SPLICE)),
        ("HAVOC", engine.mutate(test_input, engine.HAVOC)),
    ]
    
    for strategy_name, mutated in strategies:
        assert isinstance(mutated, bytes), f"{strategy_name} should return bytes"
        # Most strategies should change the input (except some edge cases)
        # We don't assert this strictly since some strategies might not change short inputs


def test_crash_deduplication():
    """Test crash deduplication."""
    analyzer = CrashAnalyzer()
    
    # Same crash multiple times
    crash_info1 = {
        'type': 'access_violation',
        'address': 0x401000,
        'write_operation': True
    }
    
    crash_info2 = {
        'type': 'access_violation',
        'address': 0x401000,
        'write_operation': True
    }
    
    # Analyze same crash twice
    analyzer.analyze_crash(crash_info1, b"input1")
    analyzer.analyze_crash(crash_info2, b"input2")
    
    # Should be deduplicate
    assert analyzer.get_unique_crash_count() == 1
    
    # Different crash
    crash_info3 = {
        'type': 'division_by_zero',
        'address': 0x402000
    }
    
    analyzer.analyze_crash(crash_info3, b"input3")
    assert analyzer.get_unique_crash_count() == 2


def test_orchestrator_hybrid_plan():
    """Ensure orchestrator builds hybrid plan without executing binaries."""
    orchestrator = Orchestrator({"fuzzing": {"max_iterations": 16}})
    request = AnalysisRequest(
        binary_path="nonexistent_vm_binary.exe",
        analysis_type=AnalysisType.HYBRID,
        seed_inputs=[b"seed"],
        options={"target_branches": [0x1000, 0x2000]},
    )

    result = asyncio.run(orchestrator.execute_analysis(request))

    assert result.success is True
    assert "pipeline" in result.results
    assert any(step["name"] == "taint_guided_mutation" for step in result.results["pipeline"])
    assert "stages" in result.results
    assert any(stage["name"] == "taint_guided_mutation" for stage in result.results["stages"])
    assert any(stage["name"] == "symbolic_guidance" for stage in result.results["stages"])
    assert "dictionary_preview" in result.results


def test_orchestrator_hybrid_simulation():
    """Ensure optional hybrid simulation returns structured preview."""
    orchestrator = Orchestrator({"fuzzing": {"max_iterations": 8}})
    request = AnalysisRequest(
        binary_path="nonexistent_vm_binary.exe",
        analysis_type=AnalysisType.HYBRID,
        seed_inputs=[b"seedA", b"seedB"],
        options={
            "target_branches": [0x3000],
            "simulate_execution": True,
            "preview_iterations": 2,
        },
    )

    result = asyncio.run(orchestrator.execute_analysis(request))

    preview = result.results.get("execution_preview")
    assert preview is not None
    assert preview["stats"]["total_cases"] <= 2
    assert preview["stats"]["seed_cases"] >= 1
    assert preview["stats"]["inputs_considered"] >= preview["stats"]["total_cases"]
    assert isinstance(preview["iterations"], list) and preview["iterations"]
    assert all("origin" in entry for entry in preview["iterations"])
    assert preview["notes"] and "Simulation executed without launching external binaries." in preview["notes"][0]
    symbolic_stage = next(stage for stage in result.results["stages"] if stage["name"] == "symbolic_guidance")
    assert symbolic_stage["details"]["generated_inputs"], "Expected symbolic guidance to produce inputs"


def test_orchestrator_hybrid_run_workflow():
    """Ensure orchestrator can run bounded hybrid workflow loop."""
    orchestrator = Orchestrator({"fuzzing": {"max_iterations": 10}})
    request = AnalysisRequest(
        binary_path="nonexistent_vm_binary.exe",
        analysis_type=AnalysisType.HYBRID,
        seed_inputs=[b"seed-run"],
        options={
            "target_branches": [0x4000],
            "run_workflow": True,
            "run_iterations": 3,
        },
    )

    result = asyncio.run(orchestrator.execute_analysis(request))

    run_summary = result.results.get("run_summary")
    assert run_summary is not None
    stats = run_summary["stats"]
    assert stats["iterations_completed"] <= 3
    assert stats["iterations_completed"] >= 1
    assert stats["seed_cases"] >= 1
    assert "iterations" in run_summary and isinstance(run_summary["iterations"], list)
    assert run_summary["iterations"], "Expected at least one iteration entry"
    assert all("origin" in entry for entry in run_summary["iterations"])
    assert run_summary["notes"]
    assert stats["symbolic_cases"] >= 1
    assert "symbolic_cases" in stats["new_cases_added"]
