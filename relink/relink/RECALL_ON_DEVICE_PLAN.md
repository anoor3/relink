# RECALL — On-Device Architecture Plan
### Everything runs on iPhone. No backend. No servers. No connection issues.

---

## THE BIG IDEA

Your iPhone talks directly to:
- **OpenAI Whisper API** → transcription
- **Anthropic Claude API** → all three agents
- **Nozomio Nia API** → semantic search + context memory
- **AgentMail API** → agent email inbox + sending + webhooks

Zero backend. Zero servers. The app IS the system.

---

## HOW THIS CHANGES EVERYTHING

| Before (backend) | Now (on-device) |
|---|---|
| FastAPI server running somewhere | Swift calls APIs directly |
| CORS issues, deployment pain | No network middleman |
| Backend crashes = app dies | If one API fails, rest still work |
| Need WiFi to your server | Just need internet (any network) |
| Two codebases to manage | One Xcode project, done |
| SQLite on server | SwiftData / Core Data on device |
| ChromaDB on server | On-device vector search (Swift) |

The only thing you lose: you can't run background jobs when the app is closed. But for a hackathon demo, the app is always open. You win.

---

## FULL ON-DEVICE ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────┐
│                          YOUR iPHONE                                │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     SwiftUI LAYER                           │   │
│  │  HomeView │ RecordView │ PeopleView │ PersonCardView        │   │
│  │  EmailDraftView │ SearchView │ SettingsView                 │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                           │
│  ┌──────────────────────▼──────────────────────────────────────┐   │
│  │                   SERVICE LAYER                             │   │
│  │                                                             │   │
│  │  AgentOrchestrator.swift  ←  coordinates all agents        │   │
│  │  ├── ExtractionAgent.swift                                  │   │
│  │  ├── BriefingAgent.swift                                    │   │
│  │  ├── NudgeAgent.swift                                       │   │
│  │  └── OutreachAgent.swift                                    │   │
│  │                                                             │   │
│  │  AudioService.swift    ← AVFoundation recording            │   │
│  │  WhisperService.swift  ← OpenAI Whisper API calls          │   │
│  │  NiaService.swift      ← Nozomio Nia API calls             │   │
│  │  AgentMailService.swift ← AgentMail API calls              │   │
│  └──────────────────────┬──────────────────────────────────────┘   │
│                         │                                           │
│  ┌──────────────────────▼──────────────────────────────────────┐   │
│  │                   STORAGE LAYER                             │   │
│  │                                                             │   │
│  │  SwiftData (persons, interactions, email threads)           │   │
│  │  UserDefaults (API keys, settings, agent inbox ID)          │   │
│  │  Local vector store (simple cosine similarity in Swift)     │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │  HTTPS (direct from device)
          ┌──────────────────┼──────────────────────┐
          ▼                  ▼                      ▼                  ▼
   ┌────────────┐   ┌───────────────┐   ┌──────────────┐   ┌─────────────┐
   │  OpenAI    │   │  Anthropic    │   │  Nozomio Nia │   │ AgentMail   │
   │  Whisper   │   │  Claude API   │   │  API         │   │ API         │
   │  API       │   │               │   │              │   │             │
   └────────────┘   └───────────────┘   └──────────────┘   └─────────────┘
```

---

## THE FOUR PIPELINES — FULLY ON DEVICE

---

### PIPELINE 1 — Adding Someone (Voice → Profile)

```
┌─────────────────────────────────────────────────────────────────┐
│ USER HOLDS RECORD BUTTON                                        │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ AudioService.swift                                              │
│ AVAudioRecorder captures mic → .m4a file in app sandbox         │
│ Waveform animates in real time (AVAudioRecorder metering)       │
└──────────────┬──────────────────────────────────────────────────┘
               │ user releases button
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ WhisperService.swift                                            │
│ POST https://api.openai.com/v1/audio/transcriptions             │
│ Headers: Authorization: Bearer {OPENAI_KEY}                     │
│ Body: multipart — audio file + model=whisper-1                  │
│ Returns: { text: "Just met James, designer at Stripe..." }      │
└──────────────┬──────────────────────────────────────────────────┘
               │ raw transcript string
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ ExtractionAgent.swift                                           │
│ POST https://api.anthropic.com/v1/messages                      │
│ Headers: x-api-key: {ANTHROPIC_KEY}                             │
│          anthropic-version: 2023-06-01                          │
│ Body: {                                                         │
│   model: "claude-sonnet-4-20250514",                            │
│   max_tokens: 1000,                                             │
│   system: EXTRACTION_SYSTEM_PROMPT,                             │
│   messages: [{ role: "user", content: transcript }]             │
│ }                                                               │
│ Returns: structured JSON person profile                         │
└──────────────┬──────────────────────────────────────────────────┘
               │ Person struct
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STORAGE — runs in parallel                                      │
│                                                                 │
│ ① SwiftData.save(person)         → local database               │
│ ② VectorStore.embed(person)      → local cosine similarity      │
│ ③ NiaService.saveContext(person) → Nia cross-session memory     │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ UI UPDATE                                                       │
│ PersonCardView animates in with extracted profile               │
│ Tags appear, signals shown, interaction logged                  │
└─────────────────────────────────────────────────────────────────┘

