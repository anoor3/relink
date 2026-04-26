# reLink backend (FastAPI)

Local-first scaffold matching `RECALL_MASTER_PLAN.md`.

## Run (dev)

```bash
cd backend

# Create local env file (do not commit it)
cp .env.example .env

# IMPORTANT: don't create a virtualenv inside the iOS app folder
# (Xcode can try to bundle it and you'll get "Multiple commands produce .keep" errors).
# Create the venv outside the project directory instead.
python3 -m venv ../.relink-backend-venv
source ../.relink-backend-venv/bin/activate
pip install -r requirements.txt

# Use --host 0.0.0.0 so your iPhone can reach it
python3 -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Env vars

- `RELINK_DB_PATH` (optional) — path to sqlite file
- `OPENAI_API_KEY` (optional) — for Whisper transcription
- `ANTHROPIC_API_KEY` (optional) — for Claude agents
- `NIA_API_KEY` (optional) — enable Nozomio integration (stubbed)
- `AGENTMAIL_API_KEY` (optional) — enable AgentMail integration (stubbed)
