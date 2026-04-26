from __future__ import annotations

from typing import Any


class ChromaStore:
    """ChromaDB wrapper.

    Local-first scaffold: we keep this optional so the backend can run
    even before Chroma is configured.
    """

    def __init__(self) -> None:
        self._enabled = False
        self._collection = None

    def enable(self) -> None:
        try:
            import chromadb  # type: ignore

            client = chromadb.Client()
            self._collection = client.get_or_create_collection("persons")
            self._enabled = True
        except Exception:
            self._enabled = False
            self._collection = None

    def upsert_person(self, person_id: str, profile: dict[str, Any]) -> None:
        if not self._enabled or self._collection is None:
            return

        text = "\n".join(
            [
                profile.get("name") or "",
                profile.get("company") or "",
                profile.get("role") or "",
                " ".join(profile.get("topics_discussed") or []),
                " ".join(profile.get("personal_details") or []),
                " ".join(profile.get("signals") or []),
                " ".join(profile.get("tags") or []),
            ]
        ).strip()
        if not text:
            return

        self._collection.upsert(ids=[person_id], documents=[text])

