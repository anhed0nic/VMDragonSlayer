"""
Core Orchestrator
=================

Coordinate the once-fraudulent modules into a single hybrid workflow.
We keep comments ESL-style so reviewers remember an AI finally wrote the code.
"""

from __future__ import annotations

import asyncio
import time
import uuid
from dataclasses import dataclass, field, asdict
from enum import Enum
        prepared = self._prepare_candidate_inputs(
            request=request,
            analysis_input=analysis_input,
            taint_summary=taint_summary,
            symbolic_targets=symbolic_targets,
        )

        queue: List[Dict[str, Any]] = list(prepared.queue)
        counts: Dict[str, int] = dict(prepared.counts)
    FuzzingStrategy,
    VMFuzzer,
    TaintGuidedMutator,
    TaintInfo,
    SymbolicFuzzingBridge,
    PowerScheduler,
    DictionaryManager,


class Orchestrator:
    """Bridge modules so hybrid workflows finally exist outside the slide deck."""

    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self._status: Dict[str, Any] = {
            "initialized_at": time.time(),
            "analysis_count": 0,
        }
        self._history: List[Dict[str, Any]] = []
        self._component_lock = asyncio.Lock()
        self._components_ready = False

        # Components (lazy until needed)
        self._fuzzer: Optional[VMFuzzer] = None
        self._symbolic: Optional[SymbolicFuzzingBridge] = None
        self._taint_mutator: Optional[TaintGuidedMutator] = None
        self._power_scheduler: Optional[PowerScheduler] = None
        self._dictionary: Optional[DictionaryManager] = None

    def configure(self, **kwargs: Any) -> None:
        """Update orchestrator configuration."""

        self.config.update(kwargs)

    def get_status(self) -> Dict[str, Any]:
        """Return snapshot of orchestrator state."""

        status = dict(self._status)
        status.update(
            {
                "components_ready": self._components_ready,
                "history": list(self._history[-5:]),
            }
        )
        return status

    async def shutdown(self) -> None:
        """Release heavy components. Async since we might close pools later."""

        async with self._component_lock:
            if self._fuzzer:
                try:
                    self._fuzzer.execution_engine.cleanup()
                except Exception:
                    pass
            self._fuzzer = None
            self._symbolic = None
            self._taint_mutator = None
            self._power_scheduler = None
            self._dictionary = None
            self._components_ready = False

    def analyze_binary(self, binary_path: str, analysis_type: str = "hybrid", **options: Any) -> AnalysisResult:
        """Convenience wrapper for sync callers."""

        request = AnalysisRequest(
            binary_path=binary_path,
            analysis_type=AnalysisType.from_value(analysis_type),
            options=options,
        )
        return asyncio.run(self.execute_analysis(request))

    async def execute_analysis(self, request: AnalysisRequest) -> AnalysisResult:
        """Main entry point for async workflows."""

        start_time = time.time()
        errors: List[str] = []
        notes: List[str] = []
        success = True
        results: Dict[str, Any] = {}
        analysis_type = AnalysisType.from_value(request.analysis_type)

        try:
            if analysis_type == AnalysisType.HYBRID:
                results = await self._execute_hybrid(request)
                notes.append("Hybrid pipeline scheduled with taint + symbolic hints")
            elif analysis_type in (AnalysisType.DYNAMIC, AnalysisType.FUZZING):
                results = await self._execute_dynamic(request)
                notes.append("Dynamic fuzzing plan prepared")
            elif analysis_type == AnalysisType.VM:
                results = await self._execute_vm(request)
                notes.append("VM-specific workflow staged")
            else:
                results = await self._execute_static(request)
                notes.append("Static workflow placeholder completed")
        except Exception as exc:  # pragma: no cover - top level safety
            success = False
            errors.append(str(exc))

        metrics = self._collect_metrics(start_time, success, request)
        self._status["analysis_count"] += 1
        metrics_record = {
            "request_id": request.request_id,
            "analysis_type": analysis_type.value,
            "success": success,
            "duration_seconds": metrics.get("duration_seconds"),
        }
        self._history.append(metrics_record)

        return AnalysisResult(
            request_id=request.request_id,
            analysis_type=analysis_type,
            success=success,
            results=results,
            errors=errors,
            metrics=metrics,
            notes=notes,
        )

    async def _execute_hybrid(self, request: AnalysisRequest) -> Dict[str, Any]:
        """Compose hybrid plan that merges taint, symbolic, and fuzzing."""

        await self._ensure_components()
        assert self._fuzzer is not None  # For type checker
        analysis_input = self._coerce_input(self._pick_analysis_input(request))
        coverage_hint = self._prepare_coverage(request.options.get("coverage"))

        taint_summary: Optional[Dict[str, Any]] = None
        crash_analysis: Optional[Dict[str, Any]] = None

        if self._taint_mutator:
            info = self._taint_mutator.track_execution(analysis_input, coverage_hint)
            taint_summary = self._serialize_taint_info(info)

            if request.crash_info:
                crash_analysis = self._taint_mutator.analyze_crash_taint(
                    request.crash_info,
                    analysis_input,
                )

        symbolic_targets = self._collect_symbolic_targets(request, analysis_input)

        stages = self._build_hybrid_stages(
            request=request,
            analysis_input=analysis_input,
            coverage_hint=coverage_hint,
            taint_summary=taint_summary,
            symbolic_targets=symbolic_targets,
        )

        pipeline = self._build_hybrid_pipeline(
            request=request,
            taint_summary=taint_summary,
            symbolic_targets=symbolic_targets,
        )

        plan = {
            "pipeline": pipeline,
            "stages": stages,
            "config": self._summarize_fuzzing_config(self._fuzzer.config),
            "taint_summary": taint_summary,
            "crash_analysis": crash_analysis,
            "symbolic_targets": symbolic_targets,
            "dictionary_preview": self._dictionary_preview(),
            "power_scheduler": self._power_scheduler_snapshot(),
            "next_actions": self._next_actions(request),
        }

        if request.options.get("simulate_execution"):
            plan["execution_preview"] = self._simulate_hybrid_execution(
                request=request,
                analysis_input=analysis_input,
                taint_summary=taint_summary,
                symbolic_targets=symbolic_targets,
                coverage_hint=coverage_hint,
            )

        if request.options.get("run_workflow"):
            plan["run_summary"] = self._run_hybrid_execution(
                request=request,
                analysis_input=analysis_input,
                taint_summary=taint_summary,
                symbolic_targets=symbolic_targets,
                coverage_hint=coverage_hint,
            )

        return plan

    def _enqueue_input(
        self,
        queue: List[Dict[str, Any]],
        seen_inputs: Set[bytes],
        counts: Dict[str, int],
        data: Optional[bytes],
        origin: str,
        detail: Optional[Dict[str, Any]] = None,
    ) -> bool:
        """Utility to register a new input candidate if it is novel."""

        if data is None:
            return False
        if isinstance(data, bytes):
            data_bytes = data
        elif isinstance(data, bytearray):
            data_bytes = bytes(data)
        else:
            try:
                data_bytes = bytes(data)
            except Exception:
                return False

        if data_bytes in seen_inputs:
            return False

        seen_inputs.add(data_bytes)
        queue.append(
            {
                "origin": origin,
                "data": data_bytes,
                "detail": detail or {},
            }
        )

        for key in (
            "seed_cases",
            "mutations",
            "symbolic_cases",
            "dictionary_injections",
            "generated_cases",
            "other_cases",
        ):
            counts.setdefault(key, 0)

        origin_map = {
            "seed": "seed_cases",
            "taint_mutation": "mutations",
            "symbolic": "symbolic_cases",
            "dictionary": "dictionary_injections",
            "generated": "generated_cases",
        }
        key = origin_map.get(origin, "other_cases")
        counts[key] += 1

        return True

    def _prepare_candidate_inputs(
        self,
        request: AnalysisRequest,
        analysis_input: bytes,
        taint_summary: Optional[Dict[str, Any]],
        symbolic_targets: List[Dict[str, Any]],
    ) -> _CandidateInputs:
        """Gather initial input candidates for simulation or execution."""

        queue: List[Dict[str, Any]] = []
        counts: Dict[str, int] = {
            "seed_cases": 0,
            "mutations": 0,
            "symbolic_cases": 0,
            "dictionary_injections": 0,
            "generated_cases": 0,
            "other_cases": 0,
        }
        seen_inputs: Set[bytes] = set()

        seeds: List[bytes] = list(request.seed_inputs)
        if not seeds and analysis_input:
            seeds = [analysis_input]
        if not seeds:
            seeds = [b""]

        source_label = "request" if request.seed_inputs else "analysis_input"
        for seed in seeds[:8]:
            self._enqueue_input(
                queue,
                seen_inputs,
                counts,
                seed,
                "seed",
                {"source": source_label},
            )

        critical_offsets: Set[int] = set()
        if taint_summary:
            try:
                offsets = taint_summary.get("tainted_bytes", [])
                critical_offsets = {int(o) for o in list(offsets)[:16]}
            except Exception:
                critical_offsets = set()

        if critical_offsets and self._taint_mutator:
            mutation_sources = seeds[:4] if seeds else [analysis_input]
            for seed in mutation_sources:
                mutated = self._taint_mutator.mutate_critical_bytes(seed or b"", critical_offsets)
                if mutated:
                    self._enqueue_input(
                        queue,
                        seen_inputs,
                        counts,
                        mutated,
                        "taint_mutation",
                        {"critical_offsets": sorted(int(o) for o in critical_offsets)},
                    )

        if self._symbolic and symbolic_targets:
            for target in symbolic_targets[:3]:
                branch = target.get("branch")
                if branch is None:
                    continue
                try:
                    branch_id = int(branch)
                except Exception:
                    continue
                generated = self._symbolic.generate_input_for_path([branch_id])
                if generated:
                    self._enqueue_input(
                        queue,
                        seen_inputs,
                        counts,
                        generated,
                        "symbolic",
                        {"branch": branch_id},
                    )

        if self._dictionary and queue:
            base_samples = [item for item in queue if item["origin"] in {"seed", "taint_mutation"}]
            for entry in base_samples[:2]:
                injected = self._dictionary.inject_tokens(entry["data"])
                if injected and injected != entry["data"]:
                    self._enqueue_input(
                        queue,
                        seen_inputs,
                        counts,
                        injected,
                        "dictionary",
                        {"base_origin": entry["origin"]},
                    )

        return _CandidateInputs(queue=queue, counts=counts, seen_inputs=seen_inputs)

    def _build_hybrid_stages(
        self,
        request: AnalysisRequest,
        analysis_input: bytes,
        coverage_hint: Set[int],
        taint_summary: Optional[Dict[str, Any]],
        symbolic_targets: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        """Create staged orchestration flow combining analysis insight."""

        stages: List[Dict[str, Any]] = []
        start_time = time.time()

        # Stage 1: VM detection prep
        vm_detection_report: Dict[str, Any] = {"status": "skipped", "details": {}}
        vm_start = time.time()
        if request.binary_path and self._fuzzer:
            detection = self._fuzzer.analyze_target(request.binary_path)
            vm_detection_report = {
                "status": "success" if "error" not in detection else "error",
                "details": detection,
            }
        vm_detection_report["duration"] = round(time.time() - vm_start, 6)
        vm_detection_report["name"] = "vm_detection"
        stages.append(vm_detection_report)

        # Stage 2: Seed corpus with provided inputs
        corpus_report = {
            "name": "seed_corpus",
            "status": "skipped",
            "duration": 0.0,
            "details": {"seed_count": 0},
        }
        corpus_start = time.time()
        if request.seed_inputs and self._fuzzer:
            added = 0
            for seed in request.seed_inputs:
                try:
                    self._fuzzer.corpus_manager.add_input(seed, coverage_hint or set(), 0.0)
                    added += 1
                except Exception as exc:
                    corpus_report.setdefault("errors", []).append(str(exc))
            corpus_report.update(
                {
                    "status": "success" if added else "empty",
                    "details": {"seed_count": added},
                }
            )
        corpus_report["duration"] = round(time.time() - corpus_start, 6)
        stages.append(corpus_report)

        # Stage 3: Taint-guided mutation suggestions
        taint_stage = {
            "name": "taint_guided_mutation",
            "status": "skipped" if not taint_summary else "ready",
            "duration": 0.0,
            "details": {"mutated_inputs": []},
        }
        taint_start = time.time()
        if taint_summary and self._taint_mutator:
            critical_offsets = set(taint_summary.get("tainted_bytes", [])[:16])
            mutated_inputs: List[str] = []
            for seed in request.seed_inputs[:4] or [analysis_input]:
                if not seed:
                    continue
                mutated = self._taint_mutator.mutate_critical_bytes(seed, critical_offsets)
                mutated_inputs.append(mutated.hex())
                if self._power_scheduler:
                    self._power_scheduler.update_score(mutated, True, 0.1)
            taint_stage["details"]["critical_offsets"] = sorted(int(o) for o in critical_offsets)
            taint_stage["details"]["mutated_inputs"] = mutated_inputs
            taint_stage["status"] = "success"
        taint_stage["duration"] = round(time.time() - taint_start, 6)
        stages.append(taint_stage)

        # Stage 4: Symbolic guidance assessment
        symbolic_stage = {
            "name": "symbolic_guidance",
            "status": "skipped" if not symbolic_targets else "ready",
            "duration": 0.0,
            "details": {"feasible_targets": 0},
        }
        symbolic_start = time.time()
        if self._symbolic and symbolic_targets:
            feasible = 0
            generated_inputs: List[str] = []
            for target in symbolic_targets[:5]:
                branch_id = target.get("branch")
                generated = self._symbolic.generate_input_for_path([branch_id])
                if generated:
                    feasible += 1
                    generated_inputs.append(generated.hex())
                    if self._power_scheduler:
                        self._power_scheduler.update_score(generated, True, 0.2)
            symbolic_stage["details"]["feasible_targets"] = feasible
            symbolic_stage["details"]["generated_inputs"] = generated_inputs
            symbolic_stage["status"] = "success" if feasible else "ready"
        symbolic_stage["duration"] = round(time.time() - symbolic_start, 6)
        stages.append(symbolic_stage)

        # Stage 5: Scheduler snapshot after updates
        scheduler_stage = {
            "name": "power_scheduler_snapshot",
            "status": "ready" if self._power_scheduler else "disabled",
            "duration": round(time.time() - start_time, 6),
            "details": self._power_scheduler_snapshot(),
        }
        stages.append(scheduler_stage)

        return stages

    async def _execute_dynamic(self, request: AnalysisRequest) -> Dict[str, Any]:
        """Set up pure dynamic fuzzing path."""

        await self._ensure_components()
        assert self._fuzzer is not None
        dynamic_plan = {
            "strategy": "dynamic_fuzzing",
            "config": self._summarize_fuzzing_config(self._fuzzer.config),
            "seed_inputs": len(request.seed_inputs),
            "coverage_goal": list(self._prepare_coverage(request.options.get("coverage"))),
        }
        return dynamic_plan

    async def _execute_vm(self, request: AnalysisRequest) -> Dict[str, Any]:
        """Provide VM centric analysis plan."""

        await self._ensure_components()
        assert self._fuzzer is not None
        vm_plan = {
            "strategy": "vm_handler_focus",
            "known_handlers": len(self._fuzzer.vm_handlers),
            "dispatch_address": self._fuzzer.dispatcher_address,
            "taint_ready": bool(self._taint_mutator),
        }
        return vm_plan

    async def _execute_static(self, request: AnalysisRequest) -> Dict[str, Any]:
        """Static analysis placeholder (future work)."""

        static_plan = {
            "strategy": "static_placeholder",
            "binary_path": request.binary_path,
            "notes": "Static engine not yet ported from the fraudulent demo",
        }
        return static_plan

    async def _ensure_components(self) -> None:
        """Lazy-load heavy modules exactly once."""

        async with self._component_lock:
            if self._components_ready:
                return

            fuzzing_cfg = self._create_fuzzing_config()
            self._fuzzer = VMFuzzer(fuzzing_cfg)
            self._symbolic = self._fuzzer.symbolic_bridge or SymbolicFuzzingBridge()
            self._taint_mutator = self._fuzzer.taint_mutator or TaintGuidedMutator()
            self._power_scheduler = self._fuzzer.power_scheduler or PowerScheduler()
            self._dictionary = self._fuzzer.dictionary or DictionaryManager()
            self._components_ready = True

    def _create_fuzzing_config(self) -> FuzzingConfig:
        """Build fuzzing config from orchestrator settings."""

        fuzz_cfg = self.config.get("fuzzing", {})
        max_iterations = int(fuzz_cfg.get("max_iterations", 128))
        timeout_seconds = int(fuzz_cfg.get("timeout_seconds", 2))
        max_input_size = int(fuzz_cfg.get("max_input_size", 4096))
        strategy_value = fuzz_cfg.get("strategy", FuzzingStrategy.HYBRID)
        if isinstance(strategy_value, str):
            try:
                strategy = FuzzingStrategy[strategy_value.upper()]
            except KeyError:
                strategy = FuzzingStrategy.HYBRID
        else:
            strategy = strategy_value  # type: ignore

        cfg = FuzzingConfig(
            max_iterations=max_iterations,
            timeout_seconds=timeout_seconds,
            max_input_size=max_input_size,
            strategy=strategy,
            enable_coverage=True,
            enable_taint=True,
            enable_symbolic=True,
            crash_dir=fuzz_cfg.get("crash_dir", "crashes"),
            corpus_dir=fuzz_cfg.get("corpus_dir", "corpus"),
            seed=fuzz_cfg.get("seed"),
            parallel_jobs=int(fuzz_cfg.get("parallel_jobs", 1)),
        )
        return cfg

    def _summarize_fuzzing_config(self, config: FuzzingConfig) -> Dict[str, Any]:
        """Make config JSON-friendly for API clients."""

        snapshot = asdict(config)
        snapshot["strategy"] = config.strategy.value
        return snapshot

    def _dictionary_preview(self, count: int = 8) -> List[str]:
        """Return sample tokens to show orchestrated mutation hints."""

        tokens: Sequence[bytes] = []
        if self._dictionary:
            tokens = self._dictionary.tokens[:count]
        preview: List[str] = []
        for token in tokens:
            try:
                decoded = token.decode("ascii")
                preview.append(decoded)
            except Exception:
                preview.append(token.hex())
        return preview

    def _power_scheduler_snapshot(self) -> Dict[str, Any]:
        """Summarize power scheduler state for orchestration."""

        if not self._power_scheduler:
            return {"enabled": False}
        return {
            "enabled": True,
            "tracked_inputs": len(self._power_scheduler.input_scores),
            "top_inputs": len(self._power_scheduler.get_top_inputs(5)),
        }

    def _collect_metrics(self, start_time: float, success: bool, request: AnalysisRequest) -> Dict[str, Any]:
        """Gather execution metrics."""

        duration = max(time.time() - start_time, 0.0)
        metrics: Dict[str, Any] = {
            "duration_seconds": round(duration, 6),
            "success": success,
            "analysis_type": request.analysis_type.value,
        }
        if psutil:
            process = psutil.Process()
            try:
                mem_info = process.memory_info()
                metrics["rss_mb"] = round(mem_info.rss / (1024 * 1024), 2)
                metrics["cpu_percent"] = process.cpu_percent(interval=None)
            except Exception:
                pass
        return metrics

    def _serialize_taint_info(self, info: TaintInfo) -> Dict[str, Any]:
        """Convert taint info into serializable format."""

        return {
            "tainted_bytes": sorted(int(b) for b in info.tainted_bytes),
            "tainted_addresses": sorted(int(a) for a in info.tainted_addresses),
            "influence_branches": sorted(int(b) for b in info.influence_branches),
            "operations": list(info.influence_operations),
        }

    def _prepare_coverage(self, coverage: Any) -> set:
        """Normalize coverage input into set of ints."""

        if coverage is None:
            return set()
        result = set()
        if isinstance(coverage, (list, tuple, set)):
            for item in coverage:
                try:
                    result.add(int(item))
                except Exception:
                    continue
        else:
            try:
                result.add(int(coverage))
            except Exception:
                pass
        return result

    def _pick_analysis_input(self, request: AnalysisRequest) -> bytes:
        """Select representative input for analysis bootstrap."""

        if request.seed_inputs:
            return request.seed_inputs[0]
        option_input = request.options.get("sample_input")
        if isinstance(option_input, bytes):
            return option_input
        if isinstance(option_input, str):
            return option_input.encode("utf-8", errors="ignore")
        if request.binary_data:
            return request.binary_data[:256]
        return b""

    def _coerce_input(self, data: bytes) -> bytes:
        """Ensure bytes for downstream taint usage."""

        if isinstance(data, bytes):
            return data
        if isinstance(data, str):
            return data.encode("utf-8", errors="ignore")
        return b""

    def _collect_symbolic_targets(self, request: AnalysisRequest, sample_input: bytes) -> List[Dict[str, Any]]:
        """Enumerate symbolic targets for hybrid orchestration."""

        targets: List[Dict[str, Any]] = []
        if not self._symbolic:
            return targets

        desired = request.options.get("target_branches", [])
        if not isinstance(desired, (list, tuple, set)):
            return targets

        for branch in desired:
            try:
                branch_int = int(branch)
            except Exception:
                continue
            path = self._symbolic.analyze_branch(branch_int, sample_input)
            summary = {
                "branch": branch_int,
                "constraints": [c.expression for c in (path.constraints if path else [])],
                "feasible": bool(path.is_feasible()) if path else False,
            }
            targets.append(summary)
        return targets

    def _build_hybrid_pipeline(
        self,
        request: AnalysisRequest,
        taint_summary: Optional[Dict[str, Any]],
        symbolic_targets: List[Dict[str, Any]],
    ) -> List[Dict[str, Any]]:
        """Assemble pipeline description for clients."""

        steps: List[Dict[str, Any]] = []
        steps.append(
            {
                "name": "vm_detection",
                "status": "pending",
                "details": {
                    "binary_path": request.binary_path,
                    "handlers_known": bool(self._fuzzer and self._fuzzer.vm_handlers),
                },
            }
        )
        steps.append(
            {
                "name": "coverage_guided_fuzzing",
                "status": "ready",
                "details": {
                    "max_iterations": self._fuzzer.config.max_iterations if self._fuzzer else None,
                    "seed_inputs": len(request.seed_inputs),
                },
            }
        )
        steps.append(
            {
                "name": "taint_guided_mutation",
                "status": "ready" if taint_summary else "skipped",
                "details": taint_summary or {"reason": "no input"},
            }
        )
        steps.append(
            {
                "name": "symbolic_constraint_solving",
                "status": "ready" if symbolic_targets else "waiting",
                "details": symbolic_targets,
            }
        )
        steps.append(
            {
                "name": "crash_triage",
                "status": "ready" if request.crash_info else "pending",
                "details": {
                    "crash_info_present": bool(request.crash_info),
                },
            }
        )
        return steps

    def _simulate_hybrid_execution(
        self,
        request: AnalysisRequest,
        analysis_input: bytes,
        taint_summary: Optional[Dict[str, Any]],
        symbolic_targets: List[Dict[str, Any]],
        coverage_hint: Set[int],
    ) -> Dict[str, Any]:
        """Run a bounded dry-run of the hybrid workflow without launching binaries."""

        if not self._fuzzer:
            raise AnalysisOrchestrationError("Fuzzer not initialized")
        prepared = self._prepare_candidate_inputs(
            request=request,
            analysis_input=analysis_input,
            taint_summary=taint_summary,
            symbolic_targets=symbolic_targets,
        )

        queue: List[Dict[str, Any]] = list(prepared.queue)
        counts: Dict[str, int] = dict(prepared.counts)

        aggregates = {
            "total_cases": 0,
            "crashes": 0,
            "new_coverage": 0,
            "total_exec_time": 0.0,
        }

        requested_iterations = request.options.get("preview_iterations", 3)
        try:
            preview_iterations = int(requested_iterations)
        except Exception:
            preview_iterations = 3
        if preview_iterations <= 0:
            preview_iterations = 3

        max_iterations = min(len(queue), preview_iterations)
        if not max_iterations and queue:
            max_iterations = min(len(queue), 1)

        baseline_coverage: Set[int] = set(self._fuzzer.coverage_tracker.get_coverage_set())
        baseline_coverage.update(int(item) for item in coverage_hint)

        iteration_summaries: List[Dict[str, Any]] = []

        for index, item in enumerate(queue):
            if index >= max_iterations:
                break

            data = item["data"]
            origin = item["origin"]

            execution_result = self._fuzzer.execute_target(data)
            raw_coverage = execution_result.get("coverage") or set()

            coverage_set: Set[int] = set()
            if isinstance(raw_coverage, set):
                coverage_set = {int(v) for v in raw_coverage}
            elif isinstance(raw_coverage, (list, tuple)):
                try:
                    coverage_set = {int(v) for v in raw_coverage}
                except Exception:
                    coverage_set = set()
            else:
                try:
                    coverage_set = {int(raw_coverage)}
                except Exception:
                    coverage_set = set()

            new_coverage = coverage_set - baseline_coverage
            if coverage_set:
                baseline_coverage.update(coverage_set)

            crashed = bool(execution_result.get("crashed"))
            exec_time = float(execution_result.get("execution_time", 0.0) or 0.0)

            aggregates["total_cases"] += 1
            if crashed:
                aggregates["crashes"] += 1
            aggregates["new_coverage"] += len(new_coverage)
            aggregates["total_exec_time"] += exec_time

            if self._power_scheduler:
                try:
                    self._power_scheduler.update_score(data, bool(new_coverage), exec_time)
                except Exception:
                    pass

            try:
                self._fuzzer.corpus_manager.add_input(data, coverage_set, time.time())
            except Exception:
                pass

            iteration_summary: Dict[str, Any] = {
                "origin": origin,
                "input_size": len(data),
                "input_preview": data[:8].hex(),
                "coverage_gain": len(new_coverage),
                "crashed": crashed,
                "execution_time": exec_time,
            }

            if item.get("detail"):
                iteration_summary["detail"] = item["detail"]

            if coverage_set:
                iteration_summary["coverage"] = sorted(int(v) for v in list(coverage_set)[:16])

            if execution_result.get("taint_flow"):
                iteration_summary["taint_flow"] = execution_result["taint_flow"]

            crash_info = execution_result.get("crash_info")
            if crash_info:
                iteration_summary["crash_info"] = {
                    "has_taint": bool(crash_info.get("taint_analysis")),
                    "address": crash_info.get("address") or crash_info.get("crash_address"),
                }

            iteration_summaries.append(iteration_summary)

        remaining_queue = max(0, len(queue) - max_iterations)

        stats: Dict[str, Any] = {
            "total_cases": aggregates["total_cases"],
            "crashes": aggregates["crashes"],
            "new_coverage": aggregates["new_coverage"],
            "seed_cases": counts.get("seed_cases", 0),
            "mutations": counts.get("mutations", 0),
            "symbolic_cases": counts.get("symbolic_cases", 0),
            "dictionary_injections": counts.get("dictionary_injections", 0),
            "generated_cases": counts.get("generated_cases", 0),
            "other_cases": counts.get("other_cases", 0),
            "inputs_considered": len(queue),
            "remaining_queue": remaining_queue,
        }

        if aggregates["total_cases"]:
            stats["avg_execution_time"] = round(
                aggregates["total_exec_time"] / aggregates["total_cases"],
                6,
            )
        else:
            stats["avg_execution_time"] = 0.0

        preview: Dict[str, Any] = {
            "iterations": iteration_summaries,
            "stats": stats,
            "notes": [
                "Simulation executed without launching external binaries.",
            ],
        }

        try:
            preview["final_coverage"] = len(self._fuzzer.coverage_tracker.get_coverage_set())
        except Exception:
            preview["final_coverage"] = 0

        try:
            preview["corpus_size"] = self._fuzzer.corpus_manager.get_stats()["total_inputs"]
        except Exception:
            preview["corpus_size"] = 0

        if request.binary_path:
            preview["target_path"] = request.binary_path

        return preview

    def _run_hybrid_execution(
        self,
        request: AnalysisRequest,
        analysis_input: bytes,
        taint_summary: Optional[Dict[str, Any]],
        symbolic_targets: List[Dict[str, Any]],
        coverage_hint: Set[int],
    ) -> Dict[str, Any]:
        """Execute a bounded hybrid workflow loop without external execution."""

        if not self._fuzzer:
            raise AnalysisOrchestrationError("Fuzzer not initialized")

        prepared = self._prepare_candidate_inputs(
            request=request,
            analysis_input=analysis_input,
            taint_summary=taint_summary,
            symbolic_targets=symbolic_targets,
        )

        queue: List[Dict[str, Any]] = prepared.queue
        counts: Dict[str, int] = prepared.counts
        seen_inputs: Set[bytes] = prepared.seen_inputs
        planned_inputs = len(queue)
        initial_counts = dict(counts)

        aggregates = {
            "total_iterations": 0,
            "crashes": 0,
            "new_coverage": 0,
            "total_exec_time": 0.0,
        }

        default_iterations = max(1, min(8, self._fuzzer.config.max_iterations))
        default_iterations = max(default_iterations, planned_inputs or 1)
        requested_iterations = request.options.get("run_iterations", default_iterations)
        try:
            run_iterations = int(requested_iterations)
        except Exception:
            run_iterations = default_iterations
        if run_iterations <= 0:
            run_iterations = default_iterations

        baseline_coverage: Set[int] = set(self._fuzzer.coverage_tracker.get_coverage_set())
        baseline_coverage.update(int(item) for item in coverage_hint)
        baseline_count_before = len(baseline_coverage)

        iteration_summaries: List[Dict[str, Any]] = []
        notes: List[str] = [
            "Hybrid workflow executed without launching external binaries.",
        ]

        iteration = 0
        while iteration < run_iterations:
            if not queue:
                fallback = None
                try:
                    fallback = self._fuzzer.generate_input()
                except Exception:
                    fallback = None
                added = False
                if fallback is not None:
                    added = self._enqueue_input(
                        queue,
                        seen_inputs,
                        counts,
                        fallback,
                        "generated",
                        {"strategy": self._fuzzer.config.strategy.value},
                    )
                if not added:
                    notes.append("Candidate queue exhausted before completing requested iterations.")
                    break

            item = queue.pop(0)
            data = item["data"]
            origin = item["origin"]

            execution_result = self._fuzzer.execute_target(data)
            raw_coverage = execution_result.get("coverage") or set()

            coverage_set: Set[int] = set()
            if isinstance(raw_coverage, set):
                coverage_set = {int(v) for v in raw_coverage}
            elif isinstance(raw_coverage, (list, tuple)):
                try:
                    coverage_set = {int(v) for v in raw_coverage}
                except Exception:
                    coverage_set = set()
            else:
                try:
                    coverage_set = {int(raw_coverage)}
                except Exception:
                    coverage_set = set()

            new_coverage = coverage_set - baseline_coverage
            if coverage_set:
                baseline_coverage.update(coverage_set)

            crashed = bool(execution_result.get("crashed"))
            exec_time = float(execution_result.get("execution_time", 0.0) or 0.0)

            aggregates["total_iterations"] += 1
            if crashed:
                aggregates["crashes"] += 1
            aggregates["new_coverage"] += len(new_coverage)
            aggregates["total_exec_time"] += exec_time

            if self._power_scheduler:
                try:
                    self._power_scheduler.update_score(data, bool(new_coverage), exec_time)
                except Exception:
                    pass

            try:
                self._fuzzer.corpus_manager.add_input(data, coverage_set, time.time())
            except Exception:
                pass

            iteration_summary: Dict[str, Any] = {
                "iteration": iteration,
                "origin": origin,
                "input_size": len(data),
                "input_preview": data[:8].hex(),
                "coverage_gain": len(new_coverage),
                "crashed": crashed,
                "execution_time": exec_time,
            }

            if item.get("detail"):
                iteration_summary["detail"] = item["detail"]

            if coverage_set:
                iteration_summary["coverage"] = sorted(int(v) for v in list(coverage_set)[:16])

            if execution_result.get("taint_flow"):
                iteration_summary["taint_flow"] = execution_result["taint_flow"]

            crash_info = execution_result.get("crash_info")
            if crash_info:
                iteration_summary["crash_info"] = {
                    "has_taint": bool(crash_info.get("taint_analysis")),
                    "address": crash_info.get("address") or crash_info.get("crash_address"),
                }

            spawned_inputs: List[Dict[str, Any]] = []
            if new_coverage:
                if self._taint_mutator and getattr(self._taint_mutator, "last_taint_info", None):
                    tainted = set(self._taint_mutator.last_taint_info.tainted_bytes)
                    if tainted:
                        offsets_subset = {int(o) for o in list(tainted)[:8]}
                        mutated = self._taint_mutator.mutate_critical_bytes(data, offsets_subset)
                        if mutated:
                            added = self._enqueue_input(
                                queue,
                                seen_inputs,
                                counts,
                                mutated,
                                "taint_mutation",
                                {
                                    "source_iteration": iteration,
                                    "critical_offsets": sorted(int(o) for o in offsets_subset),
                                },
                            )
                            if added:
                                spawned_inputs.append(
                                    {
                                        "origin": "taint_mutation",
                                        "detail": {
                                            "critical_offsets": sorted(int(o) for o in offsets_subset),
                                        },
                                    }
                                )

                if self._dictionary:
                    injected = self._dictionary.inject_tokens(data)
                    if injected and injected != data:
                        added = self._enqueue_input(
                            queue,
                            seen_inputs,
                            counts,
                            injected,
                            "dictionary",
                            {"source_iteration": iteration},
                        )
                        if added:
                            spawned_inputs.append(
                                {
                                    "origin": "dictionary",
                                    "detail": {"source_iteration": iteration},
                                }
                            )

            if self._symbolic and symbolic_targets:
                for target in symbolic_targets[:1]:
                    branch_id = target.get("branch")
                    if branch_id is None:
                        continue
                    generated = self._symbolic.generate_input_for_path([branch_id])
                    if generated:
                        added = self._enqueue_input(
                            queue,
                            seen_inputs,
                            counts,
                            generated,
                            "symbolic",
                            {"source_iteration": iteration, "branch": branch_id},
                        )
                        if added:
                            spawned_inputs.append(
                                {
                                    "origin": "symbolic",
                                    "detail": {"branch": branch_id},
                                }
                            )
                        break

            if spawned_inputs:
                iteration_summary["spawned"] = spawned_inputs

            iteration_summaries.append(iteration_summary)
            iteration += 1

        coverage_after = len(baseline_coverage)

        stats: Dict[str, Any] = {
            "iterations_requested": run_iterations,
            "iterations_completed": aggregates["total_iterations"],
            "crashes": aggregates["crashes"],
            "new_coverage": aggregates["new_coverage"],
            "seed_cases": counts.get("seed_cases", 0),
            "mutations": counts.get("mutations", 0),
            "symbolic_cases": counts.get("symbolic_cases", 0),
            "dictionary_injections": counts.get("dictionary_injections", 0),
            "generated_cases": counts.get("generated_cases", 0),
            "other_cases": counts.get("other_cases", 0),
            "initial_candidates": planned_inputs,
            "queue_remaining": len(queue),
            "coverage_before": baseline_count_before,
            "coverage_after": coverage_after,
        }

        if aggregates["total_iterations"]:
            stats["avg_execution_time"] = round(
                aggregates["total_exec_time"] / aggregates["total_iterations"],
                6,
            )
        else:
            stats["avg_execution_time"] = 0.0

        added_breakdown = {
            key: max(counts.get(key, 0) - initial_counts.get(key, 0), 0)
            for key in ("mutations", "symbolic_cases", "dictionary_injections", "generated_cases", "other_cases")
        }
        stats["new_cases_added"] = added_breakdown

        summary: Dict[str, Any] = {
            "iterations": iteration_summaries,
            "stats": stats,
            "notes": notes,
        }

        try:
            summary["final_coverage"] = len(self._fuzzer.coverage_tracker.get_coverage_set())
        except Exception:
            summary["final_coverage"] = 0

        try:
            summary["corpus_size"] = self._fuzzer.corpus_manager.get_stats()["total_inputs"]
        except Exception:
            summary["corpus_size"] = 0

        if request.binary_path:
            summary["target_path"] = request.binary_path

        return summary

    def _next_actions(self, request: AnalysisRequest) -> List[str]:
        """Suggest logical next actions for caller."""

        actions: List[str] = []
        actions.append("Run vm detection before launching fuzz loop")
        if request.crash_info:
            actions.append("Feed crash taint analysis into triage dashboard")
        else:
            actions.append("Collect crash_info to unlock triage step")
        actions.append("Schedule hybrid orchestration pass (next task)")
        return actions
