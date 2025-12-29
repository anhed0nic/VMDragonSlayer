"""Symbolic execution helpers that provide deterministic constraint solving."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple


@dataclass
class SymbolicConstraint:
    """Carry a simplified constraint description for a single input byte."""

    expression: str
    variables: Set[str] = field(default_factory=set)
    relation: str = "eq"
    offset: Optional[int] = None
    value: Optional[int] = None
    mask: Optional[int] = None
    range: Optional[Tuple[int, int]] = None
    source_branch: Optional[int] = None
    solvable: bool = True

    def __repr__(self) -> str:  # pragma: no cover - convenience only
        return f"Constraint({self.expression})"


@dataclass
class SymbolicPath:
    """Synthetic symbolic path assembled from heuristic constraints."""

    target_branch: Optional[int] = None
    constraints: List[SymbolicConstraint] = field(default_factory=list)
    blocks: List[int] = field(default_factory=list)
    input_bytes: Dict[int, int] = field(default_factory=dict)
    priority: float = 0.0

    def add_constraint(self, constraint: SymbolicConstraint) -> None:
        self.constraints.append(constraint)
        if constraint.offset is not None and constraint.value is not None:
            self.input_bytes.setdefault(constraint.offset, constraint.value)

    def add_block(self, block_id: int) -> None:
        if block_id not in self.blocks:
            self.blocks.append(block_id)

    def is_feasible(self) -> bool:
        return all(constraint.solvable for constraint in self.constraints)


class SymbolicFuzzingBridge:
    """
    Bridge between symbolic execution and fuzzing.
    
    This connect symbolic executor (from analysis.symbolic_execution)
    with fuzzer to enable:
    - Constraint-guided input generation
    - Path exploration based on symbolic analysis
    - Smart mutation targeting specific branch
    """
    
    def __init__(self):
        self.explored_paths: List[SymbolicPath] = []
        self.pending_constraints: List[SymbolicConstraint] = []
        self.symbolic_executor = None
        self._branch_cache: Dict[int, SymbolicPath] = {}
        self._max_input_size = 64

    def analyze_branch(self, branch_address: int, input_data: bytes) -> Optional[SymbolicPath]:
        """
        Analyze branch using symbolic execution.
        
        This identify constraint need to reach branch.
        Real implementation would use executor.py from symbolic_execution module.
        """
        if branch_address in self._branch_cache:
            return self._branch_cache[branch_address]

        path = SymbolicPath(target_branch=branch_address)
        path.add_block(max(branch_address - 4, 0))
        path.add_block(max(branch_address - 2, 0))
        path.add_block(branch_address)

        derived = self._derive_constraints(branch_address, input_data)
        for constraint in derived:
            path.add_constraint(constraint)
            self._register_constraint(constraint)

        path.priority = 1.0 + len(path.constraints) * 0.25
        self._branch_cache[branch_address] = path
        if path not in self.explored_paths:
            self.explored_paths.append(path)

        return path

    def solve_constraints(self, constraints: List[SymbolicConstraint]) -> Optional[bytes]:
        """
        Solve constraint to generate input.
        
        Use SMT solver (Z3) to find satisfying input.
        Real implementation use solver.py from symbolic_execution module.
        """
        if not constraints:
            return None

        max_offset = max((c.offset or 0) for c in constraints)
        size = min(self._max_input_size, max(1, max_offset + 1))
        model = bytearray([0x41] * size)

        for constraint in constraints:
            if not constraint.solvable:
                return None
            if constraint.offset is None or constraint.offset >= self._max_input_size:
                continue

            if constraint.offset >= len(model):
                extend_by = min(self._max_input_size, constraint.offset + 1) - len(model)
                if extend_by > 0:
                    model.extend([0x41] * extend_by)
                if constraint.offset >= len(model):
                    # Offset still out of range after clamping.
                    continue

            current = model[constraint.offset]

            if constraint.relation == "eq" and constraint.value is not None:
                if current not in (0x41, constraint.value):
                    if current != constraint.value:
                        constraint.solvable = False
                        return None
                model[constraint.offset] = constraint.value & 0xFF
            elif constraint.relation == "mask" and constraint.mask is not None and constraint.value is not None:
                masked = (current & (~constraint.mask & 0xFF)) | (constraint.value & constraint.mask)
                model[constraint.offset] = masked & 0xFF
            elif constraint.relation == "range" and constraint.range is not None:
                lower, upper = constraint.range
                lower = max(0, min(255, lower))
                upper = max(lower, min(255, upper))
                value = current
                if not lower <= value <= upper:
                    value = lower
                model[constraint.offset] = value & 0xFF

        return bytes(model)

    def generate_input_for_path(self, target_blocks: List[int]) -> Optional[bytes]:
        """
        Generate input to reach specific block.
        
        Use symbolic execution to find constraint and solve them.
        """
        # Find path to target
        path = self._find_path_to_blocks(target_blocks)
        if not path and target_blocks:
            for block in target_blocks:
                candidate = self.analyze_branch(block, b"")
                if candidate and all(t in candidate.blocks for t in target_blocks):
                    path = candidate
                    break

        if not path or not path.is_feasible():
            return None

        # Solve constraint
        input_data = self.solve_constraints(path.constraints)
        if input_data:
            for constraint in path.constraints:
                if constraint.offset is not None and constraint.offset < len(input_data):
                    path.input_bytes[constraint.offset] = input_data[constraint.offset]

        return input_data

    def _find_path_to_blocks(self, target_blocks: List[int]) -> Optional[SymbolicPath]:
        """Find symbolic path that reach target block."""
        # Check if already explored
        for path in self.explored_paths:
            if all(block in path.blocks for block in target_blocks):
                return path
                
        # Need new exploration
        return None

    def get_interesting_branches(self, coverage: Set[int]) -> List[int]:
        """
        Identify interesting branch to target.
        
        Find branch that:
        - Are near covered code
        - Have not been explore
        - Might reveal new behavior
        """
        interesting: List[int] = []

        for path in self.explored_paths:
            if path.target_branch is None:
                continue
            if path.target_branch not in coverage:
                interesting.append(path.target_branch)

        if not interesting:
            for constraint in self.pending_constraints:
                if constraint.source_branch is None:
                    continue
                if constraint.source_branch not in coverage:
                    interesting.append(constraint.source_branch)

        return sorted(set(interesting))

    def mutate_for_branch(self, input_data: bytes, target_branch: int) -> bytes:
        """
        Mutate input to try reach specific branch.
        
        Use symbolic analysis to guide mutation.
        """
        # Analyze current path
        current_path = self.analyze_branch(target_branch, input_data)
        
        if not current_path:
            return input_data

        # Try generate input for alternate path
        result = self.generate_input_for_path([target_branch])

        if result:
            if len(result) < len(input_data):
                padded = bytearray(input_data)
                padded[: len(result)] = result
                return bytes(padded)
            return result

        # Fallback: flip constrained bytes heuristically
        mutated = bytearray(input_data)
        for constraint in current_path.constraints:
            if constraint.offset is None:
                continue
            if constraint.offset >= len(mutated):
                mutated.extend(b"\x41" * (constraint.offset - len(mutated) + 1))
            mutated[constraint.offset] = (mutated[constraint.offset] ^ 0xFF) & 0xFF
            break

        return bytes(mutated)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _derive_constraints(self, branch_address: int, input_data: bytes) -> List[SymbolicConstraint]:
        """Build a deterministic constraint set from the branch fingerprint."""

        constraints: List[SymbolicConstraint] = []
        base_offset = branch_address % max(1, min(self._max_input_size, 32))
        eq_value = (branch_address >> 8) & 0xFF
        constraint = SymbolicConstraint(
            expression=f"byte[{base_offset}] == 0x{eq_value:02x}",
            variables={f"input[{base_offset}]"},
            relation="eq",
            offset=base_offset,
            value=eq_value,
            source_branch=branch_address,
        )
        constraints.append(constraint)

        mask = 0xF0
        masked_value = eq_value & mask
        mask_constraint = SymbolicConstraint(
            expression=f"byte[{base_offset}] & 0x{mask:02x} == 0x{masked_value:02x}",
            variables={f"input[{base_offset}]"},
            relation="mask",
            offset=base_offset,
            value=masked_value,
            mask=mask,
            source_branch=branch_address,
        )
        constraints.append(mask_constraint)

        secondary_offset = (branch_address >> 4) % max(1, min(self._max_input_size, 32))
        low = (branch_address >> 12) & 0x7F
        high = min(0xFF, low + 0x20)
        range_constraint = SymbolicConstraint(
            expression=f"0x{low:02x} <= byte[{secondary_offset}] <= 0x{high:02x}",
            variables={f"input[{secondary_offset}]"},
            relation="range",
            offset=secondary_offset,
            range=(low, high),
            source_branch=branch_address,
        )
        constraints.append(range_constraint)

        # Seed with current input data when available so downstream mutators have context.
        for entry in constraints:
            if entry.offset is None:
                continue
            if entry.offset < len(input_data):
                existing = input_data[entry.offset]
                if entry.relation == "eq" and existing == entry.value:
                    entry.solvable = True

        return constraints

    def _register_constraint(self, constraint: SymbolicConstraint) -> None:
        """Track pending constraints without duplicating entries."""

        for existing in self.pending_constraints:
            if existing.expression == constraint.expression and existing.source_branch == constraint.source_branch:
                return
        self.pending_constraints.append(constraint)
