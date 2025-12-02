# Listening History Feature

## Overview

Listening history tracks which audio files were played, when, and for how long. This data enables analytics, resume functionality, and discovering listening patterns.

## User Flows

### View History Flow

1. User clicks "History" link in navigation
2. System displays listening history (most recent first)
3. User sees: track title, artist, started time, duration listened
4. History shows all devices by default

### Filter by Date Range Flow

1. User selects start and end dates in date picker
2. System filters history to selected range
3. UI updates with matching records
4. User can combine with text search

### Search History Flow

1. User enters search query
2. System searches track metadata (title, artist, album)
3. Results filter to matching history entries
4. Can combine with date range filter

### Device Filter Flow

1. User toggles "Show All Devices" / "Current Device Only"
2. System filters history by device_id
3. UI shows only selected device's history

## Technical Implementation

### Components

**Location**: [lib/media_stream_web/live/history_live.ex](../../lib/media_stream_web/live/history_live.ex)

**Context**: [lib/media_stream/media.ex](../../lib/media_stream/media.ex)

### Data Models

- **ListeningHistory** ([arch/data_models/listening_history.yang](../data_models/listening_history.yang))
  - Tracks individual listening sessions
  - Foreign key to AudioFile
  - Device ID for per-device tracking
  - Temporal fields: started_at, completed_at
  - Duration tracking

### Actions

See [arch/action_models/history_actions.yang](../action_models/history_actions.yang) for complete specifications:

- **list-history** - Get all history
- **search-history** - Search by date/metadata
- **create-history-entry** - Record new session
- **update-history-entry** - Mark session complete
- **filter-by-date** - Filter by date range
- **toggle-device-filter** - Switch device scope
- **get-statistics** - Aggregate analytics

## History Recording

### Session Creation

History entry created when playback starts:

```elixir
def create_listening_history(attrs) do
  %MediaStream.Media.ListeningHistory{}
  |> MediaStream.Media.ListeningHistory.changeset(attrs)
  |> Repo.insert()
end

# Called when play button clicked
Media.create_listening_history(%{
  audio_file_id: 42,
  device_id: "A1B2C3D4E5F6G7H8",
  started_at: DateTime.utc_now(),
  duration_listened_seconds: 0
})
```

### Session Completion

Updated when track completes or user stops:

```elixir
# When audio_ended event fires
Media.update_listening_history(history_id, %{
  completed_at: DateTime.utc_now(),
  duration_listened_seconds: actual_duration
})
```

### Incomplete Sessions

Sessions may remain incomplete (completed_at = NULL) if:
- User navigates away during playback
- Browser crashes or closes
- Playback interrupted by error

These represent partial listening sessions.

## Querying History

### List All History

```elixir
def list_listening_history do
  from(h in MediaStream.Media.ListeningHistory,
    order_by: [desc: h.started_at],
    preload: [:audio_file]
  )
  |> Repo.all()
end
```

**Key Points**:
- Ordered by `started_at DESC` (most recent first)
- Preloads `audio_file` association for display
- No pagination (returns all records)

### Filter by Device

```elixir
def list_listening_history(device_id) do
  query =
    from(h in MediaStream.Media.ListeningHistory,
      order_by: [desc: h.started_at],
      preload: [:audio_file]
    )

  query = where(query, [h], h.device_id == ^device_id)
  Repo.all(query)
end
```

### Search by Date Range

```elixir
def search_listening_history(start_date, end_date, query \\ nil) do
  start_datetime = DateTime.new!(start_date, ~T[00:00:00])
  end_datetime = DateTime.new!(end_date, ~T[23:59:59])

  base_query =
    from(h in MediaStream.Media.ListeningHistory,
      where: h.started_at >= ^start_datetime and h.started_at <= ^end_datetime,
      order_by: [desc: h.started_at],
      preload: [:audio_file]
    )

  # Optional text search on audio file metadata
  query =
    if query do
      search_term = "%#{query}%"
      from(h in base_query,
        join: a in assoc(h, :audio_file),
        where:
          ilike(a.title, ^search_term) or
          ilike(a.artist, ^search_term) or
          ilike(a.album, ^search_term)
      )
    else
      base_query
    end

  Repo.all(query)
end
```

### Query Performance

**Indexes Used**:
- `started_at` - For date range filtering
- `device_id` - For device filtering
- `audio_file_id` - For join to audio_files

**Join Performance**:
- Preload uses separate query (N+1 avoided)
- Alternative: Use join with `select` for single query

**Pagination**:
- Not currently implemented
- Should add for large datasets (thousands of records)

## UI Implementation

### History Display

```elixir
# In HistoryLive template
<div :for={entry <- @history}>
  <div>
    <%= entry.audio_file.title %>
    by <%= entry.audio_file.artist %>
  </div>
  <div>
    Started: <%= format_datetime(entry.started_at) %>
    Duration: <%= format_duration(entry.duration_listened_seconds) %>
  </div>
</div>
```

### Date Range Picker

HTML5 date inputs:
```heex
<input type="date" name="start_date" value={@start_date} />
<input type="date" name="end_date" value={@end_date} />
<button phx-click="filter_by_date">Filter</button>
```

