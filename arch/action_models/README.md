# Action Models

This directory contains YANG RPC models for all user-facing operations and actions in MediaStream.

## Overview

Actions are modeled as YANG RPCs (Remote Procedure Calls) with:
- **Input parameters** - Required and optional arguments
- **Output results** - Success data and error information
- **Side effects** - Database writes, PubSub broadcasts, filesystem operations
- **Error conditions** - Possible failure modes and error codes

## Action Models

### [playback_actions.yang](playback_actions.yang)

Playback control operations for audio player.

**RPCs**:
- `play` - Start playing audio file
- `pause` - Pause current playback
- `resume` - Resume from paused state
- `seek` - Jump to position in track
- `next` - Skip to next track in queue
- `previous` - Restart current track (or go to previous)
- `audio-time-update` - Update position from audio element
- `audio-ended` - Handle track completion
- `audio-metadata-loaded` - Handle metadata loaded event
- `add-to-queue` - Add file to playback queue
- `remove-from-queue` - Remove file from queue

**Implementation**: [../../lib/media_stream_web/live/player_live.ex](../../lib/media_stream_web/live/player_live.ex)

**Side Effects**:
- Database: Updates `playback_states` table
- PubSub: Broadcasts to `playback:{device_id}` topic
- Client: Triggers audio element actions via hooks

### [library_actions.yang](library_actions.yang)

Library management operations for building and searching media collection.

**RPCs**:
- `scan-directory` - Recursively scan filesystem for audio files
- `search` - Search library by metadata
- `load-playlist` - Load M3U/M3U8 playlist into queue
- `parse-playlist` - Parse playlist file (utility)
- `list-audio-files` - Get all library files
- `get-audio-file` - Get single file by ID
- `create-audio-file` - Manually add file to library

**Implementation**: [../../lib/media_stream/media.ex](../../lib/media_stream/media.ex), [../../lib/media_stream_web/live/player_live.ex](../../lib/media_stream_web/live/player_live.ex)

**Side Effects**:
- Database: Inserts into `audio_files` table (scan, create)
- Database: Updates `playback_states.queue_json` (load-playlist)
- Filesystem: Reads audio files and playlists

### [history_actions.yang](history_actions.yang)

Listening history tracking and analytics operations.

**RPCs**:
- `list-history` - Get listening history records
- `search-history` - Search history by date/metadata
- `create-history-entry` - Record new listening session
- `update-history-entry` - Mark session complete
- `filter-by-date` - Filter by date range
- `toggle-device-filter` - Switch between current/all devices
- `get-statistics` - Aggregate analytics metrics

**Implementation**: [../../lib/media_stream_web/live/history_live.ex](../../lib/media_stream_web/live/history_live.ex), [../../lib/media_stream/media.ex](../../lib/media_stream/media.ex)

**Side Effects**:
- Database: Inserts/updates `listening_history` table
- Analytics: Computes aggregates (COUNT, SUM, AVG)

## RPC Structure

Each RPC follows this pattern:

```yang
rpc action-name {
  description
    "What this action does.

     Behavior: How it works
     Triggers: What causes it
     Side effects: What changes";

  input {
    // Required and optional parameters
    leaf param-name {
      type param-type;
      mandatory true;
      description "Parameter description";
    }
  }

  output {
    // Success results and error information
    uses common-output;

    leaf result-field {
      type result-type;
      description "Result description";
    }
  }
}
```

## Common Patterns

### Common Input

Many actions share common input parameters:

```yang
grouping common-input {
  leaf device-id {
    type playback:device-id;
    mandatory true;
    description "Device identifier";
  }
}
```

### Common Output

All actions return status and message:

```yang
grouping common-output {
  leaf status {
    type result-status;  // success | error
    mandatory true;
  }

  leaf message {
    type string;
    description "Human-readable result";
  }
}
```

### Error Responses

Actions may fail with structured errors:

```yang
typedef error-code {
  type enumeration {
    enum file-not-found;
    enum database-error;
    // ... more error types
  }
}

grouping error-response {
  leaf error-code {
    type error-code;
    mandatory true;
  }

  leaf error-message {
    type string;
  }
}
```

## Side Effects Documentation

Each RPC documents its side effects:

### Database Writes

```yang
// In description:
"Side effects:
 - Database: UPDATE playback_states SET position_seconds"
```

### PubSub Broadcasts

```yang
"Side effects:
 - PubSub: Broadcasts :playback_state_updated to 'playback:{device_id}'"
```

### Filesystem Operations

```yang
"Side effects:
 - Filesystem: Reads files recursively from directory"
```

### Client Actions

```yang
"Side effects:
 - UI: Triggers audio element to load and play file"
```

## Mapping to Implementation

### LiveView Events

YANG RPCs map to LiveView `handle_event/3`:

```yang
rpc play {
  input {
    leaf audio-file-id { type int64; }
  }
}
```

```elixir
def handle_event("play", %{"id" => id}, socket) do
  # Implementation
end
```

### Context Functions

YANG RPCs map to Context functions:

```yang
rpc scan-directory {
  input {
    leaf directory-path { type string; }
  }
  output {
    leaf files-scanned { type uint32; }
  }
}
```

```elixir
def scan_directory(directory_path) do
  # Returns {:ok, %{scanned: N, added: N, skipped: N}}
end
```

## Error Handling

### Error Codes

Each action model defines specific error codes:

**Playback Errors**:
- `file-not-found` - Audio file doesn't exist
- `queue-empty` - No tracks in queue for next/previous
- `invalid-position` - Seek position out of range

**Library Errors**:
- `directory-not-found` - Scan path doesn't exist
- `permission-denied` - No read access
- `playlist-parse-error` - Invalid playlist format

**History Errors**:
- `invalid-date-range` - End before start
- `audio-file-not-found` - Referenced file missing

### Error Response Format

```elixir
# Success
{:ok, %{status: :success, data: ...}}

# Error
{:error, %{
  error_code: :file_not_found,
  error_message: "Audio file does not exist",
  details: "File ID: 42"
}}
```

## Testing Actions

### Unit Tests

Test context functions (RPCs):

```elixir
test "scan_directory/1 finds audio files" do
  result = Media.scan_directory("/test/music")
  assert {:ok, %{scanned: count}} = result
  assert count > 0
end
```

### Integration Tests

Test LiveView event handlers:

```elixir
test "play event starts playback" do
  {:ok, view, _html} = live(conn, "/")

  view
  |> element("button#play-42")
  |> render_click()

  assert has_element?(view, "#now-playing-42")
end
```

## Documentation Generation

YANG models serve as documentation:

```bash
# Generate HTML docs for all actions
pyang -f html playback_actions.yang > playback_actions.html
pyang -f html library_actions.yang > library_actions.html
pyang -f html history_actions.yang > history_actions.html

# Generate tree view
pyang -f tree playback_actions.yang
```

## Related Documentation

- **Data Models**: [../data_models/](../data_models/)
- **Features**: [../features/](../features/)
- **Implementation**: [../../lib/media_stream_web/live/](../../lib/media_stream_web/live/), [../../lib/media_stream/media.ex](../../lib/media_stream/media.ex)