Total time: ~6–10 seconds on device
```

---

### PIPELINE 2 — Get AI Brief (On Demand)

```
┌─────────────────────────────────────────────────────────────────┐
│ USER TAPS "BRIEF ME" on PersonCardView                          │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ CONTEXT ASSEMBLY (in Swift, no API call needed)                 │
│                                                                 │
│ profile       = SwiftData.fetchPerson(id)                       │
│ interactions  = SwiftData.fetchInteractions(personID: id)       │
│ daysSince     = Date().daysSince(profile.lastContact)           │
│                                                                 │
│ OPTIONAL: NiaService.getContext(name)                           │
│ → pulls any enriched context saved from previous sessions       │
└──────────────┬──────────────────────────────────────────────────┘
               │ assembled context object
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ BriefingAgent.swift                                             │
│ POST https://api.anthropic.com/v1/messages                      │
│                                                                 │
│ User message:                                                   │
│ """                                                             │
│ Person: \(profile.toJSON())                                     │
│ Interactions: \(interactions.toJSON())                          │
│ Days since last contact: \(daysSince)                           │
│ Brief me before I reach out.                                    │
│ """                                                             │
│                                                                 │
│ Returns: plain text brief (3–4 sentences)                       │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ UI: BriefBubble animates in on PersonCardView                   │
│ Purple card, agent attribution, interaction count shown         │
└─────────────────────────────────────────────────────────────────┘

Total time: ~2–4 seconds
```

---

### PIPELINE 3 — Nudge Engine (On App Open)

```
┌─────────────────────────────────────────────────────────────────┐
│ APP OPENS → HomeView.onAppear fires                             │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: SCORE ALL PERSONS (pure Swift, no API)                  │
│                                                                 │
│ For each person in SwiftData:                                   │
│                                                                 │
│   dayScore     = min(daysSince / 30.0 * 40, 40)  // 0–40 pts  │
│   signalScore  = signals.count * 8               // 0–40 pts   │
│   strengthScore = relationshipStrength * 2       // 0–20 pts   │
│   totalScore   = dayScore + signalScore + strengthScore         │
│                                                                 │
│ Sort descending → take top 5                                    │
└──────────────┬──────────────────────────────────────────────────┘
               │ top 5 persons with scores
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: NudgeAgent.swift — Claude picks & explains (1 API call) │
│                                                                 │
│ POST https://api.anthropic.com/v1/messages                      │
│                                                                 │
│ User message:                                                   │
│ """                                                             │
│ Here are 5 people ranked by relationship health score.          │
│ Pick the 3 most important to reconnect with TODAY.              │
│ For each, write one sentence (max 15 words) explaining          │
│ WHY NOW specifically — not just "it's been a while."            │
│ Return JSON: [{person_id, reason, urgency: high|med|low}]       │
│ \(top5.toJSON())                                                │
│ """                                                             │
│                                                                 │
│ Returns: [{person_id: "x", reason: "...", urgency: "high"}]     │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ UI: HomeView renders 3 NudgeCards                               │
│ Each card shows: name, company, urgency color, reason sentence  │
│ Tap → goes to PersonCardView                                    │
└─────────────────────────────────────────────────────────────────┘

