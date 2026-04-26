from __future__ import annotations

import os
from typing import Any


EXTRACTION_SYSTEM_PROMPT = """You are an expert at extracting structured relationship data from casual speech.
You receive a raw voice memo transcript about a person the user just met.
Extract all meaningful information and return ONLY valid JSON with these fields:
- name (string)
- company (string or null)
- role (string or null)
- topics_discussed (array of strings)
- personal_details (array of strings — anything personal: kids, hobbies, life events)
- signals (array of strings — anything that implies a future action or emotional state)
- sentiment (string: \"warm\", \"neutral\", \"cold\")
- follow_up_intent (string — what would be natural to follow up on)
- relationship_strength (integer 1-10 — how well they got on)
- tags (array of short keyword strings)
Return ONLY the JSON object. No explanation. No preamble."""


async def extract_profile(transcript: str) -> dict[str, Any]:
    """Agent 1 — Extraction Agent.

    Scaffold behavior:
    - If `ANTHROPIC_API_KEY` is set, we call Claude via anthropic.
    - Otherwise we return a minimal profile so the local pipeline works.
    """

    if os.getenv("ANTHROPIC_API_KEY"):
        import anthropic  # type: ignore

        client = anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        msg = await client.messages.create(
            model=os.getenv("RELINK_CLAUDE_MODEL", "claude-sonnet-4-20250514"),
            max_tokens=800,
            system=EXTRACTION_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": transcript}],
        )
        content = "".join(block.text for block in msg.content if hasattr(block, "text"))
        return _safe_json(content)

    if os.getenv("OPENAI_API_KEY"):
        from openai import AsyncOpenAI  # type: ignore

        client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
        msg = await client.chat.completions.create(
            model=os.getenv("RELINK_OPENAI_AGENT_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": EXTRACTION_SYSTEM_PROMPT},
                {"role": "user", "content": transcript},
            ],
            response_format={"type": "json_object"},
        )
        content = (msg.choices[0].message.content or "").strip()
        return _safe_json(content)

    # Local-first fallback
    return {
        "name": "Unknown",
        "company": None,
        "role": None,
        "topics_discussed": [],
        "personal_details": [],
        "signals": [],
        "sentiment": "neutral",
        "follow_up_intent": "",
        "relationship_strength": 5,
        "tags": [],
    }


def _safe_json(text: str) -> dict[str, Any]:
    import json

    try:
        data = json.loads(text)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}
