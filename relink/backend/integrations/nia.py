from __future__ import annotations

import os
from typing import Any


def enabled() -> bool:
    return bool(os.getenv("NIA_API_KEY"))


async def save_person_context(person: dict[str, Any]) -> None:
    """Placeholder for Nozomio (Nia) context store save."""
    if not enabled():
        return
    # TODO: call Nia contexts save (HTTP or CLI).


async def semantic_search(query: str, limit: int = 10) -> list[dict[str, Any]]:
    """Placeholder for Nozomio semantic search."""
    if not enabled():
        return []
    # TODO: call Nia semantic search.
    return []

