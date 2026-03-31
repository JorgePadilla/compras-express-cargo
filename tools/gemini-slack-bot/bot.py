"""
Gemini Auditor Slack Bot for Compras Express Cargo (CEC).

Listens for @mentions in #cec-agents and sends messages to
Google Gemini for code review, then posts the response back
to the Slack thread.

Usage:
    cp .env.example .env  # fill in your tokens
    pip install -r requirements.txt
    python bot.py
"""

import os
import re
import logging

from dotenv import load_dotenv
from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler
from google import genai

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

# --- Configuration -----------------------------------------------------------

SLACK_BOT_TOKEN = os.environ["SLACK_BOT_TOKEN"]
SLACK_APP_TOKEN = os.environ["SLACK_APP_TOKEN"]
GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

SYSTEM_PROMPT = """You are the code auditor for Compras Express Cargo (CEC), a Rails 8 + Hotwire + \
Tailwind CSS 4 cargo/shipping logistics system being built from scratch.

Your responsibilities:
1. **Security**: SQL injection, XSS, CSRF, mass assignment, auth bypass
2. **Rails conventions**: Follow Rails 8 patterns, proper use of Hotwire/Turbo
3. **Performance**: N+1 queries, missing indexes, inefficient scopes
4. **Test coverage**: Missing test cases, edge cases, sad paths
5. **Architecture**: Proper separation of concerns, service objects where needed
6. **Business logic**: Validate against CEC requirements (39 modules: clients, packages, invoicing, warehouses, etc.)
7. **I18n**: All user-facing text must support Spanish (primary) + English

Format your reviews with bullet points. Rate severity:
- 🔴 Critical — must fix before merge
- 🟡 Warning — should fix, potential issue
- 🟢 Suggestion — nice to have, improvement

Always end your review with one of:
- "APPROVED ✅" — code is ready to merge
- "CHANGES REQUESTED ❌" — list the specific items that must be addressed

Keep reviews concise and actionable. No fluff."""

# --- Initialize clients ------------------------------------------------------

app = App(token=SLACK_BOT_TOKEN)

client = genai.Client(api_key=GEMINI_API_KEY)

# --- Event handlers -----------------------------------------------------------


@app.event("app_mention")
def handle_mention(event, say):
    """Respond to @Gemini Auditor mentions with a Gemini-powered code review."""
    text = event.get("text", "")
    user = event.get("user", "unknown")
    thread_ts = event.get("thread_ts") or event.get("ts")
    channel = event.get("channel")

    # Strip the bot mention from the message text
    # Slack sends mentions as <@BOT_USER_ID>, remove it
    clean_text = re.sub(r"<@[A-Z0-9]+>", "", text).strip()

    if not clean_text:
        say(text="Please include a message or code for me to review!", thread_ts=thread_ts)
        return

    logger.info("Review requested by %s in %s: %s", user, channel, clean_text[:100])

    # Post a "thinking" message
    thinking = say(text="🔍 Reviewing... give me a moment.", thread_ts=thread_ts)

    try:
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=clean_text,
            config=genai.types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
            ),
        )
        review_text = response.text
    except Exception:
        logger.exception("Gemini API error")
        say(text="⚠️ Sorry, I couldn't complete the review. Gemini API error — check the logs.", thread_ts=thread_ts)
        return

    # Update the "thinking" message with the actual review
    try:
        app.client.chat_update(
            channel=channel,
            ts=thinking["ts"],
            text=review_text,
        )
    except Exception:
        # Fallback: post as a new message if update fails
        logger.exception("Failed to update thinking message, posting new one")
        say(text=review_text, thread_ts=thread_ts)

    logger.info("Review posted for %s (%d chars)", user, len(review_text))


@app.event("message")
def handle_message(event):
    """Required to prevent warnings for unhandled message events."""
    pass


# --- Main ---------------------------------------------------------------------

if __name__ == "__main__":
    logger.info("Starting Gemini Auditor bot (model: %s)...", GEMINI_MODEL)
    handler = SocketModeHandler(app, SLACK_APP_TOKEN)
    handler.start()
