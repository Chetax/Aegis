# 🛡️ Aegis

**An AI companion that trains people to recognize and respond to scams — before they happen.**


---

## The Problem

Financial scams impersonating police, banks, and government officials have become a national crisis in India. The "digital arrest" scam alone has led authorities to block nearly 8 lakh SIM cards, and the Ministry of Home Affairs has publicly flagged it as a new and dangerous form of fraud. The Prime Minister has addressed it directly on national radio.

But awareness content — checklists, articles, warning videos — assumes two things the victim doesn't have in the moment: reading comprehension, and a calm mind. Neither is available when a stranger on the phone is manufacturing panic on purpose. The entire tactic is engineered to isolate the victim and stop them from thinking clearly before they can act.

The people most exposed to this — low-literacy users, first-time smartphone owners, non-English speakers, daily-wage workers, homemakers, the elderly — are also the people every existing safety tool ignores. Most awareness material is text-heavy, English-first, and delivered once, long before it's ever needed.

Knowing a list of red flags in advance does not prepare someone to stay calm and act correctly while they're being shouted at and told not to hang up. The real gap isn't information — it's the inability to **rehearse** the moment before it happens, and the lack of a calm, trusted voice to turn to **during** it.

## The Story Behind It

This isn't a hypothetical problem. It comes from a real, lived experience: a call claiming SIM misuse, escalated to a fake "officer," an instruction not to hang up, an accusation invented to create panic. It's a well-documented national pattern, not an isolated incident — thousands of similar cases are reported every month through India's official cybercrime channels. Anyone who's been on that call knows the fear is real even when, in hindsight, the trick is obvious. That's exactly the gap Aegis is built to close.

## The Solution

Aegis is a voice-first mobile companion that does two things no existing tool does together:

1. **Trains the response before the moment happens** — through daily bite-sized stories, active-recall quizzes, and a live roleplay sandbox where an AI plays the scammer and the user practices handling it, safely, in advance.
2. **Calmly guides the user through the real moment if it happens** — a single-button check-in where the user describes what's happening by voice, gets asked a few short clarifying questions, and receives a clear, conservative verdict plus a next step, grounded in real regulatory sources, not guesswork.

Everything works by voice, in Hindi or English, and there's no login required to start — just open the app and speak. Login is entirely optional, offered only if and when the user wants to save their streak and progress so it isn't lost if they change phones — never a gate to using the app.

## Value Addition

- **Trains behavior, not just awareness.** Nothing else on the market lets someone rehearse an actual scam call before facing one for real — this is the core differentiator, not a feature bolt-on.
- **Built for the audience everyone else ignores.** Voice-first and vernacular-first design serves low-literacy and first-time smartphone users directly, not as an accessibility afterthought.
- **Calm, sourced guidance in the actual moment of panic** — not a static article read days earlier, but live, conversational support when it's needed most.
- **Zero friction to start, progress that isn't lost.** No login is needed to begin using the app, and progress is saved locally by default — optional login exists purely to protect a user's streak/history if they get a new phone, never as a barrier to entry.
- **Works with or without connectivity** — a hybrid online/offline design means the tool doesn't fail exactly when a low-income user is most likely to have a weak signal.
- **Grounded in real, cited sources** — RBI advisories and the National Cyber Crime Reporting Portal, not invented legal facts, because getting this wrong is actively dangerous.
- **Genuinely a learning product** — active recall, roleplay practice, teach-back, and adaptive difficulty give it real pedagogical structure, not just a safety utility with a UI.

## Tech Stack

- **Mobile:** Flutter — voice input/output via device-native speech recognition and TTS, offline local caching, anonymous device-based identity by default
- **Backend:** FastAPI
- **AI reasoning:** Claude (via AWS Bedrock), orchestrated with LangGraph for the check-in and roleplay conversation flows
- **Knowledge retrieval:** RAG over a sourced, country-scoped rules dictionary (ChromaDB)
- **Offline fallback:** Lightweight quantized on-device model (LoRA fine-tuned) for when there's no connectivity
- **Storage:** PostgreSQL for progress/history, cached content for offline access; optional phone-number linkage for progress recovery across devices

## Scope Boundaries

- No real transaction-tracing or money-laundering mechanics.
- No content specific enough to double as a how-to for committing fraud — pattern-level recognition only.
- All legal/regulatory content is sourced from real, current advisories — nothing invented.

---

## Author

**Chetan Padhen** — Applied AI Engineer
[LinkedIn](https://linkedin.com/in/chetan-padhen-501416222) · [GitHub](https://github.com/Chetax)

Built for the [Nerdy AI Hackathon Challenge](https://hackathon.nerdy.com/) (Sep 2026).
