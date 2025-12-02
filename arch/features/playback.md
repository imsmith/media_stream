# Playback Feature

## Overview

The playback feature enables users to play audio files with full transport controls (play, pause, seek, next, previous) and maintains playback state across browser sessions and multiple tabs/windows.

## User Flows

### Basic Playback Flow

1. User browses library on main page
2. User clicks play button on a file
3. System loads file into HTML5 audio element
4. Audio begins playing
5. UI shows playing state with transport controls
6. Playback state saved to database

### Queue-Based Playback

1. User adds multiple files to queue
2. User clicks play on first queued item (or currently playing track ends)
3. System plays tracks in queue order
4. When track ends, system auto-advances to next in queue
5. Queue updates in real-time in UI

### Multi-Tab Synchronization

1. User opens two browser tabs with MediaStream
2. User plays a track in Tab 1
3. Tab 2 automatically syncs and shows same track playing
4. User seeks position in Tab 2
5. Tab 1 automatically updates to same position

## Technical Implementation

### Components

**Location**: [lib/media_stream_web/live/player_live.ex](../../lib/media_stream_web/live/player_live.ex)

### Data Models

- **PlaybackState** ([arch/data_models/playback_state.yang](../data_models/playback_state.yang))
  - Stores per-device playback state
  - Unique constraint on device_id
  - Includes: current_file_id, position_seconds, queue_json

### Actions

- **play** - Start playing audio file
- **pause** - Pause playback
- **resume** - Resume from paused state
- **seek** - Jump to position
- **next** - Skip to next track in queue
- **prev** - Restart current track (or go to previous)

See [arch/action_models/playback_actions.yang](../action_models/playback_actions.yang) for detailed action specifications.

## State Management

### Device ID Generation

Each browser session gets a unique device ID:
```elixir
# Generated in PlayerLive.mount/3
device_id = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :upper)
# Example: "A1B2C3D4E5F6G7H8"
```

Device ID is:
- Stored in Phoenix session
- Persists across page reloads within same browser session
- Used as key for playback state lookup

### State Persistence

Playback state persists to database on every change:
```elixir
Media.update_playback_state(device_id, %{
  current_file_id: file.id,
  position_seconds: 45.2,
  queue_json: encode_queue(queue)
})
```

This enables:
- Resuming playback after page reload
- Syncing state across multiple tabs
- Recovering position in track after browser restart

### Queue Management

Queue stored as JSON array of audio file IDs:
```json
[1, 5, 12, 3]
```

Queue operations:
- **Add to queue**: Append ID to array
- **Remove from queue**: Filter out ID
- **Next track**: Pop first ID, load corresponding file
- **Replace queue**: Overwrite entire array (used by playlist loading)

## Audio Element Integration

### JavaScript Hooks

MediaStream uses `phoenix-colocated` for LiveView hooks. Hooks wire up bidirectional communication between HTML5 audio element and LiveView.

**Key Events**:
- `playing` → `audio_playing` event to LiveView
- `pause` → `audio_paused` event to LiveView
- `timeupdate` → `audio_time_update` event (with position)
- `ended` → `audio_ended` event (triggers auto-advance)
- `loadedmetadata` → `audio_metadata_loaded` event (with duration)

### Position Updates

Position updates are throttled to reduce database load:
- Audio element fires `timeupdate` ~4 times per second
- JavaScript hook debounces/throttles updates
- Only significant position changes sent to server
- Server updates database and broadcasts to other tabs

## Real-time Synchronization

### PubSub Architecture

Every playback state update broadcasts via Phoenix PubSub:

```elixir
# In Media.update_playback_state/2
PubSub.broadcast(
  MediaStream.PubSub,
  "playback:#{device_id}",
  {:playback_state_updated, playback_state}
)
```

**Topic format**: `"playback:{device_id}"`

**Subscription**:
```elixir
# In PlayerLive.mount/3
if connected?(socket) do
  PubSub.subscribe(MediaStream.PubSub, "playback:#{device_id}")
end
```

