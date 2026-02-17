# MediaStream

Personal audio streaming server built with Phoenix LiveView. Browse, search, and play audio files with cross-device playback sync, listening history, and playlist support.

## Features

- Audio playback with full transport controls (play, pause, seek, next, prev)
- Real-time cross-tab/cross-device synchronization via PubSub
- Library scanning with metadata extraction (ffprobe)
- M3U/M3U8 playlist loading
- Listening history with date range filtering and search
- Session-persistent playback state (resume after browser restart)
- HTTP range request support for seeking

## Stack

- **Elixir/Phoenix 1.8** with LiveView 1.1
- **SQLite** via Ecto SQLite3
- **Comn v0.3.0** for structured errors, events, and process-scoped contexts
- **Tailwind CSS** with daisyUI
- **Bandit** web server

## Setup

```bash
mix setup    # Install deps, create DB, run migrations, build assets
mix phx.server   # Start at http://localhost:4000
```

## Dependencies

- `ffprobe` (from ffmpeg) for audio metadata extraction
- Elixir 1.15+, Erlang/OTP 26+

## Comn Integration

MediaStream uses [Comn](https://github.com/imsmith/comn) v0.3.0 for shared infrastructure:

- **Comn.Events.EventStruct** — All PubSub broadcasts use structured event structs with type, topic, data, source, and timestamp
- **Comn.EventLog** — In-memory audit log records all playback and history events
- **Comn.Contexts** — Process-scoped context carries device_id through request lifecycle
- **Comn.Errors** — Error wrapping with categorization for user-facing flash messages

## Architecture

See [arch/README.md](arch/README.md) for full architecture documentation including YANG data models, Mermaid diagrams, and feature specs.

## License

AGPL-3.0
