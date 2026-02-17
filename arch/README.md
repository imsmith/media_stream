# MediaStream Architecture Documentation

Comprehensive architecture documentation using YANG data models, Mermaid diagrams, and feature specifications.

## Overview

This directory contains the complete architectural documentation for MediaStream, including:

- **Data Models** - YANG specifications for all database schemas
- **Action Models** - YANG RPC specifications for all operations
- **Diagrams** - Mermaid visualizations of architecture and flows
- **Features** - Detailed documentation of user-facing features

## Why This Approach?

### YANG Data Models

[YANG](https://datatracker.ietf.org/doc/html/rfc7950) is an industry-standard data modeling language (IETF RFC 7950) that provides:

- ✅ **Machine-readable** - Can be validated and used for code generation
- ✅ **Strongly typed** - Precise type definitions with built-in constraints
- ✅ **Hierarchical** - Natural fit for structured data like database schemas
- ✅ **Relationships** - Native support via leafref for foreign keys
- ✅ **Documentation** - Inline descriptions and metadata
- ✅ **Tooling** - Extensive ecosystem (pyang, validators, generators)

### Mermaid Diagrams

[Mermaid](https://mermaid.js.org/) provides text-based diagramming:

- ✅ **Version control friendly** - Text format, easy to diff
- ✅ **Native rendering** - GitHub, GitLab, VS Code support out of box
- ✅ **Maintainable** - Edit as text, renders automatically
- ✅ **Multiple formats** - ER diagrams, sequence diagrams, component diagrams
- ✅ **Exportable** - Generate PNG/SVG for external docs

## Directory Structure

```
arch/
├── data_models/           # YANG data models
│   ├── audio_file.yang
│   ├── playback_state.yang
│   ├── listening_history.yang
│   └── README.md
├── action_models/         # YANG RPC action models
│   ├── playback_actions.yang
│   ├── library_actions.yang
│   ├── history_actions.yang
│   └── README.md
├── diagrams/              # Mermaid architecture diagrams
│   ├── data_relationships.mmd
│   ├── system_architecture.mmd
│   ├── pubsub_flow.mmd
│   ├── streaming_sequence.mmd
│   └── README.md
├── features/              # Feature documentation
│   ├── playback.md
│   ├── library_management.md
│   ├── listening_history.md
│   ├── real_time_sync.md
│   └── README.md
└── README.md              # This file
```

## Quick Start

### Understanding the System

1. **Start with System Architecture**
   - Read [diagrams/system_architecture.mmd](diagrams/system_architecture.mmd)
   - See how components fit together

2. **Review Data Models**
   - Read [data_models/README.md](data_models/README.md)
   - Understand database schema via [data_models/audio_file.yang](data_models/audio_file.yang), etc.
   - View relationships in [diagrams/data_relationships.mmd](diagrams/data_relationships.mmd)

3. **Explore Features**
   - Browse [features/](features/) directory
   - Each feature doc links to relevant models and diagrams

4. **Understand Actions**
   - Read [action_models/README.md](action_models/README.md)
   - See available operations in YANG RPC models

### Working with YANG Models

#### Install Tools

```bash
# Install pyang (Python-based YANG validator)
pip install pyang

# Or use system package manager
apt-get install pyang  # Debian/Ubuntu
brew install pyang     # macOS
```

#### Validate Models

```bash
cd arch/data_models
pyang audio_file.yang

# If valid, no output
# If invalid, shows errors
```

#### Generate Documentation

```bash
# Tree view
pyang -f tree audio_file.yang

# HTML documentation
pyang -f html audio_file.yang > audio_file.html

# Browse all models
for file in *.yang; do
  pyang -f html "$file" > "${file%.yang}.html"
done
```

### Working with Diagrams

#### View in GitHub

Simply open .mmd files in GitHub - they render automatically.

#### View in VS Code

Install Mermaid extension:
```bash
code --install-extension bierner.markdown-mermaid
```

#### Export as Images

```bash
# Install Mermaid CLI
npm install -g @mermaid-js/mermaid-cli

# Export diagram
cd arch/diagrams
mmdc -i data_relationships.mmd -o data_relationships.png
```

## Data Models

### Core Schemas

**[AudioFile](data_models/audio_file.yang)** - Media library files
- Path (unique), title, artist, album
- Duration, file type, file size
- Indexed for search performance

**[PlaybackState](data_models/playback_state.yang)** - Per-device playback state
- Device ID (unique)
- Current file, position, queue (JSON)
- Enables multi-tab sync and session persistence

**[ListeningHistory](data_models/listening_history.yang)** - Listening sessions
- Audio file reference
- Device ID, timestamps
- Duration listened, completion status

### Relationships

```
AudioFile (1) ──┬── (0..N) PlaybackState [ON DELETE: NILIFY]
                └── (0..N) ListeningHistory [ON DELETE: CASCADE]
```

See [diagrams/data_relationships.mmd](diagrams/data_relationships.mmd) for full ER diagram.

## Action Models

### Operation Categories

**[Playback Actions](action_models/playback_actions.yang)** - 11 RPCs
- Transport controls: play, pause, resume, seek, next, previous
- Queue management: add-to-queue, remove-from-queue
- Audio events: time-update, ended, metadata-loaded

**[Library Actions](action_models/library_actions.yang)** - 7 RPCs
- Directory scanning: scan-directory
- Search: search, list-audio-files, get-audio-file
- Playlists: load-playlist, parse-playlist
- Management: create-audio-file

**[History Actions](action_models/history_actions.yang)** - 7 RPCs
- Querying: list-history, search-history, filter-by-date
- Recording: create-history-entry, update-history-entry
- Analytics: get-statistics
- UI: toggle-device-filter

## Key Features

### [Playback](features/playback.md)

Audio playback with full transport controls and multi-tab synchronization.

**Highlights**:
- Real-time sync across tabs via PubSub (<20ms latency)
- HTTP range request support for seeking
- Session persistence (resume after reload)
- Automatic queue management

### [Library Management](features/library_management.md)

Building and organizing your audio collection.

**Highlights**:
- Recursive directory scanning (6 audio formats)
- M3U/M3U8 playlist loading
- Real-time search (title/artist/album)
- Duplicate prevention by path

### [Listening History](features/listening_history.md)

Track what you've listened to and when.

**Highlights**:
- Automatic session recording
- Date range filtering
- Device-scoped history
- Analytics-ready data structure

### [Real-Time Sync](features/real_time_sync.md)

Multi-device synchronization architecture.

**Highlights**:
- Per-device PubSub topics
- Broadcast-on-write pattern
- Eventual consistency model
- Database-backed persistence

## Architecture Principles

### Context-Driven Design

All business logic lives in the Media Context:
```elixir
# Good: Use context
Media.list_audio_files()
Media.update_playback_state(device_id, attrs)

# Bad: Direct repo access from views
Repo.all(AudioFile)
```

### Immutable Data Structures

Use Ecto changesets for all data mutations:
```elixir
# Build changeset, validate, then insert/update
audio_file
|> AudioFile.changeset(attrs)
|> Repo.insert()
```

### PubSub for Real-Time

Broadcast state changes as structured Comn events:
```elixir
# Update database, create event, log, then broadcast
{:ok, state} = Repo.update(changeset)
event = Comn.Events.EventStruct.new(:playback_state_updated, topic, state, :media_stream)
Comn.EventLog.record(event)
PubSub.broadcast(MediaStream.PubSub, topic, {:event, event.topic, event})
```

### Session Persistence

Store state in database for session restoration:
- Playback position saved continuously
- Queue persisted as JSON
- Device ID in session cookie

## Common Patterns

### LiveView Event Flow

```
1. User Action (click button)
   ↓
2. LiveView Event (handle_event/3)
   ↓
3. Context Function (Media.*)
   ↓
4. Database Update (Repo.insert/update)
   ↓
5. PubSub Broadcast (optional)
   ↓
6. LiveView Update (handle_info/2)
   ↓
7. UI Render (assign/2)
```

### Error Handling

Errors are wrapped with Comn.Errors for consistent, categorized messages:
```elixir
case Media.operation() do
  {:ok, result} ->
    # Success path
    {:noreply, assign(socket, ...) |> put_flash(:info, "Success")}

  {:error, reason} ->
    error = Comn.Errors.wrap(reason)
    {:noreply, put_flash(socket, :error, error.message)}
end
```

### Query Patterns

```elixir
# Always preload associations when displaying
from h in ListeningHistory,
  preload: [:audio_file],
  order_by: [desc: h.started_at]

# Use indexes for performance
where([a], ilike(a.title, ^search_term))  # Uses title index
```

## Maintenance

### Keeping Documentation Synchronized

When making changes:

1. **Update Data Models**
   - Modify Ecto schema
   - Update YANG model
   - Update migration if needed
   - Update ER diagram

2. **Update Action Models**
   - Add/modify context function
   - Update YANG RPC specification
   - Document side effects

3. **Update Feature Docs**
   - Describe user-visible changes
   - Update technical implementation section
   - Add edge cases if relevant

4. **Update Diagrams**
   - Modify affected .mmd files
   - Verify rendering
   - Export new images if needed

### Documentation Checklist

- [ ] Data model YANG files updated
- [ ] Action model YANG files updated
- [ ] Feature documentation updated
- [ ] Diagrams updated and verified
- [ ] READMEs updated if structure changed
- [ ] Cross-references checked

## Validation

### YANG Models

```bash
# Validate all data models
cd arch/data_models
for file in *.yang; do
  echo "Validating $file..."
  pyang --strict "$file" || echo "ERROR in $file"
done

# Validate all action models
cd arch/action_models
for file in *.yang; do
  echo "Validating $file..."
  pyang --strict "$file" || echo "ERROR in $file"
done
```

### Diagrams

```bash
# Validate Mermaid syntax with mmdc
cd arch/diagrams
for file in *.mmd; do
  echo "Validating $file..."
  mmdc -i "$file" -o "/tmp/test.png" || echo "ERROR in $file"
done
```

## Tools and Resources

### YANG

- **pyang** - https://github.com/mbj4668/pyang
- **RFC 7950** - https://datatracker.ietf.org/doc/html/rfc7950
- **YANG Tutorial** - https://www.yangvalidator.com/

### Mermaid

- **Live Editor** - https://mermaid.live/
- **Documentation** - https://mermaid.js.org/
- **CLI** - https://github.com/mermaid-js/mermaid-cli

### Elixir/Phoenix

- **Phoenix Docs** - https://hexdocs.pm/phoenix/
- **Ecto Docs** - https://hexdocs.pm/ecto/
- **LiveView Docs** - https://hexdocs.pm/phoenix_live_view/

## Benefits

### For Developers

- **Faster onboarding** - Complete system documentation in one place
- **Better understanding** - Visual diagrams + precise models
- **Reduced errors** - Validate changes against models
- **Code generation** - YANG models can generate code/tests

### For Architecture

- **Single source of truth** - Models define the system
- **Version control** - All docs are text files
- **Maintainable** - Easy to keep updated
- **Discoverable** - Organized, searchable structure

### For Collaboration

- **Clear contracts** - YANG RPCs define interfaces
- **Visual communication** - Diagrams show flows
- **Consistent terminology** - Shared vocabulary
- **Review-friendly** - Easy to diff and review

## Related Documentation

- **High-Level Overview**: [../CLAUDE.md](../CLAUDE.md)
- **Project README**: [../README.md](../README.md)
- **Implementation**: [../lib/](../lib/)
- **Database Migrations**: [../priv/repo/migrations/](../priv/repo/migrations/)