### Device Toggle

```heex
<button phx-click="toggle_device_filter">
  <%= if @show_all_devices, do: "Current Device Only", else: "Show All Devices" %>
</button>
```

## Analytics and Statistics

### Available Metrics

**Count Metrics**:
- Total listening sessions
- Completed sessions
- Incomplete sessions
- Unique files played

**Duration Metrics**:
- Total time listened
- Average session duration
- Time listened per day/week/month

**Top Lists**:
- Most played tracks
- Most played artists
- Most played albums
- Longest sessions

### Implementation Example

```elixir
def get_listening_statistics(device_id \\ nil) do
  query = from(h in ListeningHistory)
  query = if device_id, do: where(query, [h], h.device_id == ^device_id), else: query

  %{
    total_plays: Repo.aggregate(query, :count),
    total_time: Repo.aggregate(query, :sum, :duration_listened_seconds),
    avg_duration: Repo.aggregate(query, :avg, :duration_listened_seconds),
    completion_rate: calculate_completion_rate(query)
  }
end

defp calculate_completion_rate(query) do
  total = Repo.aggregate(query, :count)
  completed = query |> where([h], not is_nil(h.completed_at)) |> Repo.aggregate(:count)
  if total > 0, do: completed / total * 100, else: 0
end
```

### Top Played Tracks

```elixir
def get_top_played(limit \\ 10) do
  from(h in ListeningHistory,
    group_by: h.audio_file_id,
    order_by: [desc: count(h.id)],
    limit: ^limit,
    select: {h.audio_file_id, count(h.id)},
    preload: [:audio_file]
  )
  |> Repo.all()
end
```

## Data Relationships

### Cascade Behavior

**When AudioFile Deleted**:
- Listening history records CASCADE DELETE
- All history for that file is removed
- Rationale: History without file reference is meaningless

**Alternative Approach**:
- Keep history, set audio_file_id to NULL
- Store snapshot of file metadata in history table
- Preserves historical data even after file deletion

### Association Preloading

Always preload `audio_file` when displaying history:

```elixir
# Good: Single query per batch
preload: [:audio_file]

# Bad: N+1 queries
# Don't access entry.audio_file without preload
```

## Edge Cases

### Clock Skew

- User's system clock is wrong
- **Impact**: Incorrect timestamps in history
- **Mitigation**: Use server time (`DateTime.utc_now()`) not client time

### Duplicate Sessions

- Rapid play/pause creates multiple sessions
- **Behavior**: Each play creates new history entry
- **Result**: Many short sessions for same track
- **Improvement**: Merge sessions within short time window

### Long Sessions

- User leaves track playing for hours
- **Behavior**: Duration tracked accurately
- **Result**: Very long duration_listened_seconds
- **Improvement**: Cap duration at track length

### Incomplete Session Cleanup

- Many incomplete sessions accumulate
- **Behavior**: No automatic cleanup
- **Storage**: Grows unbounded
- **Improvement**: Periodic cleanup of old incomplete sessions

### Time Zone Handling

- All timestamps stored as UTC
- **Display**: Should convert to user's local time zone
- **Current**: Displays UTC (not ideal UX)
- **Improvement**: Store user's time zone preference, convert on display

## Future Enhancements

### Listening Insights

- "You listened to 45 hours of music this month"
- "Your top artist this week: Artist Name"
- "You discovered 12 new artists"
- Spotify Wrapped-style year-in-review

### Resume Functionality

- "Continue listening to X where you left off"
- Store last position for incomplete sessions
- Auto-resume on next play

### Recommendations

- "Based on your history, you might like..."
- Collaborative filtering (if multiple users)
- Genre/mood-based recommendations

### Export Data

- Export history as CSV
- Export listening statistics
- GDPR compliance (user data export)

### Session Merging

- Merge consecutive sessions for same track
- Detect pause/resume within short timeframe
- Create single continuous session

### Listening Streaks

- Track consecutive days of listening
- Gamification elements
- Achievement system

### Playlist Generation

- "Create playlist from this month's top tracks"
- Generate playlists based on history
- Save as M3U or database playlist

### Data Retention Policy

- Automatically archive old history (>1 year)
- Compress historical data
- Aggregate to summary statistics

## Privacy Considerations

### Device ID as Identifier

- Device ID is pseudonymous
- Links sessions to specific browser
- Could be used to track user behavior

### Cross-Device Tracking

- No cross-device correlation currently
- Each device has separate history
- Future: User accounts could link devices

### Data Deletion

- No UI for deleting history
- Future: "Clear history" button
- Comply with privacy regulations (GDPR, CCPA)

## Related Documentation

- **Data Models**: [listening_history.yang](../data_models/listening_history.yang), [audio_file.yang](../data_models/audio_file.yang)
- **Action Models**: [history_actions.yang](../action_models/history_actions.yang)
- **Implementation**: [history_live.ex](../../lib/media_stream_web/live/history_live.ex), [media.ex](../../lib/media_stream/media.ex)
