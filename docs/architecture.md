# Wuzzy AO — Decentralized Crawl Architecture

## Overview

This document outlines the four core AO processes — **nest**, **nest-registry**, **crawl-request-queue**, and **crawler** — to minimize data and message duplication across the decentralized crawling system.

### Design Principles

- **Content never flows through the queue.** Crawlers deliver directly to nests; the queue only tracks coordination metadata.
- **Crawl once, deliver to many.** Multiple nests requesting the same Arweave target are collapsed into a single work item with a subscriber list.
- **Registry-vouched nests.** The nest-registry pushes registration/unregistration events to the crawl-request-queue, which maintains a `registered_nests` set. Only registry-vouched nests can submit crawl requests.
- **Automatic trust delegation.** Nests auto-grant `Index-Document` permission to crawlers endorsed by their configured queue — no manual ACL setup for nest operators.

### Control Model

| Process | Controlled by |
|---|---|
| Nest Registry | Us (admin) |
| Crawl Request Queue | Us (admin) — open to any nest for `Request-Crawl` |
| Crawler(s) | Us (admin) — hybrid: AO process + optional off-chain oracle |
| Nest(s) | Any user with a registration code |

---

## Process Contracts

### Nest (`src/contracts/nest/nest.lua`)

Core indexing/storage process. Holds crawled documents and provides BM25-ready aggregate stats.

**Init Tags:** `Nest-Registry`, `Registration-Code`, `Crawl-Request-Queue`

#### Handlers

| Action | Auth | Description |
|---|---|---|
| `Update-Roles` | owner/admin | Modify ACL roles |
| `View-Roles` | public | View ACL state |
| `Index-Document` | owner/admin/Index-Document | Upsert a document by normalized URL. Maintains running totals for BM25. |
| `Remove-Document` | owner/admin/Remove-Document | Remove a document, adjust aggregates |
| `Request-Crawl` | owner/admin/Request-Crawl | Accepts `TX-Id` + `Path` tags (or newline-separated TX-Ids in Data). Forwards to the configured crawl-request-queue. |
| `Crawl-Requested` | queue only | Response handler — auto-grants `Index-Document` role to all crawler IDs returned by the queue |

**Key behavior:**
- On init, self-registers with the configured `Nest-Registry` using a one-time `Registration-Code`.
- Documents are deduplicated by normalized URL (`protocol://domain/path`).
- When `Crawl-Requested` arrives from the queue, the nest automatically trusts the listed crawlers — third-party nest operators never need to manually configure crawler permissions.

---

### Nest Registry (`src/contracts/nest-registry/nest-registry.lua`)

Directory of registered nest processes. Pushes registration/unregistration events to the crawl-request-queue so it can maintain an authoritative set of valid nests.

**Init Tags:** `Crawl-Request-Queue`

#### Handlers

| Action | Auth | Description |
|---|---|---|
| `Toggle-Registration-Code` | owner/admin | Enable/disable code requirement |
| `Add-Registration-Code` | owner/admin | Store SHA2-512 hash of a registration secret |
| `Remove-Registration-Code` | owner/admin | Remove a code hash |
| `List-Registration-Codes` | public | List stored hashes |
| `Register-Nest` | any (valid code) | Validate code, insert nest, burn code. **Sends `Notify-Nest-Registered` to queue.** |
| `Unregister` | nest process | Self-remove. **Sends `Notify-Nest-Unregistered` to queue.** |
| `Batch-Unregister` | owner/admin | Remove multiple nests. **Sends `Notify-Nest-Unregistered` (batch) to queue.** |
| `Update-Registration` | nest process | Update own owner/ACL |
| `List-Nests` | public | Paginated listing with optional owner filter |
| `List-Nests-By-Address` | public | Nests where address is owner or has ACL role |
| `Set-Crawl-Request-Queue` | owner/admin | **New.** Set/update the queue process ID. Syncs all existing nests to the new queue. |
| `View-State` | public | Full registry state |

---

### Crawl Request Queue (`src/contracts/crawl-request-queue/crawl-request-queue.lua`)

Coordination hub that deduplicates crawl work by Arweave TX ID and distributes tasks to crawlers. Maintains an authoritative set of registered nests (populated by the nest-registry via notifications) and only accepts crawl requests from vouched nests.

**Init Tags:** `Nest-Registry`

