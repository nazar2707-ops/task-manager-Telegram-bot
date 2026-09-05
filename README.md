# Telegram → ClickUp AI Task Agent 📋

A Telegram bot + AI agent that turns voice and text messages from multiple people into structured ClickUp tasks, built with n8n, OpenAI, and Postgres.

## 🎯 Overview

Two people assign work to one executor. They dump tasks into a single Telegram bot — as text, as voice notes, as three messages in a row. The AI agent stitches the fragments together, splits them into discrete tasks, prioritises them, creates them in ClickUp (one list per author), and sends the executor a task card with one-tap status buttons and AI-generated execution hints.

When the executor needs clarification, they simply reply to the card. The bot relays the question to the task's author and routes the answer back — the executor never has to remember who asked for what.

## ✨ Features

- 🎙 **Voice + text intake** — voice notes transcribed with OpenAI Whisper
- 🧩 **Multi-message buffering** — collects fragments until the author says «готово», then parses them as one unit
- 🤖 **AI task extraction** — GPT splits free-form input into tasks with title, category, priority, due date
- 💡 **Execution hints** — the agent suggests how to approach each task at intake time
- 📁 **Per-author ClickUp lists** — tasks land in the right list, tagged by author
- 🔘 **Inline status buttons** — In progress / Done / Postponed, synced to ClickUp instantly
- 🔁 **Two-way Q&A relay** — executor replies to a card → question goes to the author → answer comes back, threaded
- 🗄 **Postgres state** — message buffers, task↔card mapping, open questions, conversation log

## 🏗 Architecture

```
Author A ──┐
           ├──► Telegram Bot ──► n8n Workflow
Author B ──┘                       │
                                   ├──► OpenAI Whisper   (voice → text)
                                   ├──► Postgres         (buffers, mappings, Q&A state)
                                   ├──► OpenAI GPT       (parse → tasks + hints)
                                   ├──► ClickUp API      (create / update tasks)
                                   └──► Telegram         (cards + buttons → Executor)
                                                               │
Executor ◄─────────────────────────────────────────────────────┘
   │  reply to card
   └──► question relayed to author ──► answer relayed back ──► ClickUp comment
```

## 🛠 Technology Stack

- **n8n Cloud** — orchestration (62 nodes, Code nodes for routing and state logic)
- **Telegram Bot API** — intake, cards, inline keyboards, reply threading
- **OpenAI Whisper** — voice transcription
- **OpenAI GPT-4o-mini** — task parsing, categorisation, hint generation (JSON mode)
- **Supabase Postgres** — persistent state (5 tables)
- **ClickUp API v2** — task creation, status updates, comments

## 📋 Key Workflows

### 1. Intake & Buffering
- Identifies the sender's role by `chat_id` (author / executor / unknown)
- Text goes straight to the buffer; voice is downloaded and transcribed first
- Buffer accumulates per author until the trigger word «готово»

### 2. AI Parsing
- Buffer is flushed into a single prompt with today's date
- GPT returns strict JSON: `tasks[] {title, description, category, priority, due_date, hints[]}`
- Handles one message containing several tasks, and several messages containing one task

### 3. ClickUp Sync
- Creates each task in the author's list with priority, due date and author tag
- Stores `task_id ↔ card_message_id ↔ author` mapping in Postgres
- Status buttons on the card update ClickUp via API

### 4. Q&A Relay
- Executor replies to a card → bot looks up the task and author → forwards the question
- Author replies → bot threads the answer back to the executor and logs it as a ClickUp comment
- Open questions tracked in Postgres so answers land on the right task

## 🎓 What This Demonstrates

- ✅ Multi-user Telegram bot design with role-based routing
- ✅ Stateful conversation handling with Postgres (not just LLM memory)
- ✅ Structured output from LLMs (JSON mode) driving real API calls
- ✅ Audio pipeline: Telegram file download → Whisper → text
- ✅ Bidirectional message relay with threading preserved on both ends
- ✅ Direct REST integration (ClickUp API v2) instead of relying on prebuilt nodes

## 💡 How It Works

1. Author sends a voice note: *«Найди двух водителей до пятницы, срочно. И ещё выставь квартиру в аренду»*
2. Bot transcribes it, buffers it, waits for «готово»
3. GPT splits it into two tasks: `Найти 2 водителей` (urgent, due Friday) and `Выставить квартиру в аренду` (normal)
4. Both appear in the author's ClickUp list; executor gets two cards with hints and buttons
5. Executor replies to the first card: *«Какая зарплата?»* → author receives the question → answers → executor sees the reply under the same card
6. Executor taps **Done** → ClickUp status updates

## 📈 Potential Improvements

- Silence-based auto-flush (timer) as an alternative to the trigger word
- Detect non-threaded replies from authors («40k, 6/1») and match them to open questions
- Daily digest of open tasks per author
- ClickUp → Telegram webhook so status changes made in ClickUp reflect on the card
- Multi-executor support

## 📝 Lessons Learned

- n8n expression fields break on nested `}}` — complex request bodies belong in a Code node
- Two Header Auth credentials look identical to the HTTP node; name them clearly and double-check every node
- Telegram `reply_to_message` is the cheapest reliable way to thread conversations — no parsing needed
- Whisper handles mixed Russian/English speech well enough that no language hint was required
- Keep state in a database from day one; workflow static data is not persisted in manual test runs

## 🤝 Team

- **Developer:** Nazar Seitkuliev
- **Users:** Two task authors, one executor (internal tool)

## 📧 Contact

- GitHub: [@nazar2707-ops](https://github.com/nazar2707-ops)
- Email: nazar2707@gmail.com

## 📝 License

Proprietary — internal tool

## 🎬 Credits

Powered by n8n, OpenAI, Supabase, and ClickUp
