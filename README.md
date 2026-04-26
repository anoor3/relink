# reLink

  A local-first iOS app for “relationship recall”: capture a quick voice memo
  after meeting someone, extract a structured profile, and generate briefs +
  outreach drafts when you need to follow up.

  This repo contains:

  - relink/ — SwiftUI iOS app (local-first, on-device UI + local JSON store)
  - relink/backend/ — optional FastAPI backend scaffold (useful for a server-
  driven version)

  ## What it does

  - Record a short voice memo right after a conversation
  - Transcribe audio with OpenAI Whisper
  - Extract a structured “person profile” (name, company, role, topics, signals,
  etc.)
  - Show:
      - A concise brief before you reach out
      - Nudges (who to follow up with next)
      - Email drafts / outreach plans
  - Optional integrations:
      - AgentMail: send/schedule outreach emails
      - Nia: save/search context semantically (stub/variable response support)

  ## iOS App (SwiftUI)

  ### Requirements

  - Xcode (project currently targets iOS 18.5 in relink.xcodeproj)
  - Microphone access (you’ll be prompted on first record)

  ### Run

  1. Open relink/relink.xcodeproj in Xcode
  2. Select a simulator or device
  3. Press Run

  ### API keys / configuration

  The app reads secrets from either:

  - Xcode Scheme env vars: Product → Scheme → Edit Scheme… → Run → Arguments →
  Environment Variables
  - OR Info.plist keys (if you prefer bundling a dev-only plist locally)

  Required (for transcription + LLM features)

  - OPENAI_API_KEY

  Optional

  - RELINK_OPENAI_AGENT_MODEL (defaults to gpt-4o-mini)
  - AGENTMAIL_API_KEY (enables AgentMail features)
  - NIA_API_KEY (enables Nia context save/search)
  - NIA_BASE_URL (override Nia API base URL)

  ### Local-first storage

  - People + interactions are stored locally as JSON:
      - App Support directory → relink/store.json
  - Demo data is seeded on first launch (via DemoSeeder / RichDemoSeeder).
      - To reset: delete the app from the simulator/device (or clear relevant
  UserDefaults keys).

  ## Backend (FastAPI scaffold) (Optional)

  There’s a backend scaffold in relink/backend/ that mirrors the app’s core
  flows (add person, briefs, nudges, email drafts, etc.).

  - Setup + run instructions live in: relink/backend/README.md
  - Key tip: create the Python venv outside the iOS app folder (to avoid Xcode
  bundling issues).

  ## Repo layout

  - relink/relink/ — iOS app source (SwiftUI)
  - relink/relink/Services/ — OpenAI / AgentMail / Nia clients + app services
  - relink/relink/Audio/ — audio recording
  - relink/relink/Persistence/ — LocalStore JSON persistence
  - relink/backend/ — FastAPI app + sqlite schema + integrations stubs

