"""
Taint Tracking Integration
===========================

Integrate taint tracking to guide fuzzing.
Track how input byte influence execution and crash.
"""

from typing import Dict, List, Set, Optional, Any
from dataclasses import dataclass

try:
    # Real tracker live in analysis module; might be missing when fraud build shipped.
    from ..analysis.taint_tracking import TaintTracker  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    TaintTracker = None  # type: ignore


@dataclass
class TaintInfo:
    """Information about taint propagation."""
    
    tainted_bytes: Set[int]  # Which input byte are tainted
    tainted_addresses: Set[int]  # Which memory address are tainted
    influence_branches: Set[int]  # Branch influenced by taint
    influence_operations: List[str]  # Operation on tainted data
    

class TaintGuidedMutator:
    """
    Mutate input base on taint information.
    
    Focus mutation on byte that actually influence execution.
    This more efficient than blind mutation.
    """
    
    def __init__(self):
        try:
            self.taint_tracker = TaintTracker() if TaintTracker else None
        except Exception:
            # Fraud build shipped without proper tracker, so we fall back gracefully.
            self.taint_tracker = None
        self.influence_map: Dict[int, Set[int]] = {}  # byte offset -> influenced block
        self.last_taint_info: Optional[TaintInfo] = None
        self.last_crash_analysis: Optional[Dict[str, Any]] = None
        self._max_tracked_bytes = 256  # keep heuristic small for offline analysis
        
    def track_execution(self, input_data: bytes, coverage: Set[int]) -> TaintInfo:
        """
        Track how input byte influence execution.
        
        Real implementation use tracker.py from taint_tracking module.
        """
        tainted_bytes: Set[int] = set()
        if input_data:
            # Focus on first chunk of data to keep tracking bounded.
            limit = min(len(input_data), self._max_tracked_bytes)
            tainted_bytes = set(range(limit))
        
        branches = set(coverage or set())
        operations: List[str] = []
        if branches:
            # We hint at influence by noting branch ids; cheap stand-in for full taint log.
            for branch in sorted(list(branches))[:16]:
                operations.append(f"branch_hit_{branch:x}")
        
        taint_info = TaintInfo(
            tainted_bytes=tainted_bytes,
            tainted_addresses=set(),
            influence_branches=branches,
            influence_operations=operations
        )
        
        for offset in taint_info.tainted_bytes:
            self.influence_map.setdefault(offset, set()).update(branches)
        
        self.last_taint_info = taint_info
        return taint_info
        
    def identify_critical_bytes(self, input_data: bytes, target_block: int) -> Set[int]:
        """
        Identify which input byte influence reaching target block.
        
        Return set of byte offset that are critical.
        """
        critical = set()
        
        # Check influence map
        for offset, influenced_blocks in self.influence_map.items():
            if target_block in influenced_blocks:
                critical.add(offset)
                
        return critical
        
    def mutate_critical_bytes(self, input_data: bytes, critical_bytes: Set[int]) -> bytes:
        """
        Mutate only critical byte that influence execution.
        
        This more targeted than random mutation.
        """
        import random
        
        result = bytearray(input_data)
        
        for offset in critical_bytes:
            if offset < len(result):
                # Mutate this critical byte
                result[offset] = random.randint(0, 255)
                
        return bytes(result)
        
    def analyze_crash_taint(self, crash_info: Dict, input_data: bytes) -> Dict:
        """
        Analyze which input byte contribute to crash.
        
        This help understand exploitability and minimize crash input.
        """
        crash_context = dict(crash_info or {})
        crash_address_raw = (
            crash_context.get('address')
            or crash_context.get('crash_address')
            or crash_context.get('fault_address')
        )
        try:
            crash_address = int(crash_address_raw) if crash_address_raw is not None else 0
        except (TypeError, ValueError):
            crash_address = 0
        
        coverage_hint = crash_context.get('coverage')
        if coverage_hint is None and 'result' in crash_context:
            coverage_hint = crash_context['result'].get('coverage')
        if coverage_hint is None:
            coverage_hint = set()
        coverage_set: Set[int] = set(coverage_hint) if isinstance(coverage_hint, (list, set, tuple)) else set()
        
        taint_info = self.track_execution(input_data, coverage_set)
        
        critical_bytes: Set[int] = set()
        if 'tainted_offsets' in crash_context and crash_context['tainted_offsets']:
            try:
                critical_bytes.update(int(o) for o in crash_context['tainted_offsets'])
            except Exception:
                pass
        fault_offset = crash_context.get('faulting_offset')
        if fault_offset is not None:
            try:
                critical_bytes.add(int(fault_offset))
            except Exception:
                pass
        if crash_address and coverage_set:
            for block in coverage_set:
                critical_bytes.update(self.identify_critical_bytes(input_data, block))
        if not critical_bytes and taint_info.tainted_bytes:
            # Fall back to first handful of tainted bytes when we lack precise intel.
            critical_bytes.update(sorted(taint_info.tainted_bytes)[:8])
        
        taint_flow: List[Dict[str, Any]] = []
        for offset in sorted(list(critical_bytes))[:16]:
            taint_flow.append({
                'input_offset': offset,
                'influenced_branches': sorted(list(self.influence_map.get(offset, set()))),
                'operations': list(taint_info.influence_operations),
            })
        if not taint_flow and taint_info.influence_branches:
            taint_flow.append({
                'input_offset': None,
                'influenced_branches': sorted(list(taint_info.influence_branches)),
                'operations': list(taint_info.influence_operations),
            })
        
        crash_type = str(
            crash_context.get('type')
            or crash_context.get('crash_type')
            or ''
        ).lower()
        exploitable = bool(crash_context.get('write_operation'))
        if not exploitable:
            if any(keyword in crash_type for keyword in ('overflow', 'heap', 'use-after', 'stack')):
                exploitable = True
            elif 'access' in crash_type or 'segfault' in crash_type:
                exploitable = crash_address > 0x10000
            elif 'division' in crash_type or 'assert' in crash_type:
                exploitable = False
        if crash_context.get('exploitable') in (True, False):
            exploitable = bool(crash_context['exploitable'])
        
        confidence = 'low'
        if coverage_set and critical_bytes:
            confidence = 'medium'
        if exploitable:
            confidence = 'high' if critical_bytes else 'medium'
        
        analysis = {
            'crash_address': crash_address,
            'critical_bytes': sorted(int(b) for b in critical_bytes),
            'taint_flow': taint_flow,
            'exploitable': exploitable,
            'confidence': confidence,
        }
        
        self.last_crash_analysis = analysis
        return analysis
        
    def minimize_input(self, input_data: bytes, must_trigger_crash: bool = False) -> bytes:
        """
        Minimize input by removing non-critical byte.
        
        Use taint tracking to identify byte that don't matter.
        """
        # Track which byte are used
        taint_info = self.track_execution(input_data, set())
        
        # Remove byte that don't influence execution
        result = bytearray()
        for i, byte in enumerate(input_data):
            if i in taint_info.tainted_bytes:
                result.append(byte)
                
        if len(result) == 0:
            return input_data
            
        return bytes(result)


