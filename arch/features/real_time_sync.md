# Real-Time Synchronization Feature

## Overview

Real-time synchronization enables playback state to sync instantly across multiple browser tabs and windows on the same device. Changes in one tab immediately reflect in all other open tabs.

## User Flows

### Multi-Tab Sync Flow

1. User opens MediaStream in Tab A
2. User opens MediaStream in Tab B (same browser)
3. User plays a track in Tab A
4. Tab B instantly updates to show same track playing
5. User seeks to position 45s in Tab B
6. Tab A instantly updates to same position
7. User adds track to queue in Tab A
8. Tab B's queue instantly updates

### Session Restoration Flow

1. User plays a track
2. User seeks to position 1:23
3. User closes browser
4. User reopens browser
5. User reopens MediaStream
6. Playback state restored: same track, position 1:23
7. User can resume playback from exact position

## Technical Implementation

### Architecture Overview

```text
Tab 1 → PlayerLive 1 → Media Context → Database
                           ↓
                        PubSub
                           ↓
Tab 2 ← PlayerLive 2 ←────┘
```

See [arch/diagrams/pubsub_flow.mmd](../diagrams/pubsub_flow.mmd) for detailed sequence diagram.

### Components

**Phoenix PubSub**: Built-in real-time messaging
**Device ID**: Session-scoped unique identifier
**PlaybackState**: Per-device persistent state

## Device ID Management

### Generation

Device ID generated on first session via the DeviceId plug, which also initializes a Comn context:

```elixir
# In DeviceId plug
device_id = get_session(conn, "device_id") || generate_device_id()
Comn.Contexts.new(%{metadata: %{device_id: device_id}})

# In LiveView mount (separate process, sets its own context)
device_id = session["device_id"] || generate_device_id()
Comn.Contexts.new(%{metadata: %{device_id: device_id}})
```

**Format**: 16-character uppercase hexadecimal
**Example**: `"A1B2C3D4E5F6G7H8"`

### Storage

**Phoenix Session**:

- Encrypted session cookie
- Persists across page reloads
- Scoped to browser session
- Cleared when browser closes (by default)

**Alternative Approaches**:

- localStorage: Persists indefinitely
- Server-side session: Requires session store
- User account: Requires authentication

### Scope

**Same Device ID when**:

- Multiple tabs in same browser
- Page reloads in same session
- Same browser window

**Different Device ID when**:

- Different browser (Chrome vs Firefox)
- Incognito/Private browsing
- Session cleared
- Different computer

## PubSub Architecture

### Topic Structure

Format: `"playback:#{device_id}"`

**Examples**:

- `"playback:A1B2C3D4E5F6G7H8"`
- `"playback:1234567890ABCDEF"`

### Subscription

LiveView subscribes on connection:

```elixir
def mount(_params, session, socket) do
  device_id = session["device_id"] || generate_device_id()

  if connected?(socket) do
    PubSub.subscribe(MediaStream.PubSub, "playback:#{device_id}")
  end

  # Load existing state from database
  playback_state = Media.get_playback_state(device_id)

  {:ok, assign(socket, device_id: device_id, ...)}
end
```

**Why `connected?/1` guard?**

- LiveView mounts twice: once for static render, once for WebSocket
- Only subscribe on WebSocket connection
- Avoids subscription during static render

### Broadcasting

Every state change creates a structured Comn event, logs it, and broadcasts:

```elixir
defp broadcast_playback_update({:ok, playback_state} = result) do
  event = Comn.Events.EventStruct.new(
    :playback_state_updated,
    "playback:#{playback_state.device_id}",
    playback_state,
    :media_stream
  )
  Comn.EventLog.record(event)
  PubSub.broadcast(
    MediaStream.PubSub,
    "playback:#{playback_state.device_id}",
    {:event, event.topic, event}
  )

  result
end
```

**Triggered by**:

- Play/pause/resume
- Seek position change
- Queue modifications (add/remove)
- Next/previous track

### Receiving Updates

Handle structured event broadcast in LiveView:

