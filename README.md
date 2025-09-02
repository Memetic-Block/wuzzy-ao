# Wuzzy AO

A decentralized search engine built on AO (Actor Oriented) architecture, providing distributed web crawling and search capabilities on the Arweave ecosystem.

## Overview

Wuzzy AO consists of smart contracts (processes) written in Lua that run on the AO network. The system enables decentralized web crawling, content indexing, and search functionality through a network of autonomous processes.

Take a look at the [documentation](https://docs_wuzzy.arweave.net)!

## Architecture

The system is composed of several core components:

### Core Contracts

- **WuzzyCrawler** (`wuzzy-crawler`): Autonomous web crawling processes that fetch and parse web content
- **WuzzyNest** (`wuzzy-nest`): Central indexing and search processes that store and query crawled content
- **WuzzyNestRegistry** (`wuzzy-nest-registry`): (Optional) Registry for tracking nests

## Features

- **Decentralized Crawling**: Distributed web crawlers that can be spawned and managed independently
- **Content Indexing**: Full-text search indexing with BM25 scoring algorithm
- **Access Control**: Fine-grained permissions system for process interactions
- **Content Storage**: Automatically archives crawled site content on Arweave
- **Search API**: Query interface for searching indexed content

## Getting Started

### Prerequisites

- Node.js 22+
- AO CLI tools
- Arweave wallet
- Lua 5.3 & busted (for spec tests)

### Quickstart Guide
Check out the [Wuzzy Docs Quickstart Guide](https://docs_wuzzy.arweave.net/guide/index.html)

### Installation

```bash
# Install dependencies
npm install

# Bundle Lua process code
npm run bundle

# Run tests (requires Lua 5.3 & busted)
npm test
```

### Building Contracts

The bundle script bundles Lua source code for convenient loading into an AO process:

```bash
# Bundle Lua files
npm run bundle
```

Each process will be bundled into the `dist` directory under its name and called `process.lua`.  For example: `dist/wuzzy-nest/process.lua`

### Deployment

Deploy contracts to the AO network with the AOS CLI. For example, to deploy a Wuzzy Nest:

```bash
aos my-process-name --url https://some.hyperbeam.node
```
```bash
.load dist/wuzzy-nest/process.lua
```

## Contract Details

Check out the [Wuzzy API Docs](https://docs_wuzzy.arweave.net/api/index.html)

### WuzzyCrawler

The crawler process is responsible for:
- Accepting crawl requests from authorized sources
- Fetching web content from specified URLs
- Parsing HTML content and extracting metadata
- Submitting parsed content to associated nest processes

**Key Features:**
- URL validation and normalization
- HTML parsing with metadata extraction
- Rate limiting and queue management
- Content type detection
- Error handling and retry logic

### WuzzyNest

The nest process provides:
- Content indexing and storage
- Full-text search capabilities
- Document management
- Crawler registration and management

**Search Algorithms:**
- Simple text matching
- BM25 relevance scoring
- Content-based ranking

### WuzzyNestRegistry

Manages relationships between:
- Nest processes and their associated crawlers
- Access permissions and ownership
- Process discovery and routing

## Development

### Project Structure

```
src/
├── contracts/          # Main contract implementations
│   ├── wuzzy-crawler/  # Crawler contract
│   ├── wuzzy-nest/     # Search and indexing contract
│   ├── wuzzy-nest-registry/ # Registry contract
│   └── common/         # Shared utilities
├── lib/                # External libraries
└── views/              # Contract view modules

scripts/                # Build and deployment scripts
├── build.ts           # WASM compilation
├── bundle.ts          # Lua bundling
├── publish.ts         # Contract publishing
└── util/              # Utility functions

spec/                   # Test specifications
test/                   # Test utilities and fixtures
```

### Testing

Tests are written in Lua using the Busted framework:

```bash
# Run all tests
npm test

# Run specific test suites
busted spec/wuzzy-crawler/
busted spec/wuzzy-nest/
```

### Code Style

- Follow Lua best practices
- Use type annotations in comments
- Maintain consistent indentation
- Include comprehensive error handling

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

AGPLv3 License - see LICENSE file for details

## Related Projects

- [Wuzzy Site Repo](https://github.com/memetic-block/wuzzy-site) - Frontend web application
- [Wuzzy Docs Repo](https://github.com/memetic-block/wuzzy-docs) - Documentation site

## Support

For questions and support:
- Check the [documentation](https://docs_wuzzy.arweave.net)
- Open an issue on GitHub
- Contact the development team

---

Built with ❤️ for the decentralized web
