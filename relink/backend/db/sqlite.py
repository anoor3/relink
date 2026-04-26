from __future__ import annotations

import json
import os
import sqlite3
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional


def utc_now_iso() -> str:
    return datetime.now(tz=timezone.utc).replace(microsecond=0).isoformat()


@dataclass(frozen=True)
class PersonRecord:
    id: str
    user_id: str
    name: str
    company: Optional[str]
    role: Optional[str]
    topics_discussed: list[str]
    personal_details: list[str]
    signals: list[str]
    tags: list[str]
    sentiment: Optional[str]
    follow_up_intent: Optional[str]
    relationship_strength: int
    email: Optional[str]
    last_contact: str
    created_at: str


@dataclass(frozen=True)
class InteractionRecord:
    id: str
    person_id: str
    type: str
    content: str
    created_at: str


def _db_path() -> Path:
    configured = os.getenv("RELINK_DB_PATH")
    if configured:
        return Path(configured)
    return Path(__file__).resolve().parent.parent / "relink.sqlite"


def get_conn() -> sqlite3.Connection:
    path = _db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db(schema_path: Path | None = None) -> None:
    if schema_path is None:
        schema_path = Path(__file__).resolve().parents[1] / "schema.sql"

    with get_conn() as conn:
        conn.executescript(schema_path.read_text(encoding="utf-8"))


def _json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def _json_loads(value: str | None) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
        if isinstance(data, list):
            return [str(item) for item in data]
    except json.JSONDecodeError:
        pass
    return []


def save_person(profile: dict[str, Any], user_id: str) -> PersonRecord:
    person_id = profile.get("id") or f"p_{uuid.uuid4().hex}"
    created_at = profile.get("created_at") or utc_now_iso()
    last_contact = profile.get("last_contact") or utc_now_iso()

    row = {
        "id": person_id,
        "user_id": user_id,
        "name": profile.get("name") or "Unknown",
        "company": profile.get("company"),
        "role": profile.get("role"),
        "topics": _json_dumps(profile.get("topics_discussed") or []),
        "personal_details": _json_dumps(profile.get("personal_details") or []),
        "signals": _json_dumps(profile.get("signals") or []),
        "tags": _json_dumps(profile.get("tags") or []),
        "sentiment": profile.get("sentiment"),
        "follow_up_intent": profile.get("follow_up_intent"),
        "relationship_strength": int(profile.get("relationship_strength") or 5),
        "email": profile.get("email"),
        "last_contact": last_contact,
        "created_at": created_at,
    }

    with get_conn() as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO persons (
                id, user_id, name, company, role,
                topics, personal_details, signals, tags,
                sentiment, follow_up_intent, relationship_strength,
                email, last_contact, created_at
            ) VALUES (
                :id, :user_id, :name, :company, :role,
                :topics, :personal_details, :signals, :tags,
                :sentiment, :follow_up_intent, :relationship_strength,
                :email, :last_contact, :created_at
            )
            """,
            row,
        )

    return get_person(person_id)


def get_person(person_id: str) -> PersonRecord:
    with get_conn() as conn:
        cur = conn.execute("SELECT * FROM persons WHERE id = ?", (person_id,))
        record = cur.fetchone()
        if record is None:
            raise KeyError(f"person not found: {person_id}")
        return _row_to_person(record)


def get_persons(user_id: str) -> list[PersonRecord]:
    with get_conn() as conn:
        cur = conn.execute(
            "SELECT * FROM persons WHERE user_id = ? ORDER BY last_contact DESC",
            (user_id,),
        )
        return [_row_to_person(row) for row in cur.fetchall()]


def get_person_by_email(email: str) -> Optional[PersonRecord]:
    with get_conn() as conn:
        cur = conn.execute("SELECT * FROM persons WHERE email = ?", (email,))
        row = cur.fetchone()
        return _row_to_person(row) if row else None


def save_interaction(person_id: str, type: str, content: str) -> InteractionRecord:
    interaction_id = f"i_{uuid.uuid4().hex}"
    created_at = utc_now_iso()
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO interactions (id, person_id, type, content, created_at) VALUES (?, ?, ?, ?, ?)",
            (interaction_id, person_id, type, content, created_at),
        )
        conn.execute("UPDATE persons SET last_contact = ? WHERE id = ?", (created_at, person_id))

    return InteractionRecord(
        id=interaction_id,
        person_id=person_id,
        type=type,
        content=content,
        created_at=created_at,
    )


def get_interactions(person_id: str) -> list[InteractionRecord]:
    with get_conn() as conn:
        cur = conn.execute(
            "SELECT * FROM interactions WHERE person_id = ? ORDER BY created_at DESC",
            (person_id,),
        )
        return [
            InteractionRecord(
                id=row["id"],
                person_id=row["person_id"],
                type=row["type"],
                content=row["content"],
                created_at=row["created_at"],
            )
            for row in cur.fetchall()
        ]


def _row_to_person(row: sqlite3.Row) -> PersonRecord:
    return PersonRecord(
        id=row["id"],
        user_id=row["user_id"],
        name=row["name"],
        company=row["company"],
        role=row["role"],
        topics_discussed=_json_loads(row["topics"]),
        personal_details=_json_loads(row["personal_details"]),
        signals=_json_loads(row["signals"]),
        tags=_json_loads(row["tags"]),
        sentiment=row["sentiment"],
        follow_up_intent=row["follow_up_intent"],
        relationship_strength=int(row["relationship_strength"] or 5),
        email=row["email"],
        last_contact=row["last_contact"],
        created_at=row["created_at"],
    )