Total time: ~2–3 seconds on app open
```

---

### PIPELINE 4 — Email Outreach via AgentMail

```
┌─────────────────────────────────────────────────────────────────┐
│ USER TAPS "Draft reconnect email"                               │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: OutreachAgent.swift — draft the email                   │
│                                                                 │
│ POST https://api.anthropic.com/v1/messages                      │
│                                                                 │
│ Sends: full person profile + all interactions + today's date    │
│ System prompt: write a genuine short reconnect email            │
│ Returns: { "subject": "...", "body": "..." }                    │
└──────────────┬──────────────────────────────────────────────────┘
               │ EmailDraft struct
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ UI: EmailDraftView slides up                                    │
│ Shows: subject line, full body                                  │
│ Buttons: [Edit] [Approve & Send]                                │
└──────────────┬──────────────────────────────────────────────────┘
               │ user taps Approve & Send
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: AgentMailService.swift — send the email                 │
│                                                                 │
│ POST https://api.agentmail.to/v0/inboxes/{inboxID}/messages     │
│ Headers: Authorization: Bearer {AGENTMAIL_KEY}                  │
│ Body: {                                                         │
│   to: [{ email: person.email }],                                │
│   subject: draft.subject,                                       │
│   text: draft.body                                              │
│ }                                                               │
│                                                                 │
│ Returns: { id: "msg_xxx", status: "sent" }                      │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: LOG locally                                             │
│                                                                 │
│ SwiftData.save(EmailThread(                                     │
│   personID: person.id,                                          │
│   subject: draft.subject,                                       │
│   agentMailMessageID: result.id,                                │
│   sentAt: Date(),                                               │
│   status: .sent                                                 │
│ ))                                                              │
│                                                                 │
│ SwiftData.save(Interaction(                                     │
│   personID: person.id,                                          │
│   type: .emailSent,                                             │
│   content: "Sent: \(draft.subject)"                             │
│ ))                                                              │
└──────────────┬──────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ UI: "Email sent ✓" confirmation toast                           │
│ PersonCardView updates interaction history                      │
│ Email thread visible in person card under "Outreach"            │
└──────────────┬──────────────────────────────────────────────────┘
               │ (later, when person replies)
               ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: REPLY CHECKING (on app open or manual refresh)          │
│                                                                 │
│ AgentMailService.checkReplies(inboxID)                          │
│ GET https://api.agentmail.to/v0/inboxes/{inboxID}/threads       │
│                                                                 │
│ For each thread with reply_count > 1:                           │
│   → fetch thread messages                                       │
│   → match to person by subject/email                            │
│   → log reply as new Interaction                                │
│   → show local notification: "James replied to your email"     │
└─────────────────────────────────────────────────────────────────┘

Total send time: ~3–5 seconds
```

---

## ALL SWIFT FILES — WHAT EACH ONE DOES

---

### Services/WhisperService.swift

```swift
import Foundation

class WhisperService {
    static let shared = WhisperService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let audioData = try Data(contentsOf: audioURL)
        
        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return response.text
    }
}

struct WhisperResponse: Decodable { let text: String }
```

---

### Services/ClaudeService.swift

```swift
import Foundation

// Shared Claude caller — all agents use this
class ClaudeService {
    static let shared = ClaudeService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
    }
    
    func complete(system: String, userMessage: String, maxTokens: Int = 1000) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": userMessage]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return response.content.first?.text ?? ""
    }
}

struct ClaudeResponse: Decodable {
    struct Content: Decodable { let text: String }
    let content: [Content]
}
```

---

### Agents/ExtractionAgent.swift

```swift
import Foundation

class ExtractionAgent {
    static let shared = ExtractionAgent()
    
    private let systemPrompt = """
    You are an expert at extracting structured relationship data from casual speech.
    You receive a raw voice memo transcript about someone the user just met.
    
    Extract all meaningful information and return ONLY valid JSON — no preamble, no markdown.
    
    Required JSON structure:
    {
      "name": "string",
      "company": "string or null",
      "role": "string or null",
      "email": "string or null (only if explicitly mentioned)",
      "topics_discussed": ["array of strings"],
      "personal_details": ["anything personal: kids, hobbies, life events, passions"],
      "signals": ["anything implying future action or emotional state"],
      "sentiment": "warm | neutral | cold",
      "follow_up_intent": "string — what would be natural to follow up on",
      "relationship_strength": 1-10,
      "tags": ["array of short keyword strings, max 6"]
    }
    
    Be generous with signals — anything like "stressed", "excited about X", 
    "considering leaving", "launching soon" is a signal.
    """
    
    func extract(from transcript: String) async throws -> PersonProfile {
        let raw = try await ClaudeService.shared.complete(
            system: systemPrompt,
            userMessage: transcript,
            maxTokens: 800
        )
        
        // Strip any accidental markdown fences
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let data = clean.data(using: .utf8)!
        return try JSONDecoder().decode(PersonProfile.self, from: data)
    }
}
```

---

### Agents/BriefingAgent.swift

```swift
import Foundation

class BriefingAgent {
    static let shared = BriefingAgent()
    