**Key data model change:** Replaced per-nest-per-URL entries with a subscriber-based model:

```lua
CrawlRequest = {
  canonical_id  -- tx_id + path (dedup key)
  tx_id         -- Arweave transaction ID
  path          -- Path within manifest
  subscribers   -- [{ nest_id, requested_by, requested_at }]
  assigned_to   -- crawler process ID (when claimed)
  claimed_at    -- timestamp
  completed_at  -- timestamp
  retries       -- auto-retry count
  error         -- last error message
  status        -- "queued" | "in_progress" | "completed" | "failed"
}
```

An O(1) lookup table (`crawl_index[canonical_id] → array index`) prevents scanning on dedup checks.

#### Handlers

| Action | Auth | Description |
|---|---|---|
| `Update-Roles` | owner/admin | Modify ACL |
| `View-Roles` | public | View ACL |
| `Add-Crawler` | owner/admin | Register a crawler process |
| `Remove-Crawler` | owner/admin | Unregister a crawler |
| `List-Crawlers` | public | Returns registered crawler IDs |
| `Notify-Nest-Registered` | nest-registry only | **New.** Adds a nest ID to the `registered_nests` set. Only accepted from the configured `nest_registry`. |
| `Notify-Nest-Unregistered` | nest-registry only | **New.** Removes nest IDs from `registered_nests`. Accepts JSON array of IDs in Data. |
| `Request-Crawl` | **registered nests** | Only vouched nests (in `registered_nests`) can submit. Accepts `TX-Id` + `Path` tags. Deduplicates: if queued/in-progress, appends subscriber; if completed and old enough, re-queues; if failed, resets. Returns crawler IDs in response. |
| `Claim-Crawl-Request` | registered crawlers | FIFO claim of first queued request. Returns full task including subscriber list. |
| `Complete-Crawl-Request` | assigned crawler | Marks request completed. No content payload — status only. |
| `Fail-Crawl-Request` | assigned crawler | Reports failure. Auto-requeues up to `MAX_RETRIES` (default 3), then marks permanently failed. |
| `Reclaim-Stale` | owner/admin | Reset stuck in-progress requests back to queued |
| `View-State` | public | Full queue state including config constants |

**Configuration:**

| Constant | Default | Description |
|---|---|---|
| `STALE_TIMEOUT` | 5 minutes | Timeout before reclaiming stuck jobs |
| `MAX_RETRIES` | 3 | Auto-retry limit before permanent failure |
| `RECRAWL_AFTER` | 24 hours | Minimum age of completed entry before re-crawl |

---

### Crawler (`src/contracts/crawler/crawler.lua`) — **New**

Hybrid AO process that claims work from the queue and fetches content.

**Init Tags:** `Crawl-Request-Queue`, `Content-Source` (`"relay"` or `"oracle"`)

#### Content Source Modes

| Mode | Mechanism |
|---|---|
| `relay` | Uses HyperBEAM relay device (`Send({ device = 'relay@1.0', ... })`) for on-chain content fetch |
| `oracle` | Waits for an off-chain process to deliver content via `Deliver-Content` handler |

The crawler can be switched between modes at runtime via `Configure`.

#### Handlers

| Action | Auth | Description |
|---|---|---|
| `Update-Roles` | owner/admin | ACL management |
| `View-Roles` | public | View ACL |
| `Configure` | owner/admin | Set `Crawl-Request-Queue`, `Content-Source` at runtime |
| `Poll` | owner/admin/Poll | Triggered externally. Sends `Claim-Crawl-Request` to queue. No-ops if already busy. |
| `Crawl-Request-Claimed` | queue only | Stores task, initiates content fetch (relay sends immediately; oracle waits) |
| `No-Crawl-Requests` | queue only | Queue empty — idle |
| `Deliver-Content` | owner/admin/Oracle (oracle mode) | Receives content, sends `Index-Document` **directly to each subscriber nest**, then sends `Complete-Crawl-Request` to queue |
| `Content-Failed` | owner/admin/Oracle | Reports failure to queue, clears task |
| `View-State` | public | Current state including active task |

---

## Message Flow

