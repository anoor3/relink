# RECALL — Complete Hackathon Master Plan
### The AI-Powered Relationship Memory Agent · iOS App

---

> **One line:** Recall is an iOS app with an AI agent that remembers everyone you meet, briefs you before you reconnect, and proactively tells you who needs your attention — powered by Nozomio (Nia) for intelligent search and AgentMail for autonomous outreach.

---

## TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [The Problem We're Solving](#2-the-problem-were-solving)
3. [Full Feature List](#3-full-feature-list)
4. [System Architecture](#4-system-architecture)
5. [The Three AI Agents](#5-the-three-ai-agents)
6. [Complete Data Pipeline](#6-complete-data-pipeline)
7. [Nozomio (Nia) Integration](#7-nozomio-nia-integration)
8. [AgentMail Integration](#8-agentmail-integration)
9. [Backend — FastAPI](#9-backend--fastapi)
10. [iOS App — SwiftUI](#10-ios-app--swiftui)
11. [Database Schema](#11-database-schema)
12. [All API Endpoints](#12-all-api-endpoints)
13. [Full Tech Stack](#13-full-tech-stack)
14. [File & Folder Structure](#14-file--folder-structure)
15. [Hackathon Build Order](#15-hackathon-build-order)
16. [Demo Script](#16-demo-script)
17. [What Judges Will See](#17-what-judges-will-see)

---

## 1. Project Overview

**Recall** is an iOS application that gives every person an AI-powered relationship memory. You meet someone, voice-memo 60 seconds about them, and the app does the rest — it builds their profile, monitors for re-engagement signals, briefs you before you reach out, and when the time is right, drafts and sends emails through AgentMail autonomously.

The core insight: the best networkers in the world do this manually in spreadsheets and sticky notes. Nobody has built the agent-native version of it — one that is proactive, semantic, and actually takes action on your behalf.

**This is not a contacts app. This is not a CRM. This is a relationship agent.**

---

## 2. The Problem We're Solving

You meet 200+ people a year. You remember 12 of them properly. The other 188 fade because:

- Human memory degrades fast, especially names + context
- No tool exists that captures *how* you know someone, not just *that* you know them
- Existing CRMs are built for sales pipelines, not human relationships
- Nothing proactively tells you who needs attention before it's too late
- Following up always requires you to initiate — the tool never comes to you

The result: valuable relationships decay. Introductions don't get made. Opportunities disappear. People who needed a check-in never got one.

**Recall fixes this by making the agent do the remembering, the monitoring, and the reaching out.**

---

## 3. Full Feature List

### Core Features (MVP — build at hackathon)

- **Voice memo capture** — hold to record, release to process; AVFoundation on iOS
- **Extraction agent** — Claude parses transcript into structured profile JSON
- **Person card** — name, company, role, topics, personal details, signals, tags
- **Briefing agent** — on-demand AI brief before any reconnection
- **Nudge system** — home screen surfaces who needs attention and why
- **Interaction history** — every memo logged, searchable, timestamped

### Nozomio-Powered Features

- **Semantic search across your network** — "who do I know in fintech going through a tough time?"
- **Research enrichment** — Nia's Oracle agent pulls public context on people you've met
- **Context sharing between agents** — persistent memory across sessions using Nia's context store
- **Document/source indexing** — index business cards, LinkedIn PDFs, meeting notes

### AgentMail-Powered Features

- **Agent inbox** — Recall's agent gets its own email address (`recall-agent@agentmail.to`)
- **Autonomous outreach drafting** — agent drafts personalized reconnect emails, you approve with one tap
- **Send on your behalf** — approved emails go out from the agent's inbox
- **Reply monitoring** — agent watches for replies and notifies you via webhook
- **Thread-aware follow-ups** — if no reply in 5 days, agent drafts a gentle follow-up

---

## 4. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS APP (SwiftUI)                        │
│  HomeView  │  RecordView  │  PeopleView  │  PersonCardView      │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTPS (JSON + multipart audio)
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND (Python)                     │
│                                                                 │
│   /add-person   /brief   /nudges   /search   /approve-email    │
└──────┬──────────────┬──────────────────┬───────────────────────┘
       │              │                  │
       ▼              ▼                  ▼
┌──────────┐  ┌──────────────┐  ┌──────────────────────────────┐
│  OPENAI  │  │   CLAUDE     │  │         STORAGE              │
│  WHISPER │  │  API         │  │  SQLite (profiles)           │
│(transcribe│  │(3 agents)   │  │  ChromaDB (embeddings)       │
└──────────┘  └──────┬───────┘  └──────────────────────────────┘
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
┌───────────┐  ┌──────────┐  ┌──────────────┐
│ NOZOMIO   │  │AGENTMAIL │  │   NUDGE      │
│   NIA     │  │  API     │  │   ENGINE     │
│           │  │          │  │              │
│• Semantic │  │• Inbox   │  │• Scores all  │
│  search   │  │  mgmt    │  │  relationships│
│• Oracle   │  │• Send    │  │• Surfaces top│
│  research │  │  emails  │  │  3 each day  │
│• Context  │  │• Monitor │  │              │
│  store    │  │  replies │  │              │
└───────────┘  └──────────┘  └──────────────┘
```

---

## 5. The Three AI Agents

### Agent 1 — Extraction Agent

**What it does:** Receives raw voice memo transcript and converts it into a structured, rich person profile. This is not simple parsing — it makes judgment calls about what's important, infers signals, and scores relationship warmth.

**Trigger:** Every time you add a new person or log a new interaction.

**System prompt:**
```
You are an expert at extracting structured relationship data from casual speech.
You receive a raw voice memo transcript about a person the user just met.
Extract all meaningful information and return ONLY valid JSON with these fields:
- name (string)
- company (string or null)
- role (string or null)
- topics_discussed (array of strings)
- personal_details (array of strings — anything personal: kids, hobbies, life events)
- signals (array of strings — anything that implies a future action or emotional state)
- sentiment (string: "warm", "neutral", "cold")
- follow_up_intent (string — what would be natural to follow up on)
- relationship_strength (integer 1-10 — how well they got on)
- tags (array of short keyword strings)
Return ONLY the JSON object. No explanation. No preamble.
```

**Input:** Raw transcript string
**Output:** Structured JSON person profile
**Model:** Claude claude-sonnet-4-20250514

---

### Agent 2 — Briefing Agent

**What it does:** When a user requests a brief on someone before reaching out, this agent synthesizes everything known about the person — their profile, interaction history, days since contact, relationship signals — into a concise, actionable brief that sounds like a smart friend catching you up.

**Trigger:** User taps "Brief me" on a person card.

**System prompt:**
```
You are a relationship intelligence assistant. You help people reconnect authentically.
Given a person's profile and interaction history, write a brief (max 4 sentences) that:
1. Reminds them of the most important context about this person
2. Notes how long it's been and what may have changed since
3. Suggests the natural angle for reconnecting (not pushy, genuinely human)
4. Flags anything sensitive or important to be aware of
Write in second person ("They were..."), present tense reasoning, no bullet points.
Sound like a thoughtful friend, not a corporate assistant.
```

**Input:** Full person profile + interaction history array + days_since_contact integer
**Output:** Plain text brief (3-4 sentences)
**Model:** Claude claude-sonnet-4-20250514

---

### Agent 3 — Outreach Agent (powered by AgentMail)

**What it does:** When the nudge system surfaces someone to reach out to, or when you tap "Draft email," this agent writes a personalized reconnect email. It uses the person's profile, interaction history, and current context to write something that sounds genuinely human. The draft goes to you for one-tap approval, then AgentMail sends it.

**Trigger:** User taps "Draft reconnect email" on a person card, or approves a nudge-suggested outreach.

**System prompt:**
```
You are writing a reconnect email on behalf of the user.
Write a short, warm, genuine email to reconnect with someone they haven't spoken to in a while.
Rules:
- Max 5 sentences
- No "I hope this email finds you well"
- Reference something specific and real from their history together
- One clear reason for reaching out (not just "checking in")
- One soft question to invite a reply
- Sound like a real person, not a PR email
Return JSON with: { subject: string, body: string }
```

**Input:** Person profile + interaction history + suggested_reason string
**Output:** `{ subject, body }` JSON
**Model:** Claude claude-sonnet-4-20250514

---

## 6. Complete Data Pipeline

### Pipeline A — Adding a New Person

```
Step 1: CAPTURE
  iOS records audio via AVFoundation
  Audio saved as .m4a locally
  
Step 2: UPLOAD  
  SwiftUI sends multipart/form-data POST to /add-person
  Payload: { audio_file, user_id }

Step 3: TRANSCRIBE
  Backend receives audio
  Sends to OpenAI Whisper API
  Returns raw transcript string

Step 4: EXTRACT (Agent 1)
  Transcript sent to Claude with extraction system prompt
  Claude returns structured JSON profile
  
Step 5: STORE
  Profile saved to SQLite (persons table)
  Interaction saved to SQLite (interactions table)
  Profile text embedded → ChromaDB vector store
  
Step 6: NIA CONTEXT SAVE
  Profile summary sent to Nia context store:
    nia contexts save "{name}" \
      --summary "{role} at {company}" \
      --content "{full profile JSON}" \
      --memory-type episodic
  
Step 7: RESPOND
  Backend returns full person profile JSON to iOS
  iOS displays new person card with animation
```

---

### Pipeline B — Briefing Before Reconnect

```
Step 1: REQUEST
  User taps "Brief me" on PersonCardView
  iOS sends GET /brief/{person_id}

Step 2: FETCH CONTEXT
  Backend loads person profile from SQLite
  Loads all interactions for that person
  Calculates days_since_last_contact

Step 3: NIA SEMANTIC SEARCH (optional enrichment)
  nia search query "recent updates {name} {company}"
  Appends any relevant public context found
  
Step 4: BRIEF (Agent 2)
  All context sent to Claude with briefing system prompt
  Claude returns 3-4 sentence brief

Step 5: RESPOND
  Brief returned to iOS
  Displayed in purple brief bubble on person card
```

---

### Pipeline C — Nudge Generation

```
Step 1: TRIGGER
  Runs every time app is opened (HomeView onAppear)
  
Step 2: SCORE ALL RELATIONSHIPS
  Backend loads all persons from SQLite
  For each person, calculates nudge score:
  
    base_score = days_since_contact / 30 (0-100)
    signal_boost = count(signals) * 10
    importance_boost = relationship_strength * 5
    final_score = min(base_score + signal_boost + importance_boost, 100)

Step 3: AGENT REASONING
  Top 5 scoring persons sent to Claude:
  "Given these people and their scores, pick the 3 most important
   to reconnect with and write one sentence explaining why NOW."
  
Step 4: RESPOND
  Returns array of { person, score, reason } to iOS
  HomeView displays nudge cards
```

---

### Pipeline D — Autonomous Email Outreach (AgentMail)

```
Step 1: DRAFT REQUEST
  User taps "Draft email" or approves nudge suggestion
  iOS sends POST /draft-email/{person_id}

Step 2: OUTREACH AGENT (Agent 3)
  Backend calls Claude with person profile + outreach system prompt
  Claude returns { subject, body } JSON

Step 3: DISPLAY DRAFT
  Draft returned to iOS
  User sees full email draft — subject + body
  Two buttons: "Approve & Send" or "Edit"

Step 4: APPROVE
  User taps "Approve & Send"
  iOS sends POST /send-email

Step 5: AGENTMAIL SEND
  Backend calls AgentMail API:
    POST https://api.agentmail.to/v0/inboxes/{inbox_id}/messages
    {
      "to": [person_email],
      "subject": draft.subject,
      "body": draft.body,
      "from_name": "Your Name via Recall"
    }

Step 6: MONITOR REPLIES
  AgentMail webhook fires when reply arrives
  Backend receives webhook at POST /email-reply
  Extracts reply content
  Logs as new interaction for that person
  Sends push notification to iOS: "James replied to your email"

Step 7: FOLLOW-UP (autonomous)
  If no reply in 5 days:
  Agent drafts gentle follow-up
  Sends push notification: "No reply from James yet — want to follow up?"
```

---

## 7. Nozomio (Nia) Integration

Nozomio's Nia platform is used in **three key ways** in Recall:

---

### 7.1 — Semantic Search Across Your Network

**What it enables:** The search bar on the People screen isn't just name search. It's semantic. You type "who do I know building AI at a startup who seemed stressed" and Nia finds them.

**How it works:**

When a person profile is created, it gets stored in Nia's context store with a rich summary. When the user searches, we use Nia's semantic search API:

```python
# Backend: search.py

import subprocess
import json

def semantic_search(query: str) -> list:
    result = subprocess.run([
        "nia", "contexts", "semantic", query,
        "--output", "json"
    ], capture_output=True, text=True)
    
    contexts = json.loads(result.stdout)
    return contexts  # Returns matching person profiles
```

Or via Nia's HTTP API directly:
```python
import httpx

async def nia_search(query: str, api_key: str):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.trynia.ai/v1/contexts/semantic",
            headers={"Authorization": f"Bearer {api_key}"},
            json={"query": query, "limit": 10}
        )
    return response.json()
```

---

### 7.2 — Oracle Research Enrichment

**What it enables:** When you add someone from a notable company, Nia's Oracle agent can autonomously research them — pull their LinkedIn activity, recent GitHub commits, blog posts, public news — and append enriched context to their profile.

**How it works:**
```python
async def enrich_person_profile(name: str, company: str, api_key: str):
    # Start Oracle research job
    async with httpx.AsyncClient() as client:
        job = await client.post(
            "https://api.trynia.ai/v1/oracle/jobs",
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "query": f"Who is {name} at {company}? Recent work, interests, public activity.",
                "sources": ["web", "github", "linkedin"]
            }
        )
        job_id = job.json()["id"]
        
        # Poll for completion (or use streaming)
        while True:
            status = await client.get(
                f"https://api.trynia.ai/v1/oracle/jobs/{job_id}",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if status.json()["status"] == "complete":
                return status.json()["result"]
            await asyncio.sleep(2)
```

This runs asynchronously after profile creation. When complete, the enriched context is appended to the person's profile and stored in Nia.

---

### 7.3 — Cross-Session Context Memory

**What it enables:** The agents remember context across sessions. If you added a note about James 3 months ago, the briefing agent knows about it. Nia's context store provides persistent episodic memory so Claude doesn't need to query the full database every time.

**How it works:**
```python
# Save context when person is added
def save_to_nia(person: dict, api_key: str):
    subprocess.run([
        "nia", "contexts", "save", person["name"],
        "--summary", f"{person['role']} at {person['company']}",
        "--content", json.dumps(person),
        "--memory-type", "episodic",
        "--api-key", api_key
    ])

# Retrieve context for briefing agent
def get_nia_context(person_name: str, api_key: str):
    result = subprocess.run([
        "nia", "contexts", "semantic", person_name,
        "--api-key", api_key,
        "--output", "json"
    ], capture_output=True, text=True)
    return json.loads(result.stdout)
```

**Setup at hackathon start:**
```bash
# Install Nia CLI
npx nia-wizard@latest

# Authenticate
nia auth login --api-key "YOUR_NIA_KEY"

# Verify
nia auth status
```

---

## 8. AgentMail Integration

AgentMail gives Recall's AI agent its **own email identity**. The agent isn't sending from your personal email — it has its own inbox (`recall-agent@yourdomain.agentmail.to`), manages threads, and monitors replies.

---

### 8.1 — Setup: Create Agent Inbox

```python
# Run once at startup
import httpx

async def create_agent_inbox(api_key: str):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.agentmail.to/v0/inboxes",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "username": "recall-agent",
                "display_name": "Recall Agent"
            }
        )
    inbox = response.json()
    # Save inbox_id to config
    return inbox["id"]  # e.g. "recall-agent@agentmail.to"
```

---

### 8.2 — Send Email on User's Behalf

```python
async def send_reconnect_email(
    inbox_id: str,
    to_email: str,
    subject: str,
    body: str,
    api_key: str
):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"https://api.agentmail.to/v0/inboxes/{inbox_id}/messages",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "to": [{"email": to_email}],
                "subject": subject,
                "text": body,
            }
        )
    return response.json()
```

---

### 8.3 — Webhook: Catch Replies

When someone replies to the agent's email, AgentMail fires a webhook to your backend. This is what makes outreach feel autonomous — you don't have to check. The agent tells you.

```python
# FastAPI webhook endpoint
from fastapi import FastAPI, Request

app = FastAPI()

@app.post("/email-reply")
async def handle_reply(request: Request):
    payload = await request.json()
    
    # Extract reply content
    thread_id = payload["thread_id"]
    from_email = payload["from"]["email"]
    reply_body = payload["text"]
    
    # Find which person this is
    person = db.get_person_by_email(from_email)
    
    if person:
        # Log as new interaction
        db.add_interaction(person["id"], {
            "type": "email_reply",
            "content": f"Replied to your email: {reply_body[:200]}",
            "timestamp": datetime.now().isoformat()
        })
        
        # Send push notification to iOS
        await send_push_notification(
            person["user_id"],
            f"{person['name']} replied to your email"
        )
    
    return {"status": "ok"}
```

**Register webhook in AgentMail dashboard:**
```
Webhook URL: https://your-backend.railway.app/email-reply
Events: message.received
```

---

### 8.4 — List Threads (Reply Monitoring)

```python
async def check_for_replies(inbox_id: str, api_key: str):
    async with httpx.AsyncClient() as client:
        threads = await client.get(
            f"https://api.agentmail.to/v0/inboxes/{inbox_id}/threads",
            headers={"Authorization": f"Bearer {api_key}"}
        )
    
    for thread in threads.json()["threads"]:
        if thread["reply_count"] > 1:  # Has replies
            # Process new replies
            messages = await get_thread_messages(inbox_id, thread["id"], api_key)
            # ... log to interactions
```

---

## 9. Backend — FastAPI

### Setup

```bash
# requirements.txt
fastapi
uvicorn
openai          # Whisper transcription
anthropic       # Claude agents
httpx           # AgentMail + Nia HTTP calls
python-multipart # Audio file upload
sqlite3         # Profiles DB (built-in)
chromadb        # Vector embeddings
python-dotenv   # Env vars
apscheduler     # Nudge cron job
```

```python
# main.py — full server skeleton

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
import anthropic
import openai
import httpx
import sqlite3
import chromadb
import json
from datetime import datetime, timedelta

app = FastAPI()

# CORS for iOS simulator
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"])

# Clients
claude = anthropic.Anthropic(api_key=ANTHROPIC_KEY)
chroma = chromadb.Client()
collection = chroma.get_or_create_collection("persons")

# ─── ENDPOINTS ────────────────────────────────────────────────

@app.post("/add-person")
async def add_person(audio: UploadFile = File(...), user_id: str = Form(...)):
    # 1. Transcribe
    transcript = await transcribe(audio)
    # 2. Extract profile
    profile = await extract_profile(transcript)
    # 3. Store
    person_id = db_save_person(profile, user_id)
    db_save_interaction(person_id, transcript)
    embed_person(person_id, profile)
    # 4. Save to Nia
    save_to_nia(profile)
    return {"person_id": person_id, "profile": profile}

@app.get("/brief/{person_id}")
async def get_brief(person_id: str):
    profile = db_get_person(person_id)
    interactions = db_get_interactions(person_id)
    days = calc_days_since(profile["last_contact"])
    brief = await generate_brief(profile, interactions, days)
    return {"brief": brief}

@app.get("/nudges/{user_id}")
async def get_nudges(user_id: str):
    persons = db_get_all_persons(user_id)
    scored = score_relationships(persons)
    nudges = await agent_pick_top_nudges(scored[:5])
    return {"nudges": nudges}

@app.post("/draft-email/{person_id}")
async def draft_email(person_id: str):
    profile = db_get_person(person_id)
    interactions = db_get_interactions(person_id)
    draft = await generate_outreach_email(profile, interactions)
    return {"draft": draft}

@app.post("/send-email")
async def send_email(person_id: str, to_email: str, subject: str, body: str):
    result = await agentmail_send(to_email, subject, body)
    db_log_email_sent(person_id, subject)
    return {"status": "sent", "message_id": result["id"]}

@app.post("/email-reply")
async def email_reply_webhook(request: Request):
    # Handle AgentMail webhook
    payload = await request.json()
    # ... (see section 8.3)
    return {"status": "ok"}

@app.get("/search/{user_id}")
async def search_persons(user_id: str, q: str):
    # Semantic search via Nia + ChromaDB
    results = await semantic_search(q, user_id)
    return {"results": results}
```

---

## 10. iOS App — SwiftUI

### File Structure

```
Recall/
├── RecallApp.swift              # App entry point
├── Network/
│   └── APIClient.swift          # All backend calls
├── Models/
│   ├── Person.swift             # Person data model
│   └── Interaction.swift        # Interaction model
├── Views/
│   ├── HomeView.swift           # Nudges + recents
│   ├── RecordView.swift         # Voice memo capture
│   ├── PeopleView.swift         # Contacts list
│   ├── PersonCardView.swift     # Profile + brief + email
│   └── Components/
│       ├── NudgeCard.swift      # Individual nudge card
│       ├── PersonRow.swift      # List row
│       └── BriefBubble.swift    # AI brief display
└── Audio/
    └── AudioRecorder.swift      # AVFoundation wrapper
```

---

### AudioRecorder.swift

```swift
import AVFoundation
import Foundation

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var audioURL: URL?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        audioURL = url
        isRecording = true
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        isRecording = false
        return audioURL
    }
}
```

---

### APIClient.swift

```swift
import Foundation

class APIClient {
    static let shared = APIClient()
    let baseURL = "https://your-backend.railway.app"
    
    // Add a new person via voice memo
    func addPerson(audioURL: URL, userID: String) async throws -> Person {
        var request = URLRequest(url: URL(string: "\(baseURL)/add-person")!)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", 
                        forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        // Append audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"memo.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Person.self, from: data)
    }
    
    // Get brief for a person
    func getBrief(personID: String) async throws -> String {
        let url = URL(string: "\(baseURL)/brief/\(personID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: String].self, from: data)
        return response["brief"] ?? ""
    }
    
    // Get today's nudges
    func getNudges(userID: String) async throws -> [Nudge] {
        let url = URL(string: "\(baseURL)/nudges/\(userID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: [Nudge]].self, from: data)
        return response["nudges"] ?? []
    }
    
    // Draft reconnect email
    func draftEmail(personID: String) async throws -> EmailDraft {
        let url = URL(string: "\(baseURL)/draft-email/\(personID)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: EmailDraft].self, from: data)
        return response["draft"]!
    }
    
    // Send approved email
    func sendEmail(personID: String, toEmail: String, subject: String, body: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/send-email")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "person_id": personID,
            "to_email": toEmail,
            "subject": subject,
            "body": body
        ])
        _ = try await URLSession.shared.data(for: request)
    }
}
```

---

### HomeView.swift

```swift
import SwiftUI

struct HomeView: View {
    @State private var nudges: [Nudge] = []
    @State private var recentPersons: [Person] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greetingText())
                            .font(.system(size: 28, weight: .bold))
                        Text("\(nudges.count) people need your attention")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Nudge cards
                    if !nudges.isEmpty {
                        ForEach(nudges) { nudge in
                            NudgeCard(nudge: nudge)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                    }
                    
                    // Recent
                    Text("RECENT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                    
                    ForEach(recentPersons) { person in
                        NavigationLink(destination: PersonCardView(person: person)) {
                            PersonRow(person: person)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationBarHidden(true)
            .task { await loadData() }
        }
    }
    
    func loadData() async {
        nudges = (try? await APIClient.shared.getNudges(userID: "user_1")) ?? []
        isLoading = false
    }
    
    func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}
```

---

### RecordView.swift

```swift
import SwiftUI

struct RecordView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var isProcessing = false
    @State private var transcript = ""
    @State private var newPerson: Person?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("New memory")
                .font(.system(size: 22, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            // Transcript preview
            if !transcript.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TRANSCRIPT")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(transcript)
                                .font(.system(size: 13))
                                .lineSpacing(4)
                        }
                        .padding(12),
                        alignment: .topLeading
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Processing indicator
            if isProcessing {
                Text("Agent extracting profile...")
                    .font(.system(size: 12))
                    .foregroundColor(Color.purple)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(20)
            }
            
            // Record button
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: recorder.isRecording ? 4 : 36)
                            .fill(Color.white)
                            .frame(width: recorder.isRecording ? 24 : 28,
                                   height: recorder.isRecording ? 24 : 28)
                            .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !recorder.isRecording { recorder.startRecording() }
                            }
                            .onEnded { _ in
                                if let url = recorder.stopRecording() {
                                    Task { await processAudio(url: url) }
                                }
                            }
                    )
                
                Text(recorder.isRecording ? "Release to process" : "Hold to record")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding(.top)
    }
    
    func processAudio(url: URL) async {
        isProcessing = true
        do {
            newPerson = try await APIClient.shared.addPerson(audioURL: url, userID: "user_1")
        } catch {
            print("Error: \(error)")
        }
        isProcessing = false
    }
}
```

---

### PersonCardView.swift

```swift
import SwiftUI

struct PersonCardView: View {
    let person: Person
    @State private var brief = ""
    @State private var isLoadingBrief = false
    @State private var emailDraft: EmailDraft?
    @State private var showEmailDraft = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero header
                HStack(spacing: 12) {
                    AvatarView(name: person.name, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(.system(size: 18, weight: .semibold))
                        Text("\(person.role ?? "Unknown") · \(person.company ?? "Unknown")")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(person.daysSinceContact) days ago")
                            .font(.system(size: 11, weight: .500))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(person.daysSinceContact > 60 ? Color.red : Color.orange)
                            .cornerRadius(6)
                    }
                }
                .padding()
                
                // Brief me button
                Button {
                    Task { await loadBrief() }
                } label: {
                    Text(isLoadingBrief ? "Generating brief..." : "Brief me before I reach out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Brief bubble
                if !brief.isEmpty {
                    BriefBubble(text: brief, interactionCount: person.interactions?.count ?? 0)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
                // Draft email button
                Button {
                    Task { await loadEmailDraft() }
                } label: {
                    Text("Draft reconnect email")
                        .font(.system(size: 13))
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.08))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Tags
                if let tags = person.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 12)
                }
                
                // Interaction history
                Text("INTERACTION HISTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                ForEach(person.interactions ?? []) { interaction in
                    InteractionRow(interaction: interaction)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEmailDraft) {
            if let draft = emailDraft {
                EmailDraftView(draft: draft, person: person)
            }
        }
    }
    
    func loadBrief() async {
        isLoadingBrief = true
        brief = (try? await APIClient.shared.getBrief(personID: person.id)) ?? ""
        isLoadingBrief = false
    }
    
    func loadEmailDraft() async {
        emailDraft = try? await APIClient.shared.draftEmail(personID: person.id)
        showEmailDraft = emailDraft != nil
    }
}
```

---

## 11. Database Schema

```sql
-- SQLite schema

CREATE TABLE persons (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL,
    name            TEXT NOT NULL,
    company         TEXT,
    role            TEXT,
    topics          TEXT,  -- JSON array
    personal_details TEXT, -- JSON array
    signals         TEXT,  -- JSON array
    tags            TEXT,  -- JSON array
    sentiment       TEXT,
    follow_up_intent TEXT,
    relationship_strength INTEGER DEFAULT 5,
    email           TEXT,
    last_contact    DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE interactions (
    id          TEXT PRIMARY KEY,
    person_id   TEXT REFERENCES persons(id),
    type        TEXT DEFAULT 'voice_memo',  -- voice_memo, email_sent, email_reply, manual_note
    content     TEXT NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE email_threads (
    id              TEXT PRIMARY KEY,
    person_id       TEXT REFERENCES persons(id),
    agentmail_thread_id TEXT,
    subject         TEXT,
    status          TEXT DEFAULT 'sent',  -- sent, replied, no_reply
    sent_at         DATETIME,
    replied_at      DATETIME
);

CREATE INDEX idx_persons_user ON persons(user_id);
CREATE INDEX idx_interactions_person ON interactions(person_id);
CREATE INDEX idx_last_contact ON persons(last_contact);
```

---

## 12. All API Endpoints

| Method | Endpoint | Description | Input | Output |
|--------|----------|-------------|-------|--------|
| POST | `/add-person` | Add person from voice memo | audio file + user_id | Person profile JSON |
| GET | `/brief/{person_id}` | Get AI brief | person_id | brief string |
| GET | `/nudges/{user_id}` | Get today's nudges | user_id | array of nudges |
| GET | `/persons/{user_id}` | Get all persons | user_id | array of persons |
| GET | `/person/{person_id}` | Get single person | person_id | full profile |
| POST | `/interaction/{person_id}` | Add a new voice note | audio file | interaction |
| POST | `/draft-email/{person_id}` | Draft reconnect email | person_id | {subject, body} |
| POST | `/send-email` | Send approved email | person_id, to_email, subject, body | {status, message_id} |
| POST | `/email-reply` | AgentMail webhook | AgentMail payload | {status} |
| GET | `/search/{user_id}` | Semantic search | q (query string) | array of persons |

---

## 13. Full Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| iOS frontend | SwiftUI | Native, premium feel, you know it |
| Audio capture | AVFoundation | Best-in-class iOS audio |
| HTTP client | URLSession | Native, no dependencies |
| Backend | FastAPI (Python) | Fast to build, async-native |
| Transcription | OpenAI Whisper API | Best accuracy on voice memos |
| Agent LLM | Anthropic Claude claude-sonnet-4-20250514 | Best at structured extraction + reasoning |
| Structured DB | SQLite | Zero config, fast, local |
| Vector DB | ChromaDB | Simple embeddings, local, no cloud needed |
| Semantic memory | Nozomio Nia | Cross-session context, Oracle research, semantic search |
| Email agent | AgentMail | Agent-native email inbox + webhook replies |
| Embeddings | OpenAI text-embedding-3-small | For ChromaDB vectors |
| Backend hosting | Railway or Render | Free tier, deploys from GitHub in 2 min |
| Push notifications | APNs (Apple Push) | For reply notifications on iOS |

---

## 14. File & Folder Structure

```
recall/
├── ios/                          # Xcode project
│   └── Recall/
│       ├── RecallApp.swift
│       ├── Network/
│       │   └── APIClient.swift
│       ├── Models/
│       │   ├── Person.swift
│       │   ├── Interaction.swift
│       │   ├── Nudge.swift
│       │   └── EmailDraft.swift
│       ├── Views/
│       │   ├── HomeView.swift
│       │   ├── RecordView.swift
│       │   ├── PeopleView.swift
│       │   ├── PersonCardView.swift
│       │   ├── EmailDraftView.swift
│       │   └── Components/
│       │       ├── NudgeCard.swift
│       │       ├── PersonRow.swift
│       │       ├── AvatarView.swift
│       │       ├── BriefBubble.swift
│       │       └── InteractionRow.swift
│       └── Audio/
│           └── AudioRecorder.swift
│
├── backend/                      # Python FastAPI
│   ├── main.py                   # All routes
│   ├── agents/
│   │   ├── extraction.py         # Agent 1
│   │   ├── briefing.py           # Agent 2
│   │   └── outreach.py           # Agent 3
│   ├── integrations/
│   │   ├── nia.py                # Nozomio Nia calls
│   │   └── agentmail.py          # AgentMail calls
│   ├── db/
│   │   ├── sqlite.py             # SQLite helpers
│   │   └── chroma.py             # ChromaDB helpers
│   ├── schema.sql                # DB schema
│   ├── requirements.txt
│   └── .env                      # API keys
│
└── README.md
```

---

## 15. Hackathon Build Order

### Hour 1 — Foundation (get the pipeline working)
- Set up FastAPI skeleton, SQLite schema, install all packages
- Build `/add-person` endpoint: audio upload → Whisper → extraction agent → SQLite save
- Build iOS: AudioRecorder.swift + basic RecordView
- **Milestone: Record a memo, see a JSON profile returned**

### Hour 2 — Core screens
- Build PersonCardView with profile display
- Build `/brief` endpoint with briefing agent
- Wire up "Brief me" button in iOS
- Build PeopleView with persons list from API
- **Milestone: Tap a person, get an AI brief**

### Hour 3 — Nozomio integration
- Set up Nia CLI, get API key
- Add `save_to_nia()` call in add-person pipeline
- Add semantic search endpoint `/search`
- Wire up search bar in PeopleView to Nia
- **Milestone: Search "who do I know in design" → returns right people**

### Hour 4 — AgentMail integration
- Create AgentMail account, get API key
- Create agent inbox programmatically
- Build `/draft-email` and `/send-email` endpoints
- Build EmailDraftView in iOS (preview + approve + send)
- Register webhook URL for replies
- **Milestone: Draft an email, approve it, watch it send**

### Hour 5 — Nudge system + HomeView
- Build nudge scoring algorithm
- Add nudge agent reasoning call
- Build `/nudges` endpoint
- Build HomeView with nudge cards
- Pre-load demo data (15 people with varied dates + signals)
- **Milestone: Home screen shows smart nudges with reasons**

### Hour 6 — Polish + demo prep
- Test full flow end to end
- Fix any broken states / error handling
- Prepare demo data (make it impressive)
- Practice the demo script twice
- Deploy backend to Railway (takes 5 minutes)

---

## 16. Demo Script

**Duration: 90 seconds**

**Step 1 (15s):** Open app on real iPhone. Show home screen with 3 nudge cards. Point at Marcus — "91 days, hasn't been contacted since he mentioned going through something hard. The agent flagged this."

**Step 2 (20s):** Tap the record button. Speak live into the phone: *"Just met David — he's a partner at a16z, focused on AI infrastructure, mentioned he's frustrated with the pace of enterprise AI adoption, has a daughter who's starting college next year."*

**Step 3 (15s):** Watch the transcript appear live. Watch the processing indicator. Watch the profile card appear. Tags extracted: "enterprise AI," "a16z," "daughter starting college."

**Step 4 (15s):** Tap "Brief me." Show the brief appear: *"David is an AI-focused partner at a16z. He's frustrated with enterprise AI moving slowly — a real conversation hook. His daughter starts college soon, which means he's probably thinking about the next chapter too."*

**Step 5 (20s):** Tap "Draft reconnect email." Show the draft: subject, personalized body referencing what he said, a question to invite a reply. Tap "Approve & Send." Show AgentMail confirmation. Say: "That email just went out from our agent's inbox. If David replies, we get a push notification and it's logged as a new interaction automatically."

**Step 6 (5s):** "The best relationship builders in the world do this manually. We built the agent version."

---

## 17. What Judges Will See

**The agent angle:** Three distinct Claude agents with different roles — not one chatbot. An extraction agent that transforms speech into structured data, a briefing agent that reasons about relationships, and an outreach agent that takes autonomous action.

**The pipeline:** Voice → Whisper → Claude → SQLite + ChromaDB + Nia. Two external integrations used meaningfully, not as decoration.

**The demo moment:** A real email sent from an AI agent's inbox, to a real address, in real time, in front of them. Nobody else at this hackathon will have autonomous email outreach in their demo.

**The use case:** Universal. Every person in that room has relationships they've let decay. They will feel it personally. That emotional resonance is rare at hackathons.

**The polish:** A real iPhone with a native SwiftUI app. Not a web app. Not a Figma mockup. A thing that works.

---

*Built at hackathon using: Anthropic Claude, OpenAI Whisper, Nozomio Nia, AgentMail, FastAPI, SwiftUI*

*Contact: recall-agent@agentmail.to*
