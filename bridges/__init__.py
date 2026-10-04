"""Pluggable Godot bridges. Agent Core must not import these packages."""

from bridges.base import BridgeAdapter, BridgeInfo

__all__ = ["BridgeAdapter", "BridgeInfo"]