```elixir
def handle_info({:event, "playback:" <> _, %Comn.Events.EventStruct{type: :playback_state_updated, data: state}}, socket) do
  # Sync from other tab
  current = if state.current_file_id, do: Media.get_audio_file!(state.current_file_id)
  queue_ids = decode_queue(state.queue_json)
  queue_files = Enum.map(queue_ids, &Media.get_audio_file!/1)

  {:noreply,
   socket
   |> assign(:current_file, current)
   |> assign(:queue, queue_files)
   |> assign(:position, state.position_seconds || 0.0)}
end
```

## State Persistence

### Database Schema

```sql
CREATE TABLE playback_states (
  id INTEGER PRIMARY KEY,
  device_id STRING NOT NULL UNIQUE,
  current_file_id INTEGER REFERENCES audio_files(id),
  position_seconds FLOAT DEFAULT 0.0,
  queue_json TEXT,
  inserted_at DATETIME,
  updated_at DATETIME
);
```

See [arch/data_models/playback_state.yang](../data_models/playback_state.yang) for complete schema.

### Update Strategy

**Upsert Pattern**:

```elixir
def update_playback_state(device_id, attrs) do
  case get_playback_state(device_id) do
    nil ->
      %PlaybackState{device_id: device_id}
      |> PlaybackState.changeset(attrs)
      |> Repo.insert()
      |> broadcast_playback_update()

    playback_state ->
      playback_state
      |> PlaybackState.changeset(attrs)
      |> Repo.update()
      |> broadcast_playback_update()
  end
end
```

**Key Points**:

- INSERT if state doesn't exist
- UPDATE if state exists
- Broadcast after successful database write
- Atomic operation per device_id

### Write Frequency

**Position Updates**:

- Audio element fires `timeupdate` ~4 times/second
- Client-side throttling reduces to ~1 update/second
- Each update writes to database and broadcasts

**Performance**:

- SQLite handles single-row updates efficiently
- No performance issues observed
- PubSub broadcasts are fast (microseconds)

## Synchronization Guarantees

### Eventual Consistency

System uses **eventual consistency** model:

- No distributed transactions
- Updates propagate quickly (milliseconds)
- Brief inconsistency possible during network delays

### Conflict Resolution

**Last Write Wins**:

- No complex conflict resolution
- Most recent database update wins
- Works well for single-user scenario

**Potential Conflicts**:

1. Two tabs seek simultaneously
   - Both write to database
   - Last write wins
   - Both tabs sync to last position
   - Brief position jump possible

2. Two tabs modify queue simultaneously
   - Last write overwrites
   - Queue may briefly show inconsistent state
   - Resolves to last written state

### Ordering

**No strict ordering guarantees**:

- PubSub delivers messages quickly but not instantaneously
- Database writes are ordered per connection
- Cross-tab updates may arrive out of order if rapid

**Practical Impact**:

- Rarely noticeable to users
- Sub-second latency typical
- Good enough for music player use case

## Performance Characteristics

### Latency

**Typical Sync Latency**:

- Tab A action → Database write: <5ms
- Database write → PubSub broadcast: <1ms
- PubSub → Tab B receive: <1ms
- Tab B render update: <10ms
- **Total**: <20ms (imperceptible to user)

### Throughput

**PubSub Capacity**:

- Phoenix PubSub handles thousands of messages/second
- No throttling needed for this use case
- Single device generates <10 messages/second (max)

### Scalability

**Per-Device Topics**:

- Each device has separate topic
- No cross-device broadcast overhead
- Scales linearly with concurrent users

**Database Load**:

- One UPDATE per state change per device
- SQLite easily handles hundreds of updates/second
- No scaling concerns for single-user deployment

## Client-Side Integration

### JavaScript Hooks

Hooks bridge LiveView and HTML5 audio element:

```javascript
// Example hook structure (simplified)
let AudioHook = {
  mounted() {
    this.audio = this.el.querySelector("audio")

    // Listen to audio events
    this.audio.addEventListener("timeupdate", () => {
      this.pushEvent("audio_time_update", {
        position: this.audio.currentTime
      })
    })

    // Listen to LiveView updates
    this.handleEvent("sync_position", ({position}) => {
      if (Math.abs(this.audio.currentTime - position) > 1.0) {
        this.audio.currentTime = position
      }
    })
  }
}
```