    private let systemPrompt = """
    You are a relationship intelligence assistant.
    Given a person's profile and interaction history, write a brief (max 4 sentences) that:
    1. Reminds the user of the most important context about this person
    2. Notes how long it's been and what may have changed since
    3. Suggests the natural angle for reconnecting — genuine, not pushy
    4. Flags anything sensitive or important to be aware of
    
    Write in second person ("They were..."). Sound like a thoughtful friend, not a corporate assistant.
    No bullet points. Plain paragraph only.
    """
    
    func brief(person: Person, interactions: [Interaction], daysSince: Int) async throws -> String {
        let userMessage = """
        Person profile:
        \(person.toJSONString())
        
        Interaction history (\(interactions.count) total):
        \(interactions.map { "- [\($0.formattedDate)]: \($0.content)" }.joined(separator: "\n"))
        
        Days since last contact: \(daysSince)
        
        Write the brief.
        """
        
        return try await ClaudeService.shared.complete(
            system: systemPrompt,
            userMessage: userMessage,
            maxTokens: 300
        )
    }
}
```

---

### Agents/NudgeAgent.swift

```swift
import Foundation

struct NudgeResult: Codable {
    let personID: String
    let reason: String
    let urgency: String // "high" | "medium" | "low"
    
    enum CodingKeys: String, CodingKey {
        case personID = "person_id"
        case reason, urgency
    }
}

class NudgeAgent {
    static let shared = NudgeAgent()
    
    private let systemPrompt = """
    You are a relationship health advisor.
    You receive a list of people ranked by a relationship health score.
    Pick the 3 most important to reconnect with TODAY.
    
    For each, write one sentence (max 15 words) explaining WHY NOW specifically.
    Don't say "it's been a while" — reference their actual signals and context.
    
    Return ONLY valid JSON array:
    [{"person_id": "...", "reason": "...", "urgency": "high|medium|low"}]
    """
    
    // Score each person locally — no API needed
    func scorePersons(_ persons: [Person]) -> [(Person, Double)] {
        return persons.map { person in
            let days = Double(Calendar.current.dateComponents(
                [.day], from: person.lastContact, to: Date()).day ?? 0)
            let dayScore = min(days / 30.0 * 40.0, 40.0)
            let signalScore = Double(min(person.signals.count * 8, 40))
            let strengthScore = Double(person.relationshipStrength * 2)
            let total = dayScore + signalScore + strengthScore
            return (person, total)
        }.sorted { $0.1 > $1.1 }
    }
    
    func pickNudges(from persons: [Person]) async throws -> [NudgeResult] {
        let scored = scorePersons(persons)
        let top5 = scored.prefix(5).map { $0.0 }
        
        // Build summary for Claude
        let summaries = top5.map { p in
            """
            {
              "person_id": "\(p.id)",
              "name": "\(p.name)",
              "company": "\(p.company ?? "unknown")",
              "days_since_contact": \(p.daysSince),
              "signals": \(p.signals),
              "relationship_strength": \(p.relationshipStrength)
            }
            """
        }.joined(separator: ",\n")
        
        let raw = try await ClaudeService.shared.complete(
            system: systemPrompt,
            userMessage: "[\(summaries)]",
            maxTokens: 400
        )
        
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let data = clean.data(using: .utf8)!
        return try JSONDecoder().decode([NudgeResult].self, from: data)
    }
}
```

---

### Agents/OutreachAgent.swift

```swift
import Foundation

struct EmailDraft: Codable {
    let subject: String
    let body: String
}

class OutreachAgent {
    static let shared = OutreachAgent()
    
    private let systemPrompt = """
    You are writing a reconnect email on behalf of the user.
    Write a short, warm, genuine email to reconnect with someone they haven't 
    spoken to in a while.
    
    Rules:
    - Max 5 sentences total
    - NEVER use "I hope this email finds you well"
    - Reference something specific and real from their history together
    - Include one natural reason for reaching out (not just "checking in")
    - End with one soft question to invite a reply
    - Sound like a real person, not a template
    
    Return ONLY valid JSON: {"subject": "...", "body": "..."}
    No markdown, no explanation.
    """
    
    func draft(person: Person, interactions: [Interaction]) async throws -> EmailDraft {
        let userMessage = """
        Person: \(person.name), \(person.role ?? "") at \(person.company ?? "unknown")
        Days since last contact: \(person.daysSince)
        Key signals: \(person.signals.joined(separator: ", "))
        Personal details: \(person.personalDetails.joined(separator: ", "))
        
        Interaction history:
        \(interactions.prefix(3).map { "- \($0.content)" }.joined(separator: "\n"))
        
        Draft the reconnect email.
        """
        
        let raw = try await ClaudeService.shared.complete(
            system: systemPrompt,
            userMessage: userMessage,
            maxTokens: 500
        )
        
        let clean = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let data = clean.data(using: .utf8)!
        return try JSONDecoder().decode(EmailDraft.self, from: data)
    }
}
```

---

### Services/AgentMailService.swift

```swift
import Foundation

