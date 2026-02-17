# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MediaStream is a Phoenix LiveView application for streaming audio files with multi-device playback state synchronization. It allows users to browse, search, play audio files, manage playback queues, and load M3U/M3U8 playlists. The app uses SQLite for persistence and Phoenix PubSub for real-time sync across devices.

## Technology Stack

- **Framework**: Phoenix 1.8.0-rc.4 with Phoenix LiveView 1.1.0-rc.0
- **Database**: SQLite via Ecto SQLite3 and Exqlite
- **Web Server**: Bandit 1.5 (replacing Cowboy)
- **Frontend**: Tailwind CSS 4.1.7, esbuild 0.25.4
- **Real-time**: Phoenix PubSub for cross-device state synchronization
- **Shared Infrastructure**: Comn v0.3.0 (structured errors, events, process-scoped contexts)

## Common Commands

### Initial Setup

```bash
mix setup  # Installs deps, creates DB, runs migrations, sets up assets
```

### Development

```bash
mix phx.server              # Start Phoenix server at http://localhost:4000
iex -S mix phx.server        # Start with IEx shell for debugging
```

### Database

```bash
mix ecto.create              # Create database
mix ecto.migrate             # Run migrations
mix ecto.rollback            # Rollback last migration
mix ecto.reset               # Drop, create, and migrate database
mix ecto.setup               # Create DB, run migrations, and seed
```

### Assets

```bash
mix assets.setup             # Install Tailwind and esbuild if missing
mix assets.build             # Build assets for development
mix assets.deploy            # Build and minify assets for production
```

### Testing

```bash
mix test                     # Run all tests (sets up test DB automatically)
mix test test/path/file_test.exs  # Run specific test file
mix test test/path/file_test.exs:42  # Run specific test at line 42
```

### Development Dashboard

- LiveDashboard: [http://localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard)
- Mailbox Preview: [http://localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox)

## Architecture

### Domain Context: `MediaStream.Media`

The Media context ([lib/media_stream/media.ex](lib/media_stream/media.ex)) is the primary business logic layer with three core schemas:

1. **AudioFile** - Represents audio files with metadata (path, title, artist, album, duration, file type/size)
2. **PlaybackState** - Per-device playback state (current file, position, queue as JSON)
3. **ListeningHistory** - Records what was played when (with device_id and timestamps)

Key functions:

- `scan_directory/1` - Recursively scans filesystem for audio files (.mp3, .m4a, .flac, etc.)
- `parse_playlist/1` and `load_playlist_queue/1` - M3U/M3U8 playlist support
- `update_playback_state/2` - Upserts playback state and broadcasts via PubSub

### Comn Integration

MediaStream uses [Comn](https://github.com/imsmith/comn) v0.3.0 for shared infrastructure:

- **Comn.Events.EventStruct** — All PubSub broadcasts use structured event structs (`{:event, topic, %EventStruct{}}`) instead of bare tuples
- **Comn.EventLog** — In-memory audit log (Agent) records all playback and history events; query via `Comn.EventLog.all()`
- **Comn.Contexts** — Process-scoped context initialized per request (DeviceId plug) and per LiveView mount, carrying device_id metadata
- **Comn.Errors** — `Comn.Errors.wrap/1` converts raw error terms into `ErrorStruct` with categorized messages for flash display

Supervisor children in `application.ex`:
```elixir
{Registry, keys: :duplicate, name: Comn.EventBus},
{Comn.EventLog, []},
```

### Real-time Sync Architecture

**Device ID Generation**: Each browser session gets a unique device_id (8 random bytes, Base16 encoded) stored in session. The DeviceId plug also initializes a `Comn.Contexts` with the device_id for the HTTP process. LiveView mounts set their own context (separate process).

**PubSub Broadcasting**: When playback state changes (position, current file, queue), the Media context creates a `Comn.Events.EventStruct`, logs it to `Comn.EventLog`, then broadcasts `{:event, topic, event_struct}` to the PubSub topic. LiveViews pattern-match on `{:event, topic, %Comn.Events.EventStruct{type: type, data: data}}`.

**State Persistence**: PlaybackState stores the queue as JSON in the database. On page load, the state is restored from DB, allowing playback to resume after closing/reopening the app.

### Audio Streaming with Range Requests

The AudioController ([lib/media_stream_web/controllers/audio_controller.ex](lib/media_stream_web/controllers/audio_controller.ex)) implements HTTP range request support (RFC 7233) to enable:

- Seeking in audio player
- Partial content delivery (206 responses)
- Efficient bandwidth usage

It parses `Range: bytes=start-end` headers and uses `send_file/4` with offset/length parameters.

### LiveView Structure

**PlayerLive** ([lib/media_stream_web/live/player_live.ex](lib/media_stream_web/live/player_live.ex)):

- Main interface for browsing, searching, and playing audio
- Handles playback controls (play, pause, seek, next, prev)
- Queue management (add, remove)
- Directory scanning for new files
- Playlist upload (.m3u/.m3u8)
- Bidirectional sync with HTML5 audio element via JS hooks

**HistoryLive** ([lib/media_stream_web/live/history_live.ex](lib/media_stream_web/live/history_live.ex)):

- Displays listening history with date range filtering
- Search by title/artist/album

### JavaScript Integration

The app uses `phoenix-colocated` for co-located LiveView hooks ([assets/js/app.js](assets/js/app.js)). Audio element interactions (play, pause, timeupdate, ended) are wired up via hooks that push events back to the LiveView.

## Database Schema

### audio_files

- Unique constraint on `path`
- Indexes on `title`, `artist`, `album` for search performance

### playback_states

- Unique constraint on `device_id` (one state per device)
- `queue_json` stores array of audio_file IDs as JSON
- Foreign key to `current_file_id` with `on_delete: :nilify_all`

### listening_history

- Tracks playback events with `started_at`, `completed_at`
- Foreign key to `audio_file_id` and stores `device_id`

## Configuration Notes

- **Database Location**: `media_stream_dev.db` in config directory (dev)
- **Server Binding**: Binds to 0.0.0.0:4000 (accessible from network) in dev
- **MIME Types**: Custom MIME types registered for .m3u and .m3u8 files
- **Migrations**: Auto-run on release start, skipped in dev (use `mix ecto.migrate`)

## Code Patterns

### Context Functions

All database operations go through the `MediaStream.Media` context. Never query `Repo` directly from LiveViews or Controllers.

### Search Implementation

Uses `ilike` for case-insensitive search across multiple fields. Example:

```elixir
    where([a], ilike(a.title, ^search_term) or ilike(a.artist, ^search_term))
```

### Queue Serialization

Queue is stored as JSON array of IDs. Use `encode_queue/1` and `decode_queue/1` helpers in PlayerLive to convert between `[%AudioFile{}]` and JSON string.

### PubSub Pattern

1. Update DB via context function
2. Context function creates `Comn.Events.EventStruct`, logs to `Comn.EventLog`, broadcasts `{:event, topic, event_struct}` via PubSub
3. LiveView subscribes to topic in `mount/3` with `connected?/1` guard
4. Handle broadcast in `handle_info/2` by pattern-matching `{:event, topic, %Comn.Events.EventStruct{type: type, data: data}}`

### Error Handling

Errors surfacing to LiveViews are wrapped via `Comn.Errors.wrap/1` which returns an `ErrorStruct` with a `.message` field suitable for `put_flash/3`.
