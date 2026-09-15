# 🛡️ Aegis

**An AI companion that trains people to recognize and respond to scams — before they happen.**



https://github.com/user-attachments/assets/5d37d110-3799-44e2-8156-1961af60b206



---

## The Problem

Financial scams impersonating police, banks, and government officials have become a national crisis in India. The "digital arrest" scam alone has led authorities to block nearly 8 lakh SIM cards, and the Ministry of Home Affairs has publicly flagged it as a new and dangerous form of fraud. The Prime Minister has addressed it directly on national radio.

But awareness content — checklists, articles, warning videos — assumes two things the victim doesn't have in the moment: reading comprehension, and a calm mind. Neither is available when a stranger on the phone is manufacturing panic on purpose. The entire tactic is engineered to isolate the victim and stop them from thinking clearly before they can act.

The people most exposed to this — low-literacy users, first-time smartphone owners, non-English speakers, daily-wage workers, homemakers, the elderly — are also the people every existing safety tool ignores. Most awareness material is text-heavy, English-first, and delivered once, long before it's ever needed.

Knowing a list of red flags in advance does not prepare someone to stay calm and act correctly while they're being shouted at and told not to hang up. The real gap isn't information — it's the inability to **think clearly in the moment**, and the lack of a calm, trusted voice to turn to **while it's happening**.

## The Story Behind It

This isn't a hypothetical problem. It comes from a real, lived experience: a call claiming SIM misuse, escalated to a fake "officer," an instruction not to hang up, an accusation invented to create panic. It's a well-documented national pattern, not an isolated incident — thousands of similar cases are reported every month through India's official cybercrime channels. Anyone who's been on that call knows the fear is real even when, in hindsight, the trick is obvious. That's exactly the gap Aegis is built to close.

## The Solution

Aegis is a voice-first mobile companion built around two things working together:

1. **A real-time "should I do this?" check-in** — a single button. The user describes what's happening by voice, Aegis asks a few short clarifying questions, and gives a clear, conservative verdict plus a next step, grounded in real regulatory sources, not guesswork.
2. **Teach-back** — right after the verdict, the user explains in their own words *why* the situation was risky. Aegis checks their reasoning and gently corrects it if needed. This is the actual learning moment — the user isn't just told an answer, they have to reconstruct it themselves, on a real situation they were genuinely unsure about.

Around that core, daily bite-sized stories and active-recall quizzes build pattern recognition before anything ever happens for real, and a plain-language rules dictionary — with direct links to independently verify a caller's claims against real government tools — is always available to browse or search directly.

Everything works by voice, in Hindi or English, and there's no login required to start — just open the app and speak. Login is entirely optional, offered only if and when the user wants to save their streak and progress so it isn't lost if they change phones — never a gate to using the app.

## Feature Priorities

Not every idea here gets equal build time — prioritized against the hackathon's actual "genuinely helps someone learn" brief, and against what's provably useful versus merely plausible-sounding.

| Feature | Priority | Build Status |
|---|---|---|
| Real-time "should I do this?" check-in | **Core — build first** | ✅ Done — voice-first check-in graph, verdict + reporting flow, verified end-to-end |
| Teach-back after check-in | **Core — build first** (flagship learning mechanic) | ✅ Done — graded, XP-linked, verified |
| Rules & regulations dictionary | **Core — build first** (grounds everything else) | ✅ Done — standalone browsable screen (expandable rule cards with source citations, emergency reporting banner, universal fallback patterns), plus powers the check-in's RAG retrieval |
| Daily voice-first scam story | **Build early** | ✅ Done — narrated (AWS Polly, neural voice), English content verified; Hindi story content not yet generated |
| "Spot the red flag" mini-quiz | **Build early** | ✅ Done |
| Progress tracking (XP, streaks, daily/weekly history) | **Build if time permits** | ✅ Done, ahead of plan — local + DynamoDB-backed, streaks/longest-streak/weekly-monthly breakdown |
| "Verify This Yourself" — real government tools (Sanchar Saathi/TAFCOP, UIDAI) to independently check claims made in a scam call | **Build if time permits** | ✅ Done, ahead of plan — added to the rules dictionary screen, linking out to Sanchar Saathi/TAFCOP and UIDAI's official portals |
| Adaptive story/quiz selection (spaced repetition) | **Build if time permits** | ⬜ Not started |
| Additional prompt-injection defense layer (AWS Bedrock Guardrails) | **Stretch** | ⬜ Not started |
| Trusted-contact escalation | **Stretch** | ⬜ Not started |
| Hybrid online/offline AI | **Stretch** | ⬜ Not started |
| Practice scam call (roleplay sandbox) | **Backlog — build last, only if time allows, and validated with a real test user first.** Simulated-attack engagement is a known problem in phishing-training research: people behave differently once they know it's a test, real or not. Worth testing on a real person before trusting it as a core feature rather than assuming it works. | ⬜ Not started |

## Value Addition

- **Trains reasoning in the real moment, not just recognition in advance.** Teach-back forces the user to articulate *why* something was risky right after a genuine moment of uncertainty — this is the core differentiator, not a feature bolt-on.
- **Built for the audience everyone else ignores.** Voice-first and vernacular-first design serves low-literacy and first-time smartphone users directly, not as an accessibility afterthought.
- **Calm, sourced guidance in the actual moment of panic** — not a static article read days earlier, but live, conversational support when it's needed most.
- **Zero friction to start, progress that isn't lost.** No login is needed to begin using the app, and progress is saved locally by default — optional login exists purely to protect a user's streak/history if they get a new phone, never as a barrier to entry.
- **Works with or without connectivity** — a hybrid online/offline design means the tool doesn't fail exactly when a low-income user is most likely to have a weak signal.
- **Grounded in real, cited sources** — RBI advisories and the National Cyber Crime Reporting Portal, not invented legal facts, because getting this wrong is actively dangerous.
- **Doesn't ask the user to just trust it.** The "Verify This Yourself" links let anyone independently check a caller's claims (a number, an Aadhaar link) against the real government source, rather than take Aegis's word for it either.
- **Genuinely a learning product** — active recall, teach-back, and adaptive difficulty give it real pedagogical structure, not just a safety utility with a UI.

## Tech Stack

- **Mobile:** Flutter — voice input via device-native speech recognition, voice output via AWS Polly (neural bilingual Hindi/Indian-English voice), anonymous device-based identity by default
- **Backend:** FastAPI
- **AI reasoning:** Claude (via AWS Bedrock), orchestrated with LangGraph for the check-in and teach-back conversation flows
- **Knowledge retrieval:** RAG over a sourced, country-scoped rules dictionary (ChromaDB)
- **Voice synthesis:** AWS Polly (Kajal neural voice — bilingual Hindi + Indian English)
- **Storage:** DynamoDB for progress/history (XP, streaks, daily activity), local on-device caching as the primary read path so the app never depends on network availability for its own numbers
- **Planned, not yet built:** offline fallback via a lightweight quantized on-device model (LoRA fine-tuned) for no-connectivity use; optional login/phone-number linkage for cross-device progress recovery

## Scope Boundaries

- No real transaction-tracing or money-laundering mechanics.
- No content specific enough to double as a how-to for committing fraud — pattern-level recognition only.
- All legal/regulatory content is sourced from real, current advisories — nothing invented.

---

## Author

**Chetan Padhen** — Applied AI Engineer
[LinkedIn](https://linkedin.com/in/chetan-padhen-501416222) · [GitHub](https://github.com/Chetax)

Built for the [Nerdy AI Hackathon Challenge](https://hackathon.nerdy.com/) (Sep 2026).