class AgentMailService {
    static let shared = AgentMailService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "agentmail_api_key") ?? ""
    }
    
    private var inboxID: String {
        UserDefaults.standard.string(forKey: "agentmail_inbox_id") ?? ""
    }
    
    private let baseURL = "https://api.agentmail.to/v0"
    
    // Call ONCE at first app launch to create the agent inbox
    func createInbox() async throws -> String {
        let url = URL(string: "\(baseURL)/inboxes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": "recall-agent", "display_name": "Recall Agent"]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AgentMailInbox.self, from: data)
        
        // Save inbox ID for future use
        UserDefaults.standard.set(response.id, forKey: "agentmail_inbox_id")
        return response.id
    }
    
    // Send an email from the agent inbox
    func sendEmail(to email: String, subject: String, body: String) async throws -> String {
        let url = URL(string: "\(baseURL)/inboxes/\(inboxID)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "to": [["email": email]],
            "subject": subject,
            "text": body
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AgentMailMessage.self, from: data)
        return response.id
    }
    
    // Check for replies (call on app open)
    func checkReplies() async throws -> [AgentMailThread] {
        let url = URL(string: "\(baseURL)/inboxes/\(inboxID)/threads")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AgentMailThreadsResponse.self, from: data)
        return response.threads.filter { $0.messageCount > 1 } // Has replies
    }
    
    // Get messages in a thread
    func getThread(threadID: String) async throws -> [AgentMailMessage] {
        let url = URL(string: "\(baseURL)/inboxes/\(inboxID)/threads/\(threadID)/messages")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AgentMailMessagesResponse.self, from: data)
        return response.messages
    }
}

// AgentMail response models
struct AgentMailInbox: Decodable { let id: String }
struct AgentMailMessage: Decodable {
    let id: String
    let subject: String?
    let text: String?
    let from: AgentMailAddress?
}
struct AgentMailAddress: Decodable { let email: String }
struct AgentMailThread: Decodable {
    let id: String
    let subject: String?
    let messageCount: Int
    enum CodingKeys: String, CodingKey {
        case id, subject
        case messageCount = "message_count"
    }
}
struct AgentMailThreadsResponse: Decodable { let threads: [AgentMailThread] }
struct AgentMailMessagesResponse: Decodable { let messages: [AgentMailMessage] }
```

---

### Services/NiaService.swift

```swift
import Foundation

