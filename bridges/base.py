"""BridgeAdapter — maps abstract Godot tools onto a concrete MCP/editor backend.

Agent Core only sees ``AbstractGodotTools``. At process startup, the host wires:

    tools: AbstractGodotTools = SomeBridgeAdapter(...)
    capabilities.update_from_bridge(...)
    executor = AgentExecutor(tools=tools, capabilities=capabilities)

Adapters may talk MCP, an EditorPlugin RPC, or anything else — that detail
stays inside ``bridges/``, never inside ``agent_core/``.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Protocol, runtime_checkable

from tools.abstract import AbstractGodotTools
from tools.registry import CapabilityRegistry


@dataclass(frozen=True)
class BridgeInfo:
    bridge_id: str
    display_name: str
    godot_version: str
    capabilities: Mapping[str, bool]


@runtime_checkable
class BridgeAdapter(AbstractGodotTools, Protocol):
    """Concrete bridge: implements every abstract tool + connection lifecycle."""

    def connect(self) -> BridgeInfo:
        """Establish connection to Godot / MCP and return capability report."""
        ...

    def disconnect(self) -> None:
        """Tear down the connection cleanly."""
        ...

    def bridge_info(self) -> BridgeInfo:
        """Last known bridge metadata (after connect)."""
        ...

    def apply_capabilities(self, registry: CapabilityRegistry) -> CapabilityRegistry:
        """Push ``bridge_info()`` into a capability registry."""
        ...