### Preventing Feedback Loops

**Problem**: Position update causes sync, which causes position update, etc.

**Solution**: Threshold-based sync

```javascript
// Only sync if position differs by >1 second
if (Math.abs(this.audio.currentTime - position) > 1.0) {
  this.audio.currentTime = position
}
```

## Edge Cases

### Self-Broadcast Reception

**Scenario**: Tab receives its own broadcast

**Behavior**:

- Tab A sends update
- PubSub broadcasts to all subscribers
- Tab A receives update it sent

**Handling**:

- Usually ignored (idempotent)
- UI already reflects change
- Broadcast serves as confirmation

### Rapid State Changes

**Scenario**: User rapidly seeks multiple times

**Behavior**:

- Multiple database writes queued
- Multiple broadcasts sent
- All subscribers receive all updates
- Subscribers sync to latest position

**Optimization Opportunity**:

- Debounce rapid updates
- Only send final position after pause
- Reduces database/broadcast load

### Tab Closed Mid-Update

**Scenario**: Tab closes while update in-flight

**Behavior**:

- Update may complete in database
- PubSub broadcast sent
- Other tabs receive update normally
- No issues, graceful handling

### Network Interruption

**Scenario**: WebSocket disconnects temporarily

**Behavior**:

- LiveView automatically reconnects
- State reloaded from database on reconnect
- Sync resumes after reconnection
- Possible brief desync during interruption

### Multiple Device IDs

**Scenario**: User accidentally has multiple device IDs

**Causes**:

- Session cleared
- Switching browsers
- Incognito mode

**Behavior**:

- Each device_id has separate state
- No sync across different device_ids
- Each operates independently

**User Impact**:

- Separate playback states
- Confusing if unexpected
- Could show "merge states" option

## Testing Synchronization

### Manual Testing

1. Open two browser tabs
2. Play track in Tab 1
3. Verify Tab 2 updates within 1 second
4. Seek in Tab 2
5. Verify Tab 1 reflects new position
6. Add to queue in Tab 1
7. Verify Tab 2 shows updated queue

### Automated Testing

```elixir
test "playback state syncs across live views" do
  device_id = "TEST1234"

  # Mount two LiveViews with same device_id
  {:ok, view1, _html} = live(conn, "/", session: %{"device_id" => device_id})
  {:ok, view2, _html} = live(conn, "/", session: %{"device_id" => device_id})

  # Play in view1
  view1 |> element("button#play-42") |> render_click()

  # Assert view2 receives update
  assert render(view2) =~ "Now Playing"
end
```

## Future Enhancements

### Cross-Device Sync

**Requires**:

- User authentication
- Link multiple device_ids to account
- Sync across devices for same user

**Benefits**:

- Start on phone, continue on desktop
- True multi-device experience

### Offline Support

**Progressive Web App**:

- Service worker for offline playback
- Sync queue when online
- Local storage for state

### Conflict Resolution UI

**Smart Merging**:

- Detect conflicting updates
- Show "Another tab made changes" notification
- Let user choose which state to keep

### Broadcast Optimization

**Differential Updates**:

- Only broadcast changed fields
- Reduce message size
- Faster propagation

**Batching**:

- Batch multiple updates
- Send single broadcast for related changes
- Reduce PubSub load

### State History

**Undo/Redo**:

- Track state change history
- Enable undo of accidental changes
- Useful for queue modifications

## Related Documentation

- **Data Models**: [playback_state.yang](../data_models/playback_state.yang)
- **Action Models**: [playback_actions.yang](../action_models/playback_actions.yang)
- **Diagrams**: [pubsub_flow.mmd](../diagrams/pubsub_flow.mmd), [system_architecture.mmd](../diagrams/system_architecture.mmd)
- **Implementation**: [player_live.ex](../../lib/media_stream_web/live/player_live.ex), [media.ex](../../lib/media_stream/media.ex)
