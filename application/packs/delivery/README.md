# Delivery

Delivery owns outbound notification policy and transport formatting. It does not scrape domain tables. Telegram messages are consumed from transactional Outbox records emitted by owning bounded contexts.

## Telegram near-real-time policy

`Delivery::Telegram::NotificationPolicy` evaluates the active LMX profile rather than hard-coding source names. The default profile currently selects:

- `new_local_fast_opportunity` for sources whose configured profile lane is `local_fast`;
- `high_action_priority` at the profile's `action_priority_threshold`;
- `material_posting_change`;
- `compensation_change`;
- `repost_or_reopen`.

Market Catalog attaches objective `change_kinds` to posting integration messages. Delivery combines those facts with profile policy to decide whether a Telegram request should actually be sent.

Suppressed messages are terminally marked published in the Outbox. Transport failures are marked failed with a retry time, so publisher retries remain safe and observable without re-querying domain state.

## Canonical opening links

When an event contains `job_opening_id` and `LMX_PUBLIC_BASE_URL` is configured, Telegram links to:

```text
<LMX_PUBLIC_BASE_URL>/openings/<job_opening_id>
```

If no canonical opening or public base URL is available yet, formatting falls back to the source posting/application URL. Staging derives `LMX_PUBLIC_BASE_URL` from `LMX_STAGING_HOSTNAME`.
