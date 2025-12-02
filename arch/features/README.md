# Features

This directory contains detailed documentation for each major feature in MediaStream.

## Overview

Feature documentation describes:
- **User flows** - How users interact with the feature
- **Technical implementation** - How it's built
- **Data models** - What data structures are used
- **Actions** - What operations are supported
- **Edge cases** - Potential issues and handling
- **Future enhancements** - Ideas for improvement

## Features

### [playback.md](playback.md)

**Audio playback and transport controls**

Core functionality for playing audio files with full controls.

**Key Capabilities**:
- Play, pause, resume, seek controls
- Queue-based playback with auto-advance
- Multi-tab synchronization via PubSub
- Session persistence (resume after reload)
- HTTP range request support for seeking

**Components**:
- PlayerLive (UI and state management)
- AudioController (streaming)
- Media Context (business logic)
- JavaScript hooks (audio element integration)

**Related**:
- Data: [playback_state.yang](../data_models/playback_state.yang), [audio_file.yang](../data_models/audio_file.yang)
- Actions: [playback_actions.yang](../action_models/playback_actions.yang)
- Diagrams: [pubsub_flow.mmd](../diagrams/pubsub_flow.mmd), [streaming_sequence.mmd](../diagrams/streaming_sequence.mmd)

### [library_management.md](library_management.md)

**Building and organizing the audio library**

Tools for importing and managing audio file collections.

**Key Capabilities**:
- Recursive directory scanning
- M3U/M3U8 playlist loading
- Real-time search (title, artist, album)
- Duplicate detection (by file path)
- Multiple audio format support

**Components**:
- PlayerLive (UI)
- Media Context (scan/search logic)
- AudioFile schema

**Supported Formats**:
- MP3, M4A, FLAC, OGG, WAV, AAC

**Related**:
- Data: [audio_file.yang](../data_models/audio_file.yang)
- Actions: [library_actions.yang](../action_models/library_actions.yang)

### [listening_history.md](listening_history.md)

**Tracking and analyzing listening sessions**

Records what you've listened to, when, and for how long.

**Key Capabilities**:
- Automatic session recording
- Date range filtering
- Text search on track metadata
- Device-scoped history
- Completion tracking

**Components**:
- HistoryLive (UI)
- Media Context (queries and analytics)
- ListeningHistory schema

**Future Features**:
- Listening insights and statistics
- Resume functionality
- Recommendations based on history

**Related**:
- Data: [listening_history.yang](../data_models/listening_history.yang), [audio_file.yang](../data_models/audio_file.yang)
- Actions: [history_actions.yang](../action_models/history_actions.yang)

### [real_time_sync.md](real_time_sync.md)

**Multi-tab synchronization and state persistence**

Keeps playback state in sync across browser tabs and sessions.

**Key Capabilities**:
- Instant sync across browser tabs
- Device ID-based state isolation
- Phoenix PubSub messaging
- Database persistence
- Session restoration

**Architecture**:
- Per-device PubSub topics
- Broadcast-on-write pattern
- Eventual consistency model
- Last-write-wins conflict resolution

**Technical Details**:
- Sub-20ms sync latency typical
- Supports unlimited tabs per device
- Scales linearly with concurrent users
- No performance bottlenecks observed

**Related**:
- Data: [playback_state.yang](../data_models/playback_state.yang)
- Actions: [playback_actions.yang](../action_models/playback_actions.yang)
- Diagrams: [pubsub_flow.mmd](../diagrams/pubsub_flow.mmd), [system_architecture.mmd](../diagrams/system_architecture.mmd)

## Feature Interactions

### Playback + Real-Time Sync

Playback state changes broadcast via PubSub:
- Play action → Update database → Broadcast → Other tabs sync
- Seek action → Update database → Broadcast → Other tabs seek
- Queue changes → Update database → Broadcast → Other tabs refresh queue

### Library + Playback

Library files integrated with playback:
- Browse library → Click play → Start playback
- Search library → Add to queue → Play queue
- Load playlist → Populate queue → Play first track

### Playback + History

Playback creates history records:
- Start playing → Create history entry (started_at)
- Track completes → Update history (completed_at, duration)
- Track skipped → History shows partial listen

### Library + History

History links back to library:
- View history → Shows track title/artist from AudioFile
- History preloads audio_file association
- AudioFile deletion cascades to history

## Common Patterns

### Context-Driven Architecture

All features use the Media Context:
```elixir
# Don't query Repo directly from LiveViews
Audio.list_audio_files()  # Good
Repo.all(AudioFile)       # Bad

# Use context functions
Media.create_listening_history(...)
Media.update_playback_state(...)
```

### LiveView State Management

State flows:
1. User action → LiveView event
2. Event → Context function call
3. Context → Database update
4. Database → Broadcast (if needed)
5. Broadcast → LiveView handle_info
6. handle_info → UI update

### Error Handling

Consistent error patterns:
```elixir
case Media.scan_directory(path) do
  {:ok, results} ->
    # Success: update UI, show flash
    {:noreply, assign(socket, ...) |> put_flash(:info, ...)}

  {:error, reason} ->
    # Error: show error message
    {:noreply, put_flash(socket, :error, ...)}
end
```

## Testing Features

### Feature Tests

Test complete user flows:
```elixir
test "user can play track and it syncs to other tab" do
  # Setup two live views
  {:ok, view1, _} = live(conn, "/")
  {:ok, view2, _} = live(conn, "/")

  # Play in view1
  view1 |> element("button#play-1") |> render_click()

  # Assert view2 synced
  assert render(view2) =~ "Now Playing"
end
```

### Unit Tests

Test context functions:
```elixir
test "scan_directory finds audio files" do
  assert {:ok, %{added: count}} = Media.scan_directory("/test")
  assert count > 0
end
```

### Integration Tests

Test full stack:
```elixir
test "playback state persists across sessions" do
  # Play and seek
  {:ok, view, _} = live(conn, "/")
  view |> element("#play-1") |> render_click()
  view |> element("#seek") |> render_change(%{"position" => "45.2"})

  # Simulate page reload
  {:ok, new_view, _} = live(conn, "/")

  # Assert state restored
  assert render(new_view) =~ "45"
end
```

## Documentation Updates

When adding/changing features:

1. ✅ Update feature .md file
2. ✅ Update or create data models (.yang)
3. ✅ Update or create action models (.yang)
4. ✅ Update relevant diagrams (.mmd)
5. ✅ Add cross-references between docs
6. ✅ Update this README with new feature

## Related Documentation

- **Data Models**: [../data_models/](../data_models/)
- **Action Models**: [../action_models/](../action_models/)
- **Diagrams**: [../diagrams/](../diagrams/)
- **Implementation**: [../../lib/media_stream/](../../lib/media_stream/), [../../lib/media_stream_web/](../../lib/media_stream_web/)
- **High-Level Docs**: [../../CLAUDE.md](../../CLAUDE.md)
