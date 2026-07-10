# reLink (iOS • Local‑First Relationship Recall)

  reLink is a SwiftUI iOS app that helps you stay on top of important
  relationships. Right after meeting someone, you record a quick voice memo;
  the app transcribes it, extracts a structured profile (who they are, what you
  discussed, follow‑up intent, signals), and later generates a crisp “brief” and
  outreach drafts so you can reconnect naturally.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Abdullah%20Noor-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/abdullah-noor1/)
[![Email](https://img.shields.io/badge/Email-abdullahnoorllc%40gmail.com-EA4335?logo=gmail&logoColor=white)](mailto:abdullahnoorllc@gmail.com)

  This folder (relink/relink/) is the full iOS app implementation (local-first
  by default).

  ## Core Experience

  1. Capture: record a short voice memo after a conversation
  2. Understand:
      - Transcribe the memo (OpenAI Whisper)
      - Extract a clean profile (LLM JSON extraction)
  3. Recall & act:
      - View a brief before you reach out
      - Get nudges (who to follow up with)
      - Generate email drafts and a lightweight outreach plan

  ## What’s “local‑first” here?

  - Your people + interactions are stored locally using LocalStore (JSON on
  disk).
  - The app works end‑to‑end without needing the backend server.
  - External APIs are only used for “intelligence” features (transcription +
  drafting), and optional integrations.

  Local storage location:

  - App Support directory → relink/store.json

  ## Integrations (Optional)

  - OpenAI
      - Whisper transcription (audio/transcriptions)
      - Chat completions for JSON extraction, briefs, and drafting
  - AgentMail (optional)
      - Create/manage inboxes and send/schedule messages (best-effort support in
  the app)
  - Nia (optional)
      - Save/search person context for semantic retrieval

  If you don’t configure AgentMail or Nia, the app still runs; those features
  simply stay inactive.

  ## Setup (Xcode)

  ### Requirements

  - Xcode (this project is currently set to iOS 18.5 in the .xcodeproj)
  - Microphone permission (requested on first use)

  ### Run

  1. Open relink.xcodeproj
  2. Select a device/simulator
  3. Press Run

  ## Configuration / API Keys

  The app reads secrets from either:

  - Xcode Scheme Environment Variables (recommended for local dev), or
  - Info.plist keys (if you prefer, but don’t commit real keys)

  Set these in Xcode:
  Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables

  ### Required (for AI features)

  - OPENAI_API_KEY

  ### Optional

  - RELINK_OPENAI_AGENT_MODEL (defaults to gpt-4o-mini)
  - AGENTMAIL_API_KEY (enables AgentMail features)
  - NIA_API_KEY (enables Nia features)
  - NIA_BASE_URL (override Nia API base URL)

  ## Project Layout (important files)

  - Audio/AudioRecorder.swift
      - Handles mic permission + recording to a temporary .m4a
  - Services/OpenAIClient.swift
      - Whisper transcription + chat completions (text + JSON)
  - Network/APIClient.swift
      - Orchestrates flows: add person from audio, briefs, nudges, drafts
  - Persistence/LocalStore.swift
      - Local JSON persistence for people + interactions
  - Services/AgentMailClient.swift
      - AgentMail inbox/draft/send support
  - Services/NiaClient.swift
      - Context save + semantic search
  - Services/DemoSeeder.swift (+ RichDemoSeeder.swift)
      - Seeds demo people/interactions for a strong first-run experience
  - Views/
      - SwiftUI UI (cards, detail views, brief bubbles, drafting UI)

  ## Demo Mode / Resetting Data

  The app can seed demo contacts on first launch.

  To fully reset:

  - Delete the app from the simulator/device (clears UserDefaults + app storage)
  - Or manually clear the App Support directory and relevant UserDefaults keys

  ## Notes / Troubleshooting


  To fully reset:
  - Delete the app from the simulator/device (clears `UserDefaults` + app
  storage)
  - Or manually clear the App Support directory and relevant `UserDefaults` keys