class NiaService {
    static let shared = NiaService()
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "nia_api_key") ?? ""
    }
    
    private let baseURL = "https://api.trynia.ai/v1"
    
    // Save person profile to Nia for cross-session memory
    func saveContext(person: Person) async {
        guard !apiKey.isEmpty else { return }
        
        let url = URL(string: "\(baseURL)/contexts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "title": person.name,
            "summary": "\(person.role ?? "unknown") at \(person.company ?? "unknown")",
            "content": person.toJSONString(),
            "memory_type": "episodic"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = try? await URLSession.shared.data(for: request)
    }
    
    // Semantic search — "who do I know in fintech who was stressed?"
    func semanticSearch(query: String) async throws -> [NiaContext] {
        guard !apiKey.isEmpty else { return [] }
        
        let url = URL(string: "\(baseURL)/contexts/semantic")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["query": query, "limit": 10] as [String: Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(NiaSearchResponse.self, from: data)
        return response.results
    }
    
    // Get enriched context for a person (used in briefing)
    func getContext(for name: String) async throws -> String? {
        let results = try await semanticSearch(query: name)
        return results.first?.content
    }
}

struct NiaContext: Decodable {
    let title: String
    let summary: String
    let content: String
}
struct NiaSearchResponse: Decodable { let results: [NiaContext] }
```

---

### AgentOrchestrator.swift — The Brain

This is the single file that coordinates all agents together. Views call this, not individual agents.

```swift
import Foundation

// Single entry point for all agent operations
// Views never call agents directly — always go through here
@MainActor
class AgentOrchestrator: ObservableObject {
    static let shared = AgentOrchestrator()
    
    @Published var isProcessing = false
    @Published var processingStep = ""
    
    // FLOW 1: Full pipeline — voice memo → person card
    func processVoiceMemo(audioURL: URL) async throws -> Person {
        isProcessing = true
        
        defer { isProcessing = false }
        
        // Step 1: Transcribe
        processingStep = "Transcribing..."
        let transcript = try await WhisperService.shared.transcribe(audioURL: audioURL)
        
        // Step 2: Extract profile
        processingStep = "Extracting profile..."
        let profile = try await ExtractionAgent.shared.extract(from: transcript)
        
        // Step 3: Save to SwiftData
        processingStep = "Saving..."
        let person = Person.from(profile: profile)
        SwiftDataStore.shared.save(person: person)
        SwiftDataStore.shared.save(interaction: Interaction(
            personID: person.id,
            type: .voiceMemo,
            content: transcript
        ))
        
        // Step 4: Save to Nia (async, don't wait)
        Task { await NiaService.shared.saveContext(person: person) }
        
        processingStep = ""
        return person
    }
    
    // FLOW 2: Get brief
    func getBrief(for person: Person) async throws -> String {
        let interactions = SwiftDataStore.shared.getInteractions(personID: person.id)
        let days = person.daysSince
        return try await BriefingAgent.shared.brief(
            person: person,
            interactions: interactions,
            daysSince: days
        )
    }
    
    // FLOW 3: Get today's nudges
    func getNudges() async throws -> [(Person, NudgeResult)] {
        let allPersons = SwiftDataStore.shared.getAllPersons()
        guard !allPersons.isEmpty else { return [] }
        
        let nudgeResults = try await NudgeAgent.shared.pickNudges(from: allPersons)
        
        return nudgeResults.compactMap { nudge in
            guard let person = allPersons.first(where: { $0.id == nudge.personID }) else {
                return nil
            }
            return (person, nudge)
        }
    }
    
    // FLOW 4: Draft email
    func draftEmail(for person: Person) async throws -> EmailDraft {
        let interactions = SwiftDataStore.shared.getInteractions(personID: person.id)
        return try await OutreachAgent.shared.draft(person: person, interactions: interactions)
    }
    
    // FLOW 4b: Send approved email
    func sendEmail(draft: EmailDraft, to person: Person) async throws {
        guard let email = person.email else { throw RecallError.noEmail }
        
        let messageID = try await AgentMailService.shared.sendEmail(
            to: email,
            subject: draft.subject,
            body: draft.body
        )
        
        // Log locally
        SwiftDataStore.shared.save(emailThread: EmailThread(
            personID: person.id,
            agentMailMessageID: messageID,
            subject: draft.subject,
            status: .sent
        ))
        
        SwiftDataStore.shared.save(interaction: Interaction(
            personID: person.id,
            type: .emailSent,
            content: "Email sent: \(draft.subject)"
        ))
    }
    
    // FLOW 4c: Check for replies (call on app open)
    func checkEmailReplies() async {
        guard let threads = try? await AgentMailService.shared.checkReplies() else { return }
        
        for thread in threads {
            // Match thread to person by looking up stored email threads
            if let emailThread = SwiftDataStore.shared.getEmailThread(agentMailThreadID: thread.id),
               emailThread.status != .replied {
                
                // Get the reply content
                if let messages = try? await AgentMailService.shared.getThread(threadID: thread.id),
                   let reply = messages.last {
                    
                    // Log as interaction
                    SwiftDataStore.shared.save(interaction: Interaction(
                        personID: emailThread.personID,
                        type: .emailReply,
                        content: "Replied: \(reply.text?.prefix(200) ?? "no content")"
                    ))
                    
                    // Update thread status
                    SwiftDataStore.shared.updateEmailThread(id: emailThread.id, status: .replied)
                    
                    // Local notification
                    let person = SwiftDataStore.shared.getPerson(id: emailThread.personID)
                    NotificationService.shared.send(
                        title: "\(person?.name ?? "Someone") replied",
                        body: "Tap to see their response"
                    )
                }
            }
        }
    }
}

enum RecallError: Error {
    case noEmail
    case transcriptionFailed
    case extractionFailed
}
```

---

## SWIFTDATA MODELS

```swift
import SwiftData
import Foundation

@Model
class Person {
    var id: String = UUID().uuidString
    var name: String = ""
    var company: String? = nil
    var role: String? = nil
    var email: String? = nil
    var topicsDiscussed: [String] = []
    var personalDetails: [String] = []
    var signals: [String] = []
    var tags: [String] = []
    var sentiment: String = "neutral"
    var followUpIntent: String = ""
    var relationshipStrength: Int = 5
    var lastContact: Date = Date()
    var createdAt: Date = Date()
    
    @Relationship(deleteRule: .cascade)
    var interactions: [Interaction]? = []
    
    @Relationship(deleteRule: .cascade)
    var emailThreads: [EmailThread]? = []
    
    var daysSince: Int {
        Calendar.current.dateComponents([.day], from: lastContact, to: Date()).day ?? 0
    }
    
    func toJSONString() -> String {
        let dict: [String: Any] = [
            "id": id,
            "name": name,
            "company": company ?? "",
            "role": role ?? "",
            "topics": topicsDiscussed,
            "personal_details": personalDetails,
            "signals": signals,
            "tags": tags,
            "sentiment": sentiment,
            "relationship_strength": relationshipStrength,
            "days_since_contact": daysSince
        ]
        let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }
    
    static func from(profile: PersonProfile) -> Person {
        let p = Person()
        p.name = profile.name
        p.company = profile.company
        p.role = profile.role
        p.email = profile.email
        p.topicsDiscussed = profile.topicsDiscussed
        p.personalDetails = profile.personalDetails
        p.signals = profile.signals
        p.tags = profile.tags
        p.sentiment = profile.sentiment
        p.followUpIntent = profile.followUpIntent
        p.relationshipStrength = profile.relationshipStrength
        return p
    }
}

@Model
class Interaction {
    var id: String = UUID().uuidString
    var personID: String = ""
    var type: InteractionType = .voiceMemo
    var content: String = ""
    var createdAt: Date = Date()
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

enum InteractionType: String, Codable {
    case voiceMemo, emailSent, emailReply, manualNote
}

@Model
class EmailThread {
    var id: String = UUID().uuidString
    var personID: String = ""
    var agentMailMessageID: String = ""
    var agentMailThreadID: String? = nil
    var subject: String = ""
    var status: EmailStatus = .sent
    var sentAt: Date = Date()
    var repliedAt: Date? = nil
}

enum EmailStatus: String, Codable {
    case sent, replied, noReply
}

// Decodable version of profile (from Claude JSON output)
struct PersonProfile: Decodable {
    let name: String
    let company: String?
    let role: String?
    let email: String?
    let topicsDiscussed: [String]
    let personalDetails: [String]
    let signals: [String]
    let sentiment: String
    let followUpIntent: String
    let relationshipStrength: Int
    let tags: [String]
    
    enum CodingKeys: String, CodingKey {
        case name, company, role, email, sentiment, tags
        case topicsDiscussed = "topics_discussed"
        case personalDetails = "personal_details"
        case signals
        case followUpIntent = "follow_up_intent"
        case relationshipStrength = "relationship_strength"
    }
}
```

---

## SETTINGS VIEW — API KEYS ON DEVICE

This is where users paste their API keys. Stored in UserDefaults (for hackathon — use Keychain in production).

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropic_api_key") private var anthropicKey = ""
    @AppStorage("openai_api_key") private var openaiKey = ""
    @AppStorage("agentmail_api_key") private var agentmailKey = ""
    @AppStorage("nia_api_key") private var niaKey = ""
    
    @State private var inboxCreated = false
    @State private var isCreatingInbox = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Anthropic") {
                    SecureField("Claude API Key (sk-ant-...)", text: $anthropicKey)
                }
                
                Section("OpenAI (Whisper)") {
                    SecureField("OpenAI API Key (sk-...)", text: $openaiKey)
                }
                
                Section("AgentMail") {
                    SecureField("AgentMail API Key", text: $agentmailKey)
                    Button {
                        Task { await setupAgentInbox() }
                    } label: {
                        if isCreatingInbox {
                            ProgressView()
                        } else if inboxCreated {
                            Label("Agent inbox ready ✓", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("Create agent inbox")
                        }
                    }
                    .disabled(agentmailKey.isEmpty || inboxCreated || isCreatingInbox)
                }
                
                Section("Nozomio Nia (optional — enables smart search)") {
                    SecureField("Nia API Key", text: $niaKey)
                }
            }
            .navigationTitle("API Keys")
        }
    }
    
    func setupAgentInbox() async {
        isCreatingInbox = true
        _ = try? await AgentMailService.shared.createInbox()
        inboxCreated = true
        isCreatingInbox = false
    }
}
```

---

## FULL FILE STRUCTURE

```
Recall.xcodeproj
└── Recall/
    ├── RecallApp.swift                 ← App entry, SwiftData container setup
    ├── Models/
    │   ├── Person.swift                ← @Model SwiftData person
    │   ├── Interaction.swift           ← @Model SwiftData interaction
    │   ├── EmailThread.swift           ← @Model SwiftData email thread
    │   └── PersonProfile.swift         ← Decodable from Claude JSON
    ├── Services/
    │   ├── WhisperService.swift        ← OpenAI Whisper API
    │   ├── ClaudeService.swift         ← Shared Claude HTTP caller
    │   ├── AgentMailService.swift      ← AgentMail send + threads
    │   ├── NiaService.swift            ← Nozomio Nia search + context
    │   ├── SwiftDataStore.swift        ← All local DB operations
    │   ├── AudioRecorder.swift         ← AVFoundation recording
    │   └── NotificationService.swift   ← Local push notifications
    ├── Agents/
    │   ├── AgentOrchestrator.swift     ← Coordinates all agents (Views use this)
    │   ├── ExtractionAgent.swift       ← Voice → structured profile
    │   ├── BriefingAgent.swift         ← Profile → contextual brief
    │   ├── NudgeAgent.swift            ← Score + pick today's nudges
    │   └── OutreachAgent.swift         ← Profile → email draft
    └── Views/
        ├── HomeView.swift              ← Nudge cards + recent persons
        ├── RecordView.swift            ← Voice memo recording
        ├── PeopleView.swift            ← All contacts + search
        ├── PersonCardView.swift        ← Full profile + brief + email
        ├── EmailDraftView.swift        ← Review + approve + send
        ├── SettingsView.swift          ← API keys input
        └── Components/
            ├── NudgeCard.swift
            ├── PersonRow.swift
            ├── AvatarView.swift
            ├── BriefBubble.swift
            ├── WaveformView.swift
            └── InteractionRow.swift
```

---

## HACKATHON BUILD ORDER (6 hours)

### Hour 1 — Core foundation
- Create Xcode project, add SwiftData models
- Build `AudioRecorder.swift` — test recording works on device
- Build `WhisperService.swift` — test transcription works
- Build `ExtractionAgent.swift` — test JSON profile comes back
- Wire them together in `AgentOrchestrator.processVoiceMemo()`
- **Milestone: Record voice memo → see Person profile printed to console**

### Hour 2 — Storage + basic screens
- Build `SwiftDataStore.swift`
- Build `RecordView.swift` with record button
- Build `PeopleView.swift` showing persons from SwiftData
- Build `PersonCardView.swift` (static, no brief yet)
- **Milestone: Record → profile → saved → visible in list**

### Hour 3 — Briefing + Nudges
- Build `BriefingAgent.swift`
- Wire "Brief me" button in PersonCardView
- Build `NudgeAgent.swift` with scoring
- Build `HomeView.swift` with nudge cards
- **Milestone: Tap person → get AI brief. Open app → see nudges**

### Hour 4 — AgentMail email flow
- Create AgentMail account, get key, set up in Settings
- Build `AgentMailService.swift`
- Build `OutreachAgent.swift`
- Build `EmailDraftView.swift`
- Wire full send flow
- **Milestone: Draft email → approve → email actually sends**

### Hour 5 — Nozomio + polish
- Add Nia API key to Settings
- Wire `NiaService.saveContext()` in add-person flow
- Wire `NiaService.semanticSearch()` in PeopleView search bar
- Build `SettingsView.swift` cleanly
- Pre-load 15 demo people with varied dates
- **Milestone: Semantic search works. Full flow works end to end.**

### Hour 6 — Demo prep
- Run full flow 5 times, fix any crashes
- Pre-load impressive demo data
- Turn off all error states that show ugly alerts
- Practice 90-second demo script
- **Milestone: Hand phone to anyone, they can use it without explanation**

---

## DEMO SCRIPT (90 seconds, on real iPhone)

**0:00** — Open app. Home screen. Three nudge cards visible.
Point at the top one: *"Marcus — 91 days. The agent flagged him because last time he was going through something hard."*

**0:15** — Hold record button. Speak:
*"Just met Priya, partner at Sequoia, focused on consumer AI. Mentioned her team just hit a rough patch with their portfolio company. Has a daughter starting school next year. Seemed really sharp."*
Release. Watch transcript appear. Watch profile card animate in.

**0:40** — Tap "Brief me."
Read the brief out loud as it appears.

**0:55** — Tap "Draft email." Show the subject and body.
*"The agent wrote this using everything it knows about Priya — her situation, her focus, what she mentioned about her daughter. Not a template."*
Tap "Approve & Send."

**1:10** — Show the confirmation. Show the interaction logged.
*"That email just went from our agent's inbox directly to Priya. If she replies, the app knows and logs it as a new interaction automatically."*

**1:20** — *"The best relationship builders do all of this in their head or in spreadsheets. We built the agent version. On your iPhone. No servers."*

---

*Recall · Built with Claude, Whisper, Nozomio Nia, AgentMail · Runs entirely on iPhone*
