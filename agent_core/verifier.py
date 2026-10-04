"""Verification is first-class — never trust a mutation as success (PRD §38).

Evidence must come from Godot (inspect/read/diagnostics/runtime), not from
the agent's belief that a tool call succeeded.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Mapping, Optional, Protocol, Sequence

from agent_core.state import AgentState, VerificationRecord
from tools.abstract import AbstractGodotTools
from tools.schemas import (
    GetDiagnosticsArgs,
    InspectNodeArgs,
    ObserveRuntimeArgs,
    ReadScriptArgs,
    ToolResult,
)


@dataclass(frozen=True)
class VerificationCriterion:
    """A single check the verifier should try to satisfy with Godot evidence."""

    id: str
    description: str
    kind: str  # structural | code | runtime | gameplay
    # Optional structured hint for which tool/path to re-inspect.
    target: Optional[str] = None
    expected: Optional[Mapping[str, object]] = None
    requires_runtime: bool = False


class EvidenceCollector(Protocol):
    """Optional hook: gather extra Godot evidence for a criterion."""

    def __call__(
        self,
        tools: AbstractGodotTools,
        criterion: VerificationCriterion,
        state: AgentState,
    ) -> ToolResult: ...


@dataclass
class Verifier:
    """Runs verification using Godot-backed tool calls, not mutation ACKs."""

    evidence_hooks: List[EvidenceCollector] = field(default_factory=list)

    def verify(
        self,
        state: AgentState,
        tools: AbstractGodotTools,
        criteria: Sequence[VerificationCriterion],
    ) -> VerificationRecord:
        if not criteria:
            # No criteria ⇒ incomplete; caller must define what success looks like.
            record = VerificationRecord(
                iteration=state.iteration,
                passed=False,
                criteria=(),
                failures=["no_verification_criteria"],
                evidence={},
                requires_runtime=False,
            )
            state.verifications.append(record)
            return record

        failures: List[str] = []
        evidence: dict[str, object] = {}
        requires_runtime = any(c.requires_runtime for c in criteria)

        for criterion in criteria:
            result = self._collect_evidence(tools, criterion, state)
            evidence[criterion.id] = {
                "status": result.status.value,
                "data": dict(result.data),
                "evidence": dict(result.evidence),
                "error": result.error,
            }
            if not result.ok:
                failures.append(f"{criterion.id}: tool_error:{result.error or result.status.value}")
                continue
            ok, reason = self._evaluate(criterion, result)
            if not ok:
                failures.append(f"{criterion.id}: {reason}")

        record = VerificationRecord(
            iteration=state.iteration,
            passed=not failures,
            criteria=tuple(c.description for c in criteria),
            evidence=evidence,
            failures=tuple(failures),
            requires_runtime=requires_runtime,
        )
        state.verifications.append(record)
        return record

    def _collect_evidence(
        self,
        tools: AbstractGodotTools,
        criterion: VerificationCriterion,
        state: AgentState,
    ) -> ToolResult:
        for hook in self.evidence_hooks:
            return hook(tools, criterion, state)

        kind = criterion.kind
        target = criterion.target or ""

        if kind == "structural" and target:
            return tools.inspect_node(InspectNodeArgs(node_path=target, include_properties=True))
        if kind == "code" and target:
            return tools.read_script(ReadScriptArgs(script_path=target))
        if kind in ("runtime", "gameplay"):
            return tools.observe_runtime(
                ObserveRuntimeArgs(node_path=target or None, include_errors=True)
            )
        # Default: diagnostics sweep.
        return tools.get_diagnostics(GetDiagnosticsArgs(scope="all", path_filter=target or None))

    def _evaluate(
        self,
        criterion: VerificationCriterion,
        result: ToolResult,
    ) -> tuple[bool, str]:
        """Lightweight structural checks; richer LLM judging plugs in later."""
        expected = criterion.expected or {}
        if not expected:
            # Presence of Godot evidence without error is a weak pass for scaffolding.
            if result.ok and (result.data or result.evidence):
                return True, ""
            return False, "missing_godot_evidence"

        combined = {**dict(result.data), **dict(result.evidence)}
        for key, want in expected.items():
            got = combined.get(key)
            if got != want:
                return False, f"expected {key}={want!r} got {got!r}"
        return True, ""


def mutation_ack_is_not_success(_: ToolResult) -> bool:
    """Explicit policy helper: a successful write result is never verification."""
    return False
