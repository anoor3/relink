from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

try:
    from dotenv import load_dotenv  # type: ignore

    load_dotenv()
except Exception:
    pass

from agents.briefing import generate_brief
from agents.extraction import extract_profile
from agents.outreach import generate_outreach_email
from db.chroma import ChromaStore
from db.sqlite import (
    get_interactions,
    get_person,
    get_persons,
    init_db,
    save_interaction,
    save_person,
)
from integrations import agentmail, nia


app = FastAPI(title="reLink API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def _startup() -> None:
    init_db()

    chroma = ChromaStore()
    chroma.enable()
    app.state.chroma = chroma


def _utc_now() -> datetime:
    return datetime.now(tz=timezone.utc)


def _calc_days_since(last_contact_iso: str) -> int:
    try:
        last = datetime.fromisoformat(last_contact_iso.replace("Z", "+00:00"))
    except ValueError:
        return 0
    delta = _utc_now() - last
    return max(0, int(delta.days))


def _person_to_api(person, interactions=None) -> dict[str, Any]:
    payload = {
        "id": person.id,
        "user_id": person.user_id,
        "name": person.name,
        "company": person.company,
        "role": person.role,
        "topics_discussed": person.topics_discussed,
        "personal_details": person.personal_details,
        "signals": person.signals,
        "sentiment": person.sentiment,
        "follow_up_intent": person.follow_up_intent,
        "relationship_strength": person.relationship_strength,
        "tags": person.tags,
        "email": person.email,
        "last_contact": person.last_contact,
        "created_at": person.created_at,
    }
    if interactions is not None:
        payload["interactions"] = [
            {
                "id": i.id,
                "person_id": i.person_id,
                "type": i.type,
                "content": i.content,
                "created_at": i.created_at,
            }
            for i in interactions
        ]
    return payload


async def _transcribe(audio: UploadFile) -> str:
    """Whisper transcription scaffold.

    Local-first fallback returns a dummy transcript so end-to-end works.
    """

    if os.getenv("OPENAI_API_KEY"):
        from tempfile import NamedTemporaryFile

        from openai import AsyncOpenAI  # type: ignore

        client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
        audio_bytes = await audio.read()

        suffix = ".m4a"
        if audio.filename and "." in audio.filename:
            suffix = "." + audio.filename.split(".")[-1]

        with NamedTemporaryFile(suffix=suffix) as tmp:
            tmp.write(audio_bytes)
            tmp.flush()
            tmp.seek(0)

            result = await client.audio.transcriptions.create(
                model=os.getenv("RELINK_WHISPER_MODEL", "whisper-1"),
                file=tmp,
            )
            return (getattr(result, "text", None) or "").strip()

    return "Just met someone — placeholder transcript."


@app.post("/add-person")
async def add_person(audio: UploadFile = File(...), user_id: str = Form(...)):
    try:
        transcript = await _transcribe(audio)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Transcription failed: {exc}") from exc

    if not transcript:
        raise HTTPException(status_code=502, detail="Transcription returned empty text")

    try:
        profile = await extract_profile(transcript)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Profile extraction failed: {exc}") from exc

    if not profile or not isinstance(profile, dict):
        raise HTTPException(status_code=502, detail="Profile extraction returned invalid JSON")

    person = save_person(profile, user_id=user_id)
    interaction = save_interaction(person.id, type="voice_memo", content=transcript)

    app.state.chroma.upsert_person(person.id, profile)
    try:
        await nia.save_person_context({**profile, "id": person.id, "user_id": user_id})
    except Exception:
        # Keep local-first flow working even if Nia fails.
        pass

    interactions = get_interactions(person.id)
    return _person_to_api(get_person(person.id), interactions=interactions)


@app.get("/persons/{user_id}")
async def list_persons(user_id: str):
    persons = get_persons(user_id)
    return [_person_to_api(p) for p in persons]


@app.get("/person/{person_id}")
async def get_person_detail(person_id: str):
    person = get_person(person_id)
    interactions = get_interactions(person_id)
    return _person_to_api(person, interactions=interactions)


class BriefResponse(BaseModel):
    brief: str


@app.get("/brief/{person_id}", response_model=BriefResponse)
async def brief(person_id: str):
    person = get_person(person_id)
    interactions = get_interactions(person_id)
    days = _calc_days_since(person.last_contact)

    brief_text = await generate_brief(
        profile=_person_to_api(person),
        interactions=[i.__dict__ for i in interactions],
        days_since_contact=days,
    )
    return BriefResponse(brief=brief_text)


def _score_person(person) -> int:
    days = _calc_days_since(person.last_contact)
    base_score = int(min(100, (days / 30) * 100))
    signal_boost = len(person.signals) * 10
    importance_boost = int(person.relationship_strength) * 5
    return min(base_score + signal_boost + importance_boost, 100)


@app.get("/nudges/{user_id}")
async def nudges(user_id: str):
    persons = get_persons(user_id)
    scored = sorted(((p, _score_person(p)) for p in persons), key=lambda x: x[1], reverse=True)
    top = scored[:3]

    nudges_payload = []
    for person, score in top:
        reason = "It’s been a while — a quick, human reach-out would keep this relationship warm."
        nudges_payload.append(
            {
                "person": _person_to_api(person),
                "score": int(score),
                "reason": reason,
            }
        )
    return {"nudges": nudges_payload}


class DraftEmailResponse(BaseModel):
    draft: dict[str, str]


@app.post("/draft-email/{person_id}", response_model=DraftEmailResponse)
async def draft_email(person_id: str):
    person = get_person(person_id)
    interactions = get_interactions(person_id)
    draft = await generate_outreach_email(
        profile=_person_to_api(person),
        interactions=[i.__dict__ for i in interactions],
    )
    return DraftEmailResponse(draft=draft)


class SendEmailRequest(BaseModel):
    person_id: str
    to_email: str
    subject: str
    body: str


@app.post("/send-email")
async def send_email(payload: SendEmailRequest):
    result = await agentmail.send_message(payload.to_email, payload.subject, payload.body)
    save_interaction(payload.person_id, type="email_sent", content=f"Subject: {payload.subject}")
    return {"status": "sent", "message_id": result.get("id")}


@app.get("/search/{user_id}")
async def search(user_id: str, q: str):
    # Placeholder: for local-first MVP we just do a naive filter in SQLite.
    persons = get_persons(user_id)
    needle = q.lower()
    matches = [
        p
        for p in persons
        if needle in p.name.lower()
        or needle in (p.company or "").lower()
        or needle in (p.role or "").lower()
    ]

    # Future: merge with Nia semantic search.
    _ = await nia.semantic_search(q)
    return {"results": [_person_to_api(p) for p in matches]}


@app.post("/email-reply")
async def email_reply_webhook(payload: dict[str, Any]):
    # Placeholder for AgentMail webhook handling.
    # Future: map `from` email -> person and save as interaction.
    _ = payload
    return {"status": "ok"}
