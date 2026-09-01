# Vision

LMX is a personal labor-market analytical center, not a vacancy bookmark list.

The system should answer both operational and historical questions:

- What relevant opportunities appeared recently?
- Which organizations are hiring now, and how frequently do they hire?
- How long does a vacancy remain visible?
- Does the same vacancy disappear and reopen later?
- Where else was the same underlying opening published, and when?
- How do listed compensation ranges move over time?
- Which sectors, technologies, locations, and seniority levels are growing or shrinking?
- Which sources publish the freshest or most actionable opportunities?
- Which opportunities best match the user right now?
- What has the user applied to, who replied, what stage is active, and what is the next action?

## Two views of the same world

LMX maintains two related but separate state machines:

- Market state: open, changed, disappeared, reappeared, closed, reopened.
- Personal state: discovered, saved, shortlisted, applied, recruiter contact, interview stages, offer, rejected, archived.

A vacancy can be open in the market while the user's application is already at a technical interview. These states must never be conflated.

## Near real-time behavior

Fresh discoveries and material changes should flow to Telegram with minimal delay. The web application provides the full context, list views, Kanban workflow, history, and analytics.

The long-term asset is the historical dataset. Even before the UI is complete, ingestion and event history should begin as early as possible.
