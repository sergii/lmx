# Product surfaces

## Telegram

Telegram is the primary real-time push surface.

Notify on:

- new high-action-priority opportunities
- newly discovered local/fast opportunities
- material changes to tracked postings
- reposts or reopenings
- compensation changes
- important application reminders or stage changes

A notification should be concise and link to the canonical LMX opening rather than forcing the user to understand source duplicates.

## Web application

The web application should expose the same canonical data in several representations.

### Kanban

Operational personal workflow. Suggested columns can evolve, but the model should support stages such as discovered, shortlist, apply, applied, recruiter contact, interview stages, offer, rejected, and archived.

Kanban state is personal state, not market state.

### List

A dense sortable representation for finding the strongest opportunities. Useful columns include Opportunity Score, Action Priority, company, role, compensation, source coverage, geography, age, repost count, and personal stage.

### Opening detail

Show the canonical opening, all known postings, historical snapshots, changes, source timeline, compensation observations, eligibility facts, score history, and personal application timeline.

### Analytics

Market, companies, compensation, skills, sources, geography, hiring velocity, vacancy lifetime, and reopen behavior.

## Manual entry

Manual input is a first-class ingestion path, not a fallback hack.

Support both:

- paste URL and extract automatically
- fully manual entry when no URL exists, for example a recruiter message

## External submissions

Expose an API so internal scripts, partners, bots, browser extensions, and agents can submit observations. API submissions enter the same inbox, command, provenance, event, and deduplication pipeline as every other source.

## Ranking

Maintain two independent scores:

- Opportunity Score: overall attractiveness of the opportunity.
- Action Priority: urgency and practical value of acting now.

Action Priority may consider freshness, source tier, application friction, current geographic eligibility, hiring funnel length, and likely speed to a real conversation.

Do not use nominal compensation as a hard rejection rule. Do not infer whether a role can coexist with another job. Record factual schedule and employment information and let the user decide.