**Handling broadcasts**:
```elixir
# In PlayerLive.handle_info/2
def handle_info({:playback_state_updated, state}, socket) do
  # Sync UI to updated state
  current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
  {:noreply, assign(socket, current_file: current, position: state.position_seconds)}
end
```

### Sync Scenarios

**Same Device, Multiple Tabs**:
- Both tabs have same device_id
- Both subscribe to same PubSub topic
- Changes in one tab broadcast to all subscribers
- Other tabs receive update and sync UI

**Different Devices**:
- Each device has unique device_id
- Each subscribes to separate PubSub topic
- No cross-device interference

## Audio Streaming

### HTTP Range Request Support

The AudioController implements HTTP range requests (RFC 7233) to support seeking:

**Controller**: [lib/media_stream_web/controllers/audio_controller.ex](../../lib/media_stream_web/controllers/audio_controller.ex)

**Supported Range Formats**:
- `bytes=START-END` - Specific byte range
- `bytes=START-` - From byte to end of file
- `bytes=-BYTES` - Last N bytes of file

**Response Codes**:
- `200 OK` - Full file (no range header)
- `206 Partial Content` - Range request fulfilled
- `404 Not Found` - File not on disk

**Headers Set**:
- `Content-Type`: Audio MIME type (from file_type)
- `Accept-Ranges`: bytes
- `Content-Range`: Byte range served (on 206 responses)
- `Content-Length`: Size of content being sent

See [arch/diagrams/streaming_sequence.mmd](../diagrams/streaming_sequence.mmd) for detailed sequence diagram.

## Edge Cases

### File Deleted From Disk

- Audio file record exists in database
- File path no longer exists on filesystem
- **Behavior**: AudioController returns 404
- **Improvement**: Could detect on playback attempt and mark file as missing

### Queue Item Deleted

- File in queue is deleted from database
- **Behavior**: When advancing to deleted item, raises `Ecto.NoResultsError`
- **Improvement**: Filter queue to only valid IDs before displaying

### Concurrent Position Updates

- User seeks in one tab while audio plays in another
- **Behavior**: Last write wins (database update is atomic)
- **Result**: Position may jump unexpectedly if seeking while playing

### Session Expiry

- User closes browser (session cleared)
- Reopens browser (new session, potentially new device_id)
- **Behavior**: Playback state not restored (new device_id)
- **Improvement**: Could use persistent cookie or localStorage for device_id

## Performance Considerations

### Database Write Frequency

Position updates happen continuously during playback:
- Throttled to ~1 update per second (configurable)
- SQLite handles single-row updates efficiently
- No performance issues observed in testing

### PubSub Broadcast Volume

Every position update broadcasts to PubSub:
- Phoenix PubSub is highly optimized for this
- Only subscribed processes receive messages
- No observed bottlenecks

### File Serving

Uses Plug's `send_file/4` with range support:
- Efficient zero-copy streaming
- No file loading into memory
- Operating system handles buffering

## Future Enhancements

### Shuffle Mode
- Add shuffle_mode boolean to PlaybackState
- Randomize queue order when enabled
- Preserve original order for un-shuffle

### Repeat Modes
- Repeat One: Re-queue same track after completion
- Repeat All: Re-queue entire queue after last track

### Crossfade
- Preload next track before current ends
- Fade out current while fading in next
- Requires multiple audio elements

### Volume Normalization
- Analyze track loudness
- Apply gain to normalize perceived volume
- Requires audio analysis library

### Gapless Playback
- Eliminate silence between tracks
- Requires precise timing with audio element
- May need Web Audio API

## Related Documentation

- **Data Models**: [playback_state.yang](../data_models/playback_state.yang), [audio_file.yang](../data_models/audio_file.yang)
- **Action Models**: [playback_actions.yang](../action_models/playback_actions.yang)
- **Diagrams**: [pubsub_flow.mmd](../diagrams/pubsub_flow.mmd), [streaming_sequence.mmd](../diagrams/streaming_sequence.mmd)
- **Implementation**: [player_live.ex](../../lib/media_stream_web/live/player_live.ex), [audio_controller.ex](../../lib/media_stream_web/controllers/audio_controller.ex)
