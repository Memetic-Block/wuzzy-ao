# Wuzzy AO

A decentralized search engine built on AO (Actor Oriented) architecture, providing distributed web crawling and search capabilities on the Arweave ecosystem.

## Overview

Wuzzy AO consists of Lua processes that run on the AO network. Four core processes coordinate to enable decentralized web crawling, content indexing, and full-text search across the permaweb.

Check out the [documentation](https://docs_wuzzy.arweave.net) and the [Quickstart Guide](https://docs_wuzzy.arweave.net/guide/index.html).

## Architecture

The system is composed of four core processes plus a shared access control library:

### Processes

- **Nest** — Core indexing and storage process. Holds crawled documents and provides BM25-scored full-text search. Automatically trusts crawlers announced by the queue.
- **Nest Registry** — Directory of registered nest processes. Manages one-time registration codes (SHA2-512 hashed) and pushes registration/unregistration events to the queue.
- **Crawl Request Queue** — Coordination hub that deduplicates crawl work using a subscriber-based model (crawl once, deliver to many). Maintains an authoritative set of registered nests and distributes tasks to crawlers.
- **Crawler** — Hybrid process that claims work from the queue and fetches content. Supports two content source modes: *relay* (HyperBEAM on-chain fetch) and *oracle* (off-chain delivery). Delivers content directly to subscriber nests — content never flows through the queue.

### Shared

- **ACL** (`src/contracts/common/acl.lua`) — Role-based access control library used by all processes.

### Message Flow

```
Nest Registry                    Crawl Request Queue
  │  ▲                              ▲    │
  │  │ Register-Nest (on init)      │    │ Claim-Crawl-Request
  │  │                              │    ▼
  │  └──── Nest ──Request-Crawl──►  │  Crawler
  │                                 │    │
  └─ Notify-Nest-Registered ───────┘    │ Index-Document
                                         │ (direct to each subscriber nest)
                                         ▼
                                    Nest(s) — documents indexed
```

1. **Registration** — A nest self-registers with the registry on init using a one-time code. The registry notifies the queue, which adds the nest to its trusted set.
2. **Crawl request** — A nest forwards a `Request-Crawl` (Arweave TX-Id + Path) to the queue. The queue deduplicates: if the target is already queued or in-progress, it appends the nest as a subscriber.
3. **Fetch & deliver** — A crawler claims the next queued task, fetches content, and sends `Index-Document` directly to every subscriber nest. It then reports completion to the queue (status only, no content payload).

For detailed handler tables and data models, see [docs/architecture](docs/architecture).

## Features

- **Subscriber-based deduplication** — Multiple nests requesting the same target are collapsed into a single work item
- **BM25 full-text search** — Relevance-scored search across indexed documents
- **Dual content source modes** — Crawlers support HyperBEAM relay (on-chain) and off-chain oracle delivery
- **Registry-vouched trust** — Only registered nests can submit crawl requests
- **Automatic crawler trust** — Nests auto-grant `Index-Document` permission to crawlers endorsed by the queue
- **Role-based ACL** — Fine-grained permissions across all processes
- **Arweave archiving** — Crawled content is persisted on the permaweb
- **Read-only views** — Lightweight view modules for querying nest and registry state

## Getting Started

### Prerequisites

- Node.js (LTS)
- Arweave wallet (JWK)

### Installation

```bash
npm install
```

### Building

Bundle Lua source into loadable process files:

```bash
npm run bundle
```

Each process is bundled into `dist/<process-name>/process.lua`.

### Development Bootstrap

Spawn a linked nest-registry and crawl-request-queue for local development:

```bash
npm run bootstrap-dev
```

This outputs the process IDs you'll need to spawn nests and crawlers against.

### Deployment

Use the provided scripts to spawn and load processes:

```bash
# Spawn a new AO process
npx tsx scripts/spawn.ts

# Load bundled code into an existing process
npx tsx scripts/eval.ts
```

### Testing

Tests use Mocha + Chai (TypeScript):

```bash
npm test
```

## Scripts

| Script | Description |
|---|---|
| `scripts/bundle.ts` | Bundle Lua contracts into `dist/` |
| `scripts/spawn.ts` | Spawn a new AO process |
| `scripts/eval.ts` | Load bundled Lua code into a process |
| `scripts/bootstrap-dev.ts` | Bootstrap dev environment (registry + queue) |
| `scripts/publish.ts` | Publish bundled contract to Arweave |
| `scripts/publish-view.ts` | Publish view modules to Arweave |
| `scripts/generate-registration-code.ts` | Generate a registration code + SHA2-512 hash |
| `scripts/action-message.ts` | Send an action message to a process |

## Project Structure

```
src/
├── contracts/
│   ├── nest/                     # Indexing & search process
│   ├── nest-registry/            # Nest directory process
│   ├── crawl-request-queue/      # Work coordination process
│   ├── crawler/                  # Content fetching process
│   ├── common/acl.lua            # Shared access control
│   └── lib/                      # AO runtime & URL libraries
├── views/                        # Read-only view modules
└── experiments/                  # Experimental scripts
scripts/                          # Build & deployment tooling
operations/                       # Nomad job configs
docs/                             # Architecture documentation
```

## License

AGPLv3

## Related Projects

- [Wuzzy Site](https://github.com/memetic-block/wuzzy-site) — Frontend web application
- [Wuzzy Docs](https://github.com/memetic-block/wuzzy-docs) — Documentation site

## Support

- [Documentation](https://docs_wuzzy.arweave.net)
- [Open an issue](https://github.com/memetic-block/wuzzy-ao/issues)
