# Gemini Auditor Slack Bot

AI-powered code reviewer for CEC that lives in `#cec-agents`. Works alongside Claude Code to provide automated code reviews using Google Gemini.

## Architecture

```
Claude Code (muscle) → Slack #cec-agents → Gemini Bot (auditor)
         ↑                                        │
         └────────── reads review ←────────────────┘
```

## Prerequisites

- Python 3.10+
- A Slack workspace with a bot app configured
- A Gemini API key from Google AI Studio

## Setup

### 1. Gemini API Key

1. Go to https://aistudio.google.com/
2. Sign in → Click **Get API Key** → Create key
3. Free tier: 15 RPM, 1M TPM, 1,500 req/day (Gemini 2.5 Flash)

### 2. Slack App

1. Go to https://api.slack.com/apps → **Create New App** → **From scratch**
2. Name: `Gemini Auditor`, select your workspace
3. Go to **OAuth & Permissions** → add Bot Token Scopes:
   - `chat:write`
   - `app_mentions:read`
   - `channels:history`
   - `channels:read`
4. Go to **Socket Mode** → Enable it → Generate an App-Level Token with `connections:write` scope
5. Go to **Event Subscriptions** → Enable → Subscribe to bot events:
   - `app_mention`
   - `message.channels`
6. **Install to Workspace** → Copy the Bot Token (`xoxb-...`)
7. Invite the bot to `#cec-agents`: `/invite @Gemini Auditor`

### 3. Environment Variables

```bash
cp .env.example .env
# Edit .env with your tokens:
# SLACK_BOT_TOKEN=xoxb-...
# SLACK_APP_TOKEN=xapp-...
# GEMINI_API_KEY=...
```

### 4. Install & Run

```bash
cd tools/gemini-slack-bot
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python bot.py
```

## Usage

In `#cec-agents`, mention the bot with code to review:

```
@Gemini Auditor Review this model:

class Package < ApplicationRecord
  belongs_to :client
  has_many :tasks
  validates :tracking, presence: true
  scope :pending, -> { where(status: 'pre_alerta') }
end
```

The bot will respond in a thread with a structured review including severity ratings and an approval/changes-requested verdict.

## Smoke Test

1. Start the bot: `python bot.py`
2. Post a message mentioning `@Gemini Auditor` with some Rails code
3. Verify the bot responds in the thread within ~10 seconds
4. Check that Claude Code can read the response via the Slack MCP
