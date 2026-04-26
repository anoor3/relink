from __future__ import annotations

import os
from typing import Any


OUTREACH_SYSTEM_PROMPT = """You are writing a reconnect email on behalf of the user.
Write a short, warm, genuine email to reconnect with someone they haven't spoken to in a while.
Rules:
- Max 5 sentences
- No \"I hope this email finds you well\"
- Reference something specific and real from their history together
- One clear reason for reaching out (not just \"checking in\")
- One soft question to invite a reply
- Sound like a real person, not a PR email
Return JSON with: { subject: string, body: string }"""


async def generate_outreach_email(profile: dict[str, Any], interactions: list[dict[str, Any]]) -> dict[str, str]:
    if os.getenv("ANTHROPIC_API_KEY"):
        import anthropic  # type: ignore

        client = anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        payload = {"profile": profile, "interactions": interactions}
        msg = await client.messages.create(
            model=os.getenv("RELINK_CLAUDE_MODEL", "claude-sonnet-4-20250514"),
            max_tokens=400,
            system=OUTREACH_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": str(payload)}],
        )
        content = "".join(block.text for block in msg.content if hasattr(block, "text"))
        return _safe_email_json(content)

    if os.getenv("OPENAI_API_KEY"):
        from openai import AsyncOpenAI  # type: ignore

        client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
        payload = {"profile": profile, "interactions": interactions}
        msg = await client.chat.completions.create(
            model=os.getenv("RELINK_OPENAI_AGENT_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": OUTREACH_SYSTEM_PROMPT},
                {"role": "user", "content": str(payload)},
            ],
            response_format={"type": "json_object"},
        )
        content = (msg.choices[0].message.content or "").strip()
        return _safe_email_json(content)

    name = profile.get("name") or "there"
    follow_up = profile.get("follow_up_intent") or "share a quick update"
    return {
        "subject": f"Quick catch-up, {name}",
        "body": f"Hey {name} — been thinking about our last chat. I wanted to follow up to {follow_up}. What’s new on your side?",
    }


def _safe_email_json(text: str) -> dict[str, str]:
    import json

    try:
        data = json.loads(text)
        subject = str(data.get("subject") or "")
        body = str(data.get("body") or "")
        return {"subject": subject, "body": body}
    except Exception:
        return {"subject": "", "body": ""}