```
                    ┌──────────────────┐
                    │  Nest Registry   │
                    └──┬───────▲───────┘
    Notify-Nest-*      │       │ Register-Nest (on init)
    (register/unreg)   │       │
        ┌──────────────┘       │
        │                      │
┌───────▼──────┐  ┌────────────┴───────────────┐
│  Nest Owner  │  │   Crawl Request Queue      │
│ Request-Crawl│  │  (dedup + coordinate)      │
└──────┬───────┘  │  registered_nests = {...}  ◀────────┐
       │          └───────────▲──────────────▲─┘        │
       │                      │              │          │
┌──────▼──────┐         Claim-Crawl-Request  │          │
│    Nest     │               │              │          │
│ (forwards)  │──Request-Crawl─────(validated against   │
└──────┬──────┘               │    registered_nests)    │
       │                      │                         │
  Crawl-Requested       ┌─────┴────────────┐            │
  (auto-trust)          │    Crawler       │            │
       │                │ (fetch content)  │            │
       │◀───────────────┤                  │            │
       │  Index-Document└────────┬─────────┘            │
       │  (direct)               │                      │
       ▼                 Complete-Crawl-Request─────────┘
 Documents indexed       (status only, no content)
```

### Detailed sequence steps:

**Registration (one-time setup):**
1. **Nest** sends `Register-Nest` to the **nest-registry** (on init, with registration code)
2. **Nest-registry** validates code, inserts nest, burns code
3. **Nest-registry** sends `Notify-Nest-Registered` to the **crawl-request-queue**
4. **Queue** adds the nest ID to `registered_nests`

**Crawl request flow:**
1. **Nest owner** sends `Request-Crawl` (TX-Id + Path) to their **nest**
2. **Nest** forwards `Request-Crawl` to the configured **crawl-request-queue** (sender = nest process ID)
3. **Queue** validates `msg.From` is in `registered_nests`, then deduplicates by `canonical_id`:
   - New: creates entry with nest as subscriber
   - Existing queued/in-progress: appends nest to subscribers
   - Completed (recent): returns `Crawl-Already-Completed`
   - Completed (stale) or failed: resets to queued
4. **Queue** responds with `Crawl-Requested` containing registered crawler IDs
5. **Nest** auto-grants `Index-Document` role to each crawler ID
6. **Polling script** sends `Poll` to a **crawler**
7. **Crawler** sends `Claim-Crawl-Request` to the queue
8. **Queue** assigns the first queued request, responds with full task + subscriber list
9. **Crawler** fetches content (relay device or oracle)
10. **Crawler** sends `Index-Document` **directly** to each subscriber nest (content in `Data`)
11. **Crawler** sends `Complete-Crawl-Request` to the queue (status only — no content)
12. If fetch fails: **crawler** sends `Fail-Crawl-Request` → queue auto-requeues (up to 3 retries)

**Unregistration:**
1. **Nest** sends `Unregister` to the **nest-registry** (or admin uses `Batch-Unregister`)
2. **Nest-registry** removes nest(s), sends `Notify-Nest-Unregistered` (array) to the **queue**
3. **Queue** removes the nest ID(s) from `registered_nests`

### Message count comparison

| Scenario: 3 nests request same URL | Before (per-URL-per-nest) | After (subscriber model) |
|---|---|---|
| Queue entries created | 3 | 1 |
| Crawl fetches | 3 | 1 |
| Index-Document messages | 3 | 3 (unavoidable — each nest needs content) |
| Content through queue | 3× (payload in claim response) | 0 (direct delivery) |
| Total messages | ~12 | ~8 |

---

## Files Changed

| File | Change |
|---|---|
| `src/contracts/crawl-request-queue/crawl-request-queue.lua` | Rewritten — subscriber-based dedup model, `registered_nests` validation, nest-registry notification handlers, Complete/Fail/List-Crawlers/View-State handlers |
| `src/contracts/nest/nest.lua` | Added `crawl_request_queue` config, `Request-Crawl` forwarding, `Crawl-Requested` auto-trust handler |
| `src/contracts/crawler/crawler.lua` | **New file** — hybrid crawler with relay/oracle modes |
| `src/contracts/nest-registry/nest-registry.lua` | Added `crawl_request_queue` config, `Set-Crawl-Request-Queue` handler, nest register/unregister notifications to queue |
| `src/contracts/common/acl.lua` | Unchanged |
| `scripts/bundle.ts` | Added `crawl-request-queue` and `crawler` to bundle list |
