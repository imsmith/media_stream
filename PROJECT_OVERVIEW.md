# MediaStream - Project Overview

Complete documentation and testing suite for the MediaStream audio player application.

## Table of Contents

- [Project Description](#project-description)
- [Documentation Structure](#documentation-structure)
- [Testing Suite](#testing-suite)
- [Quick Start](#quick-start)
- [Directory Layout](#directory-layout)

## Project Description

MediaStream is a Phoenix LiveView application for streaming audio files with real-time multi-device synchronization. It provides a complete music player experience with library management, playback controls, and listening history tracking.

### Key Features

- 🎵 **Audio Playback** - Full transport controls with queue management
- 📁 **Library Management** - Directory scanning and M3U/M3U8 playlist support
- 📊 **Listening History** - Track what you've played with analytics
- 🔄 **Real-Time Sync** - Multi-tab synchronization via Phoenix PubSub
- 💾 **State Persistence** - Resume playback across sessions
- 🎯 **HTTP Range Requests** - Efficient seeking with byte-range support

### Technology Stack

- **Framework**: Phoenix 1.8 with LiveView 1.1
- **Database**: SQLite via Ecto SQLite3
- **Web Server**: Bandit 1.5
- **Frontend**: Tailwind CSS, esbuild
- **Real-time**: Phoenix PubSub

## Documentation Structure

### Architecture Documentation ([arch/](arch/))

Comprehensive technical documentation using industry standards:

#### Data Models ([arch/data_models/](arch/data_models/))

YANG (RFC 7950) specifications for all database schemas:

- **audio_file.yang** - Media library files
- **playback_state.yang** - Per-device playback state
- **listening_history.yang** - Session tracking

**Total**: 3 YANG data models

#### Action Models ([arch/action_models/](arch/action_models/))

YANG RPC specifications for all operations:

- **playback_actions.yang** - 11 playback operations
- **library_actions.yang** - 7 library operations
- **history_actions.yang** - 7 history operations

**Total**: 25 documented operations

#### Diagrams ([arch/diagrams/](arch/diagrams/))

Mermaid visualizations:

- **data_relationships.mmd** - Entity-relationship diagram
- **system_architecture.mmd** - Component architecture
- **pubsub_flow.mmd** - Real-time sync sequence
- **streaming_sequence.mmd** - HTTP range request flow

**Total**: 4 architecture diagrams

#### Features ([arch/features/](arch/features/))

Detailed feature documentation:

- **playback.md** - Audio playback and controls
- **library_management.md** - Library operations
- **listening_history.md** - History tracking
- **real_time_sync.md** - Multi-device sync

**Total**: 4 comprehensive feature docs

### High-Level Documentation

- **[CLAUDE.md](CLAUDE.md)** - Quick reference for Claude Code
- **[README.md](README.md)** - Project readme
- **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)** - This file

## Testing Suite

### Acceptance Tests ([tests/acceptance/](tests/acceptance/))

Gherkin/BDD acceptance tests covering all features:

- **playback.feature** - 28 scenarios for audio playback
- **library_management.feature** - 35 scenarios for library operations
- **listening_history.feature** - 34 scenarios for history tracking
- **real_time_sync.feature** - 37 scenarios for synchronization

**Statistics**:

- **Total Files**: 5 (4 features + README)
- **Total Lines**: 1,154 lines of Gherkin
- **Total Scenarios**: 134 acceptance tests
- **Coverage**: All major features and edge cases

### Test Categories

Each feature file covers:

- ✅ Happy path scenarios
- ✅ Error handling
- ✅ Edge cases
- ✅ Performance scenarios
- ✅ User workflows
- ✅ Integration scenarios

### Implementation Ready

Tests are ready to be implemented with:

- **White Bread** - Gherkin for Elixir
- **Cabbage** - Pure Elixir BDD
- **ExUnit** - Direct implementation with examples provided

## Quick Start

### Documentation

#### View Architecture Docs

```bash
# Start with system overview
cat arch/README.md

# View data models
cat arch/data_models/README.md
cat arch/data_models/audio_file.yang

# View diagrams (GitHub renders Mermaid automatically)
# Or use Mermaid CLI
cd arch/diagrams
mmdc -i system_architecture.mmd -o system_architecture.png

# Read feature docs
cat arch/features/playback.md
```

#### Validate YANG Models

```bash
# Install pyang
pip install pyang

# Validate models
cd arch/data_models
pyang audio_file.yang
pyang playback_state.yang
pyang listening_history.yang

# Generate documentation
pyang -f html audio_file.yang > audio_file.html
```

### Acceptance Tests

#### Read Tests

```bash
# View test scenarios
cat tests/acceptance/playback.feature
cat tests/acceptance/library_management.feature
cat tests/acceptance/listening_history.feature
cat tests/acceptance/real_time_sync.feature

# Read test documentation
cat tests/acceptance/README.md
```

#### Implement Tests

```bash
# Option 1: Add White Bread to mix.exs
{:white_bread, "~> 4.5", only: [:test]}

# Option 2: Add Cabbage
{:cabbage, "~> 0.3.0", only: [:test]}

# Install dependencies
mix deps.get

# Run tests (once implemented)
mix test tests/acceptance/
```

### Development

```bash
# Setup project
mix setup

# Start server
mix phx.server

# Run tests
mix test

# Access application
open http://localhost:4000
```

## Directory Layout

```text
media_stream/
├── arch/                          # Architecture documentation
│   ├── data_models/               # YANG data models (3 files)
│   ├── action_models/             # YANG action models (3 files)
│   ├── diagrams/                  # Mermaid diagrams (4 files)
│   ├── features/                  # Feature docs (4 files)
│   └── README.md                  # Architecture overview
│
├── tests/
│   └── acceptance/                # Acceptance tests
│       ├── playback.feature       # 28 scenarios
│       ├── library_management.feature  # 35 scenarios
│       ├── listening_history.feature   # 34 scenarios
│       ├── real_time_sync.feature      # 37 scenarios
│       └── README.md              # Test documentation
│
├── lib/
│   ├── media_stream/              # Business logic
│   │   ├── media.ex               # Media context
│   │   ├── media/                 # Schemas
│   │   │   ├── audio_file.ex
│   │   │   ├── playback_state.ex
│   │   │   └── listening_history.ex
│   │   ├── repo.ex
│   │   └── application.ex
│   │
│   └── media_stream_web/          # Web layer
│       ├── live/                  # LiveViews
│       │   ├── player_live.ex
│       │   └── history_live.ex
│       ├── controllers/
│       │   └── audio_controller.ex
│       └── router.ex
│
├── priv/
│   └── repo/
│       └── migrations/            # Database migrations
│
├── assets/                        # Frontend assets
│   ├── js/
│   └── css/
│
├── config/                        # Configuration
│   ├── config.exs
│   ├── dev.exs
│   ├── test.exs
│   └── runtime.exs
│
├── CLAUDE.md                      # Claude Code reference
├── PROJECT_OVERVIEW.md            # This file
├── README.md                      # Project readme
└── mix.exs                        # Project configuration
```

## Documentation Statistics

### By Type

| Type | Count | Description |
|------|-------|-------------|
| YANG Data Models | 3 | Database schema specifications |
| YANG Action Models | 3 | Operation/RPC specifications |
| Mermaid Diagrams | 4 | Visual architecture diagrams |
| Feature Docs | 4 | Detailed feature documentation |
| README Files | 6 | Section overviews and guides |
| Acceptance Tests | 4 | Gherkin feature files |
| **Total** | **24** | **Complete documentation suite** |

### By Lines of Content

| Type | Lines | Files |
|------|-------|-------|
| YANG Models | ~2,500 | 6 |
| Mermaid Diagrams | ~400 | 4 |
| Feature Documentation | ~3,500 | 4 |
| README Files | ~2,000 | 6 |
| Acceptance Tests | ~1,154 | 4 |
| **Total** | **~9,554** | **24** |

### Test Coverage

| Feature | Scenarios | Lines |
|---------|-----------|-------|
| Playback | 28 | ~350 |
| Library Management | 35 | ~400 |
| Listening History | 34 | ~380 |
| Real-Time Sync | 37 | ~400 |
| **Total** | **134** | **~1,530** |

## Key Benefits

### For Developers

1. **Comprehensive Documentation**
   - Every feature fully documented
   - Architecture clearly explained
   - Data models formally specified
   - Visual diagrams for understanding

2. **Testing Suite**
   - 134 acceptance scenarios
   - All features covered
   - Edge cases documented
   - Ready to implement

3. **Standards-Based**
   - YANG (RFC 7950) for data models
   - Gherkin/BDD for acceptance tests
   - Mermaid for diagrams
   - Industry best practices

### For Onboarding

1. **Quick Understanding**
   - Start with PROJECT_OVERVIEW.md (this file)
   - Read CLAUDE.md for quick reference
   - Browse arch/README.md for architecture
   - Review feature docs for detailed understanding

2. **Multiple Entry Points**
   - Visual learners: Start with diagrams
   - Technical: Start with YANG models
   - Business: Start with acceptance tests
   - Practical: Start with feature docs

3. **Progressive Disclosure**
   - High-level overviews
   - Detailed specifications
   - Implementation examples
   - Edge cases and patterns

### For Maintenance

1. **Single Source of Truth**
   - Models define the system
   - Tests define behavior
   - Docs explain design
   - All text-based and version controlled

2. **Easy Updates**
   - Modify YANG when schema changes
   - Update diagrams when architecture evolves
   - Add scenarios when features added
   - Everything in one repository

3. **Validation Tools**
   - pyang validates YANG models
   - mmdc validates Mermaid diagrams
   - BDD frameworks validate tests
   - CI/CD integration ready

## Future Enhancements

### Documentation Enhancements

- [ ] API documentation (if REST endpoints added)
- [ ] Performance benchmarks
- [ ] Security documentation
- [ ] Deployment guides

### Testing

- [ ] Implement step definitions for acceptance tests
- [ ] Add unit test examples
- [ ] Integration test patterns
- [ ] Performance test scenarios
- [ ] Load testing specifications

### Tooling

- [ ] Auto-generate HTML documentation
- [ ] Diagram export pipeline
- [ ] Test coverage reporting
- [ ] CI/CD pipeline examples

## Getting Help

### Resources

- **Architecture Docs**: [arch/](arch/)
- **Feature Docs**: [arch/features/](arch/features/)
- **Acceptance Tests**: [tests/acceptance/](tests/acceptance/)
- **Quick Reference**: [CLAUDE.md](CLAUDE.md)

### External Links

- **Phoenix Framework**: [https://phoenixframework.org/](https://phoenixframework.org/)
- **YANG Specification**: [https://datatracker.ietf.org/doc/html/rfc7950](https://datatracker.ietf.org/doc/html/rfc7950)
- **Mermaid Diagrams**: [https://mermaid.js.org/](https://mermaid.js.org/)
- **Gherkin/BDD**: [https://cucumber.io/docs/gherkin/](https://cucumber.io/docs/gherkin/)

## Maintenance Guidelines

### When Adding Features

1. Update YANG models (data and actions)
2. Update or create diagrams
3. Write feature documentation
4. Add acceptance test scenarios
5. Update README files
6. Cross-reference between docs

### When Fixing Bugs

1. Add acceptance test for bug (if missing)
2. Update documentation if behavior changes
3. Update diagrams if flow changes
4. Keep docs synchronized with code

### Regular Reviews

- Monthly: Review for accuracy
- Quarterly: Update future enhancements
- Per release: Validate all docs
- Annual: Major documentation audit

## License

[Your License Here]

## Contributors

[Your Contributors Here]

---

**Last Updated**: 2025-12-02
**Documentation Version**: 1.0
**Project Status**: Active Development
