# CLAUDE.md — contract for AI coding sessions

Autonomous Russian-language **private** Telegram channel (the owner's own journalistic use) about rising OSINT tools,
techniques, investigations, leaks and platform changes. Sister project of `vibe-radar` (forked from it on 2026-11-01,
same stack and conventions) and `russia-nato-monitor`. Owner is a non-developer; optimise for correctness,
traceability, €0 running cost and being understandable by one person. Product docs: `README.md` (Russian);
editorial rules: `prompts/system.md`.

## Stack and conventions

- Node 24, TypeScript run **directly** by Node (type stripping) — no build step. Only erasable syntax:
  no `enum`, no constructor parameter properties, no namespaces. Relative imports end in `.ts`.
- SQLite via `node:sqlite` (`src/db.ts`). Migrations are an append-only array; never edit an existing one.
- Gemini over REST (`src/llm.ts`, shared with russia-nato-monitor and vibe-radar): model chain with fallback on quota,
  per-run / per-day caps in `llm_usage`, optional capped paid editor key. Every LLM output is zod-validated.
- Config only through `src/config.ts`. Logs are NDJSON; the logger redacts bot tokens.

## Pipeline (src/cycle.ts)

collect (`pipeline/collect.ts`, `collectors/*`) → refresh tracked repos → `candidates.ts` (group by project,
deltas from `snapshots`, pre-rank) → `scan.ts` (model verdicts) → `editorial.ts` (code thresholds, write,
check, queue) → `digest.ts` (daily, after DIGEST_HOUR_LOCAL) → `publish.ts` (Telegram queue) → prune.

Differences from vibe-radar:
- Topic filter is `looksOnTopic` (OSINT keywords) in `projects.ts`.
- **Stories** (`story:host/path`, `storyKeyOf`): an on-topic Reddit/HN thread, or an article from a source with
  `config.standalone: true`, that points at no repo/site is a candidate of its own (OSINT methods often have no repo).
  Stories get +1 pre-score when from a blog, more text in scan input, and their text goes to the writer.
- Velocity scales and anomaly thresholds are lowered for the niche (`preScore`, `ANOMALY_*`).
- Platform `mastodon` (tag RSS feeds; context only). RSS items without a title use their opening words.

## Editorial invariants (do not weaken without the owner's say)

- Velocity comes only from measured counters (`metrics.ts`); never extrapolated.
- No figure in a published text that is not in collected data (±5%) — `textcheck.unknownFigures`. For stories the
  collected article text counts as data; for repos only counters do.
- No link in a published text that collectors did not see — `editorial.allowedLinks` (model URLs are untrusted).
- Post thresholds are re-checked in code (`postDecision`); a repeat needs ≥3× growth or news after a cooldown.
- Owner's decisions (2026-11-01): the channel is private and for own use, so leaks, data-broker/"пробив" services,
  stalkerware and dual-use tools are in scope, and links to leaks are allowed when collectors saw them. The one rule
  kept: personal data of private individuals is not reprinted into post text — the post links to the source.
- Telegram delivery: `sending` is committed before the request; ambiguous outcomes become `uncertain`, never auto-retried.

## Scheduling

GitHub fired the hourly schedule only every 7–8 h (2026-11-01…03), so `radar.yml` runs one job for ~5.5 h with a
cycle every hour (state saved after each, `scripts/save-state.sh`); queued triggers start the next job. A digest
missed in the evening is sent the next morning until `DIGEST_CATCHUP_UNTIL_HOUR`. Anything from a `focused` source
gets one scan even without measured velocity (`candidates.ts`, `curated`). The repo must stay public (minutes).

## Commands

| Command | What |
|---|---|
| `npm run cycle` | one full cycle (what Actions runs hourly) |
| `node src/cli.ts collect [key…]` | collect all or some sources |
| `node src/cli.ts sources` | per-source items / failures |
| `node src/cli.ts candidates [n]` | what the next scan would see |
| `node src/cli.ts projects` | latest verdicts |
| `npm run posts -- 10` | latest generated texts |
| `node src/cli.ts prompt scan` | the filled system prompt |
| `node scripts/sql.ts "SELECT …"` | read-only ad-hoc query (`DATABASE_PATH=data/radar.db`) |
| `npm run check` | typecheck + tests — must pass before a commit |

## When you change things

- Prompt changes: bump `SCAN_VERSION` in `pipeline/scan.ts` and look at real output (`scan`, `posts-queue`, `posts`).
- New source: add to `config/sources.yaml`, check it with `node src/cli.ts collect <key>` + `sources`. Quote any
  `name` containing ` #` (YAML comment). Reddit cannot be checked from a home IP (403/429) — only from Actions.
- Thresholds (`ANOMALY_*`, `preScore` divisors) are first guesses for the OSINT niche (2026-11-01); recalibrate
  from a week of real data, not from intuition. The owner wants a steady practitioner's feed, not only viral hits:
  `POST_THRESHOLD` 5 and up to 16 posts/day (at 7 only 1 of 44 candidates qualified). The prompt reads the
  thresholds from config (`{{POST_THRESHOLD}}` etc.), so change them in one place.
- Bumping `SCAN_VERSION` makes `buildCandidates` redo older verdicts, bypassing the rescan throttles.
- Reddit: subreddits are combined per request (`r/a+b+c`) and only one Reddit source is fetched per run
  (`HOST_SOURCES_PER_RUN`, least recently fetched first) — a second request from an Actions IP draws 429.
