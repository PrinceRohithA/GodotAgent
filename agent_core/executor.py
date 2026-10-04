"""Thin custom agent loop: Plan → Observe → Reason → ToolSequence → Verify → Iterate.

No LangGraph. Budgets and cancellation are first-class stop conditions.
Model/reasoner is injectable; default stubs keep the scaffold runnable without LLMs.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, Optional, Protocol, Sequence

from agent_core.budgets import AgentBudgets
from agent_core.memory import WorkingMemory
from agent_core.planner import Planner
from agent_core.state import (
    AgentState,
    ChangeRecord,
    IterationOutcome,
    TaskStatus,
    ToolCallRecord,
)
from agent_core.verifier import VerificationCriterion, Verifier
from tools.abstract import AbstractGodotTools
from tools.registry import CapabilityRegistry, TOOL_RISK_LEVELS
from tools.schemas import ToolRisk, ToolResult


class Reasoner(Protocol):
    """Produces the next tool-call sequence and optional verification criteria."""

    def observe(self, state: AgentState, memory: WorkingMemory, tools: AbstractGodotTools) -> None: ...

    def reason(
        self,
        state: AgentState,
        memory: WorkingMemory,
        capabilities: CapabilityRegistry,
    ) -> "ReasonerDecision": ...


@dataclass
class PlannedToolCall:
    tool_name: str
    # Callable that invokes the abstract tool (keeps executor free of arg typing).
    invoke: Callable[[AbstractGodotTools], ToolResult]
    is_mutation: bool = False
    is_playtest: bool = False
    args_summary: str = ""


@dataclass
class ReasonerDecision:
    tool_calls: Sequence[PlannedToolCall] = field(default_factory=tuple)
    verification_criteria: Sequence[VerificationCriterion] = field(default_factory=tuple)
    done_claim: bool = False  # reasoner *claims* done; verifier still must pass
    needs_user: bool = False
    message: str = ""


class StubReasoner:
    """No-op reasoner for scaffold/tests — immediately asks for user input."""

    def observe(self, state: AgentState, memory: WorkingMemory, tools: AbstractGodotTools) -> None:
        del tools
        memory.sync_from_state(state)

    def reason(
        self,
        state: AgentState,
        memory: WorkingMemory,
        capabilities: CapabilityRegistry,
    ) -> ReasonerDecision:
        del memory, capabilities
        return ReasonerDecision(
            needs_user=True,
            message=f"StubReasoner: wire an LLM reasoner to pursue goal: {state.goal}",
        )


CancelCheck = Callable[[], bool]


@dataclass
class AgentExecutor:
    """Owns the iteration loop with budgets and cancellation hooks."""

    tools: AbstractGodotTools
    capabilities: CapabilityRegistry
    budgets: AgentBudgets = field(default_factory=AgentBudgets)
    planner: Planner = field(default_factory=Planner)
    verifier: Verifier = field(default_factory=Verifier)
    reasoner: Reasoner = field(default_factory=StubReasoner)
    memory: WorkingMemory = field(default_factory=WorkingMemory)
    cancel_check: Optional[CancelCheck] = None

    def run(self, goal: str, *, project_hints: Sequence[str] = ()) -> AgentState:
        state = AgentState(goal=goal, status=TaskStatus.RUNNING)
        self.memory.goal = goal
        self.planner.create_plan(state, self.capabilities, project_hints=project_hints)

        while True:
            if self._cancelled(state):
                state.status = TaskStatus.CANCELLED
                return state

            if self.budgets.exhausted():
                state.status = TaskStatus.BUDGET_EXHAUSTED
                state.final_summary = f"Stopped: budget exhausted ({self.budgets.exhaustion_reason()})"
                return state

            outcome = self._iterate(state)
            if outcome is IterationOutcome.SUCCESS:
                state.status = TaskStatus.SUCCEEDED
                state.final_summary = state.final_summary or "Task verified successfully."
                return state
            if outcome is IterationOutcome.BLOCKED:
                state.status = TaskStatus.NEEDS_USER
                return state
            if outcome is IterationOutcome.BUDGET:
                state.status = TaskStatus.BUDGET_EXHAUSTED
                return state
            if outcome is IterationOutcome.CANCELLED:
                state.status = TaskStatus.CANCELLED
                return state
            # CONTINUE → next iteration

    def _iterate(self, state: AgentState) -> IterationOutcome:
        state.iteration += 1
        self.budgets.record_iteration()

        if self.memory.needs_compaction():
            self.memory.compact(state=state)

        # OBSERVE
        self.reasoner.observe(state, self.memory, self.tools)
        self.memory.sync_from_state(state)

        if self._cancelled(state):
            return IterationOutcome.CANCELLED

        # REASON
        decision = self.reasoner.reason(state, self.memory, self.capabilities)
        if decision.needs_user:
            state.final_summary = decision.message or "Needs user intervention."
            return IterationOutcome.BLOCKED

        # TOOL SEQUENCE
        for call in decision.tool_calls:
            if self._cancelled(state):
                return IterationOutcome.CANCELLED
            if self.budgets.exhausted():
                state.final_summary = f"Budget exhausted before tool {call.tool_name}"
                return IterationOutcome.BUDGET
            if not self.capabilities.tool_available(call.tool_name):
                state.known_issues.append(f"unsupported_tool:{call.tool_name}")
                continue

            result = call.invoke(self.tools)
            self.budgets.record_tool_call(
                is_mutation=call.is_mutation,
                is_playtest=call.is_playtest,
            )
            state.tool_calls.append(
                ToolCallRecord(
                    iteration=state.iteration,
                    tool_name=call.tool_name,
                    args_summary=call.args_summary or call.tool_name,
                    ok=result.ok,
                    error=result.error,
                    evidence=dict(result.evidence),
                )
            )
            if result.change:
                state.append_change(
                    ChangeRecord(
                        iteration=state.iteration,
                        change_type=str(result.change.get("type", "unknown")),
                        path=str(result.change.get("path", "")),
                        operation=str(result.change.get("operation", "")),
                        details=dict(result.change),
                    )
                )

        # VERIFY — never treat mutation ACKs as success
        criteria: Sequence[VerificationCriterion] = decision.verification_criteria
        if decision.done_claim or criteria:
            record = self.verifier.verify(state, self.tools, criteria)
            self.memory.sync_from_state(state)
            if record.passed and decision.done_claim:
                return IterationOutcome.SUCCESS
            if not record.passed:
                state.known_issues.extend(record.failures)
                state.hypotheses.append(
                    f"iteration_{state.iteration}_verification_failed"
                )

        if self.budgets.exhausted():
            return IterationOutcome.BUDGET
        return IterationOutcome.CONTINUE

    def _cancelled(self, state: AgentState) -> bool:
        if state.cancel_requested:
            return True
        if self.cancel_check is not None and self.cancel_check():
            state.cancel_requested = True
            return True
        return False


def risk_implies_mutation(tool_name: str) -> bool:
    risk = TOOL_RISK_LEVELS.get(tool_name)
    return risk in (ToolRisk.WRITE, ToolRisk.DESTRUCTIVE)


def risk_implies_playtest(tool_name: str) -> bool:
    return tool_name in {"run_game", "playtest_input", "playtest_wait", "stop_game"}
