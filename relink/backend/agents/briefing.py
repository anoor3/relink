from __future__ import annotations

import os


BRIEFING_SYSTEM_PROMPT = """You are a relationship intelligence assistant. You help people reconnect authentically.
Given a person's profile and interaction history, write a brief (max 4 sentences) that:
1. Reminds them of the most important context about this person
2. Notes how long it's been and what may have changed since
3. Suggests the natural angle for reconnecting (not pushy, genuinely human)
4. Flags anything sensitive or important to be aware of
Write in second person (\"They were...\"), present tense reasoning, no bullet points.
Sound like a thoughtful friend, not a corporate assistant."""


async def generate_brief(profile: dict, interactions: list[dict], days_since_contact: int) -> str:
    if os.getenv("ANTHROPIC_API_KEY"):
        import anthropic  # type: ignore

        client = anthropic.AsyncAnthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        payload = {
            "profile": profile,
            "interactions": interactions,
            "days_since_contact": days_since_contact,
        }
        msg = await client.messages.create(
            model=os.getenv("RELINK_CLAUDE_MODEL", "claude-sonnet-4-20250514"),
            max_tokens=250,
            system=BRIEFING_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": str(payload)}],
        )
        return "".join(block.text for block in msg.content if hasattr(block, "text")).strip()

    if os.getenv("OPENAI_API_KEY"):
        from openai import AsyncOpenAI  # type: ignore

        client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
        payload = {
            "profile": profile,
            "interactions": interactions,
            "days_since_contact": days_since_contact,
        }
        msg = await client.chat.completions.create(
            model=os.getenv("RELINK_OPENAI_AGENT_MODEL", "gpt-4o-mini"),
            messages=[
                {"role": "system", "content": BRIEFING_SYSTEM_PROMPT},
                {"role": "user", "content": str(payload)},
            ],
        )
        return (msg.choices[0].message.content or "").strip()

    name = profile.get("name") or "They"
    company = profile.get("company") or ""
    role = profile.get("role") or ""
    angle = profile.get("follow_up_intent") or "send a quick, human check-in"
    return (
        f"{name} is {role} {('at ' + company) if company else ''}. "
        f"It’s been {days_since_contact} days since you last connected. "
        f"A natural reconnect angle is to {angle}."
    ).replace("  ", " ").strip()
