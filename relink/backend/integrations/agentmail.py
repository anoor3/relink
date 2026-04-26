from __future__ import annotations

import os
from typing import Any


def enabled() -> bool:
    return bool(os.getenv("AGENTMAIL_API_KEY"))


async def send_message(to_email: str, subject: str, body: str) -> dict[str, Any]:
    """Placeholder for AgentMail send."""
    if not enabled():
        return {"id": "local_stub", "status": "skipped"}
    # TODO: call AgentMail inbox send.
    return {"id": "agentmail_stub", "status": "queued"}