class VMTaintFuzzer:
    """
    VM-aware fuzzing with taint tracking.
    
    Combine VM detection with taint tracking for better fuzzing.
    Focus on VM handler input and data flow through virtualized code.
    """
    
    def __init__(self, taint_mutator: Optional[TaintGuidedMutator] = None):
        self.taint_mutator = taint_mutator or TaintGuidedMutator()
        self.vm_handlers: Dict[int, Set[int]] = {}  # handler addr -> critical byte
        
    def analyze_vm_handler(self, handler_address: int, input_data: bytes) -> Set[int]:
        """
        Analyze which input byte influence VM handler.
        
        This identify byte that control virtualized operation.
        """
        # Use taint tracking to see data flow into handler
        taint_info = self.taint_mutator.track_execution(input_data, {handler_address})
        
        # Find byte that reach handler
        critical_bytes = set()
        if handler_address in taint_info.influence_branches:
            critical_bytes = taint_info.tainted_bytes
            
        # Cache result
        self.vm_handlers[handler_address] = critical_bytes
        
        return critical_bytes
        
    def mutate_for_vm_handler(self, input_data: bytes, handler_address: int) -> bytes:
        """
        Mutate input to explore VM handler behavior.
        
        Focus mutation on byte that handler actually use.
        """
        # Get critical byte for this handler
        critical_bytes = self.vm_handlers.get(handler_address)
        
        if not critical_bytes:
            critical_bytes = self.analyze_vm_handler(handler_address, input_data)
            
        # Mutate only critical byte
        if critical_bytes:
            return self.taint_mutator.mutate_critical_bytes(input_data, critical_bytes)
            
        return input_data
        
    def generate_vm_aware_corpus(self, vm_handlers: List[int], 
                                  initial_input: bytes) -> List[bytes]:
        """
        Generate corpus targeting specific VM handler.
        
        Create input that exercise different handler behavior.
        """
        corpus = []
        
        for handler in vm_handlers:
            # Generate input for this handler
            mutated = self.mutate_for_vm_handler(initial_input, handler)
            corpus.append(mutated)
            
        return corpus
