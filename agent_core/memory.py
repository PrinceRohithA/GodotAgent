"""Working memory + compaction hooks.

Godot is the source of truth for project state. Memory holds task context,
decisions, hypotheses, recent changes, and verification results (PRD §12).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable, List, Mapping, Optional, Sequence

from agent_core.state import AgentState, ChangeRecord, VerificationRecord


CompactionFn = Callable[["WorkingMemory", AgentState], "WorkingMemory"]


@dataclass
class WorkingMemory:
    """Compact task-scoped memory carried across iterations."""

    goal: str = ""
    plan_summary: str = ""
    relevant_files: List[str] = field(default_factory=list)
    relevant_nodes: List[str] = field(default_factory=list)
    recent_changes: List[ChangeRecord] = field(default_factory=list)
    hypotheses: List[str] = field(default_factory=list)
    test_results: List[VerificationRecord] = field(default_factory=list)
    known_issues: List[str] = field(default_factory=list)
    failed_approaches: List[str] = field(default_factory=list)
    next_action: str = ""
    # Soft token/char estimate for compaction triggers (provider fills later).
    approx_context_chars: int = 0
    compaction_threshold_chars: int = 80_000
    # Raw observation snippets that may be discarded on compaction.
    scratch_observations: List[str] = field(default_factory=list)

    def sync_from_state(self, state: AgentState) -> None:
        self.goal = state.goal
        self.plan_summary = "; ".join(
            f"{'[x]' if s.done else '[ ]'} {s.description}" for s in state.plan
        )
        self.recent_changes = list(state.recent_changes[-20:])
        self.hypotheses = list(state.hypotheses[-10:])
        self.test_results = list(state.verifications[-10:])
        self.known_issues = list(state.known_issues)
        self.next_action = state.next_action

    def needs_compaction(self) -> bool:
        return self.approx_context_chars >= self.compaction_threshold_chars

    def compact(self, fn: Optional[CompactionFn] = None, state: Optional[AgentState] = None) -> WorkingMemory:
        """Run compaction. Default drops scratch observations and trims lists.

        A future LLM-backed ``fn`` may summarize into ``plan_summary`` while
        preserving goal, decisions, changes, failures, and next objective.
        """
        if fn is not None and state is not None:
            return fn(self, state)

        self.scratch_observations.clear()
        self.recent_changes = self.recent_changes[-10:]
        self.hypotheses = self.hypotheses[-5:]
        self.test_results = self.test_results[-5:]
        self.failed_approaches = self.failed_approaches[-10:]
        self.approx_context_chars = max(0, self.approx_context_chars // 2)
        return self

    def as_prompt_dict(self) -> Mapping[str, Any]:
        """Stable JSON-ish view for model context."""
        return {
            "goal": self.goal,
            "plan": self.plan_summary,
            "relevant_files": list(self.relevant_files),
            "relevant_nodes": list(self.relevant_nodes),
            "recent_changes": [
                {
                    "iteration": c.iteration,
                    "type": c.change_type,
                    "path": c.path,
                    "operation": c.operation,
                }
                for c in self.recent_changes
            ],
            "hypotheses": list(self.hypotheses),
            "test_results": [
                {"iteration": v.iteration, "passed": v.passed, "failures": list(v.failures)}
                for v in self.test_results
            ],
            "known_issues": list(self.known_issues),
            "failed_approaches": list(self.failed_approaches),
            "next_action": self.next_action,
        }

    def remember_observation(self, text: str) -> None:
        self.scratch_observations.append(text)
        self.approx_context_chars += len(text)

    def note_relevant(self, *, files: Sequence[str] = (), nodes: Sequence[str] = ()) -> None:
        for f in files:
            if f not in self.relevant_files:
                self.relevant_files.append(f)
        for n in nodes:
            if n not in self.relevant_nodes:
                self.relevant_nodes.append(n)
