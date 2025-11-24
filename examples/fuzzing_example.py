"""
Example Fuzzing Script
=======================

Demonstrate how to use VMDragonSlayer fuzzer.
This show complete workflow from setup to result analysis.
"""

import os
import sys
from pathlib import Path

# Add dragonslayer to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dragonslayer.fuzzing import (
    VMFuzzer,
    FuzzingConfig,
    FuzzingStrategy,
)


def main():
    """Main fuzzing example."""
    
    print("[*] VMDragonSlayer EBP Fuzzer Example")
    print("[*] This demonstrate VM-aware fuzzing capability")
    print()
    
    # Configuration
    target_path = "target.exe"  # Replace with real target
    
    if not os.path.exists(target_path):
        print(f"[!] Target not found: {target_path}")
        print("[!] Please provide valid target binary")
        return
    
    # Create fuzzing configuration
    config = FuzzingConfig(
        max_iterations=10000,
        timeout_seconds=5,
        strategy=FuzzingStrategy.HYBRID,
        enable_coverage=True,
        enable_taint=True,
        crash_dir="output/crashes",
        corpus_dir="output/corpus",
        seed=12345
    )
    
    print(f"[*] Configuration:")
    print(f"    Iterations: {config.max_iterations}")
    print(f"    Timeout: {config.timeout_seconds}s")
    print(f"    Strategy: {config.strategy.value}")
    print(f"    Coverage: {config.enable_coverage}")
    print(f"    Taint: {config.enable_taint}")
    print()
    
    # Create fuzzer
    fuzzer = VMFuzzer(config)
    
    # Prepare initial corpus (seed input)
    initial_corpus = [
        b"GET / HTTP/1.1\r\n\r\n",
        b"POST /api HTTP/1.1\r\n\r\n",
        b"\x00\x01\x02\x03\x04\x05",
        b"A" * 100,
    ]
    
    print(f"[*] Initial corpus: {len(initial_corpus)} seed")
    print()
    
    # Run fuzzing
    print("[*] Starting fuzzing session...")
    print("[*] Press Ctrl+C to stop early")
    print()
    
    try:
        result = fuzzer.fuzz(
            target_path=target_path,
            initial_corpus=initial_corpus,
            delivery_method='stdin'
        )
        
        # Display result
        print()
        print("[+] Fuzzing complete!")
        print()
        print("=" * 60)
        print("RESULTS")
        print("=" * 60)
        print(f"Total iterations:     {result.iterations}")
        print(f"Total executions:     {result.total_executions}")
        print(f"Crashes found:        {result.crashes_found}")
        print(f"Unique crashes:       {result.unique_crashes}")
        print(f"Timeouts:             {result.timeouts}")
        print(f"Coverage:             {result.coverage_percentage:.2f}%")
        print(f"Execution time:       {result.execution_time:.2f}s")
        print(f"Exec/sec:             {result.total_executions / result.execution_time:.2f}")
        print("=" * 60)
        print()
        
        # Get statistics
        stats = fuzzer.get_statistics()
        
        if stats['vm_detected']:
            print("[+] VM Protection Detected!")
            print(f"    VM Handlers: {stats['vm_handlers']}")
            print()
        
        print(f"Corpus size:          {stats['corpus_size']}")
        print()
        
        # Display crash detail if any
        if result.crashes_found > 0:
            print("[+] Crash Details:")
            print()
            
            for i, crash in enumerate(result.crash_details[:5], 1):
                print(f"  Crash #{i}:")
                for key, value in crash.items():
                    print(f"    {key}: {value}")
                print()
            
            if result.crashes_found > 5:
                print(f"  ... and {result.crashes_found - 5} more crash")
                print()
            
            print(f"[+] Crash input saved to: {config.crash_dir}")
            print()
        
        print(f"[+] Corpus saved to: {config.corpus_dir}")
        print()
        print("[*] Done!")
        
    except KeyboardInterrupt:
        print()
        print("[!] Fuzzing interrupted by user")
        print()
        
        # Get partial result
        stats = fuzzer.get_statistics()
        print(f"Partial results:")
        print(f"  Iterations: {stats['iterations']}")
        print(f"  Crashes: {stats['crashes']}")
        print(f"  Unique crashes: {stats['unique_crashes']}")


if __name__ == "__main__":
    main()
