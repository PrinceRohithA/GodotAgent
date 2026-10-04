"""Task and iteration state for the agent loop."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, List, Mapping, Optional, Sequence


class TaskStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    NEEDS_USER = "needs_user"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"
    BUDGET_EXHAUSTED = "budget_exhausted"


class IterationOutcome(str, Enum):
    CONTINUE = "continue"
    SUCCESS = "success"
    BLOCKED = "blocked"
    BUDGET = "budget"
    CANCELLED = "cancelled"


@dataclass
class PlanStep:
    index: int
    description: str
    done: bool = False
    notes: str = ""


@dataclass
class ChangeRecord:
    iteration: int
    change_type: str  # script | node | property | setting | animation | ...
    path: str
    operation: str
    details: Mapping[str, Any] = field(default_factory=dict)


@dataclass
class ToolCallRecord:
    iteration: int
    tool_name: str
    args_summary: str
    ok: bool
    error: Optional[str] = None
    evidence: Mapping[str, Any] = field(default_factory=dict)


@dataclass
class VerificationRecord:
    iteration: int
    passed: bool
    criteria: Sequence[str] = field(default_factory=tuple)
    evidence: Mapping[str, Any] = field(default_factory=dict)
    failures: Sequence[str] = field(default_factory=tuple)
    requires_runtime: bool = False


@dataclass
class AgentState:
    """Mutable lifecycle state for one user task."""

    goal: str
    status: TaskStatus = TaskStatus.PENDING
    iteration: int = 0
    plan: List[PlanStep] = field(default_factory=list)
    hypotheses: List[str] = field(default_factory=list)
    known_issues: List[str] = field(default_factory=list)
    recent_changes: List[ChangeRecord] = field(default_factory=list)
    tool_calls: List[ToolCallRecord] = field(default_factory=list)
    verifications: List[VerificationRecord] = field(default_factory=list)
    next_action: str = ""
    final_summary: str = ""
    cancel_requested: bool = False
    # Opaque hooks for a future model provider (not wired yet).
    extras: Mapping[str, Any] = field(default_factory=dict)

    def request_cancel(self) -> None:
        self.cancel_requested = True

    def append_change(self, record: ChangeRecord) -> None:
        self.recent_changes.append(record)

    def last_verification(self) -> Optional[VerificationRecord]:
        return self.verifications[-1] if self.verifications else None
