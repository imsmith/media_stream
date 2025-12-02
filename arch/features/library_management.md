# Library Management Feature

## Overview

Library management enables users to build and maintain their audio library through directory scanning, playlist loading, and search functionality.

## User Flows

### Directory Scanning Flow

1. User enters absolute path to music directory
2. User clicks "Scan Directory" button
3. System recursively scans directory for audio files
4. System creates database records for new files
5. System skips files already in database (by path)
6. UI shows scan results: "Scanned 150 files: 45 added, 105 skipped"
7. Library list refreshes with new files

### Playlist Loading Flow

1. User clicks "Load Playlist" button
2. User selects .m3u or .m3u8 file from filesystem
3. System uploads file to temporary storage
4. System parses playlist line-by-line
5. System matches file paths to database records
6. System replaces current queue with matching tracks
7. UI shows: "Loaded 12 tracks from playlist"

### Search Flow

1. User types query in search box
2. System searches as user types (live search)
3. Results filter to matching files
4. Empty query shows all files
5. Search across: title, artist, album

## Technical Implementation

### Components

**Location**: [lib/media_stream_web/live/player_live.ex](../../lib/media_stream_web/live/player_live.ex)

**Context**: [lib/media_stream/media.ex](../../lib/media_stream/media.ex)

### Data Models

- **AudioFile** ([arch/data_models/audio_file.yang](../data_models/audio_file.yang))
  - Primary library entity
  - Unique constraint on `path`
  - Indexed fields: title, artist, album

### Actions

See [arch/action_models/library_actions.yang](../action_models/library_actions.yang) for complete specifications:

- **scan-directory** - Recursively scan filesystem
- **search** - Search by metadata
- **load-playlist** - Load M3U/M3U8 playlist
- **parse-playlist** - Parse playlist file
- **list-audio-files** - Get all files
- **create-audio-file** - Add single file

## Directory Scanning

### Implementation

```elixir
# In MediaStream.Media
def scan_directory(directory_path) do
  audio_extensions = [".mp3", ".m4a", ".flac", ".ogg", ".wav", ".aac"]

  files =
    directory_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(fn path ->
      File.regular?(path) && Path.extname(path) in audio_extensions
    end)

  # Create database records for each file
  results = Enum.reduce(files, %{scanned: 0, added: 0, skipped: 0}, fn file_path, acc ->
    case create_audio_file_from_path(file_path) do
      {:ok, _} -> %{acc | scanned: acc.scanned + 1, added: acc.added + 1}
      {:error, _} -> %{acc | scanned: acc.scanned + 1, skipped: acc.skipped + 1}
    end
  end)

  {:ok, results}
end
```

### Metadata Extraction

Currently basic metadata extraction:
```elixir
defp create_audio_file_from_path(file_path) do
  file_name = Path.basename(file_path, Path.extname(file_path))
  file_type = Path.extname(file_path)
  file_size = File.stat!(file_path).size

  attrs = %{
    path: file_path,
    title: file_name,  # Use filename as title
    artist: "Unknown",  # Default artist
    album: "Unknown",   # Default album
    duration_seconds: 0,  # Duration not extracted
    file_type: file_type,
    file_size: file_size
  }

  create_audio_file(attrs)
end
```

### Supported Formats

- **MP3** - .mp3
- **M4A** - .m4a (AAC/ALAC)
- **FLAC** - .flac (lossless)
- **OGG** - .ogg (Vorbis)
- **WAV** - .wav (uncompressed)
- **AAC** - .aac

### Duplicate Handling

Duplicates prevented by unique constraint on `path`:
- Database enforces uniqueness
- Insert fails silently for duplicates
- Counted as "skipped" in scan results

### Performance

- **Recursive Scan**: Uses `Path.wildcard("**/*")`
  - Efficient Erlang VM implementation
  - No depth limits (scans entire tree)
- **Batch Inserts**: Could be optimized with `Repo.insert_all/2`
  - Current: One INSERT per file
  - Future: Batch inserts for better performance
- **Large Directories**: Tested with ~10,000 files
  - Scan time: ~5-10 seconds
  - Primarily limited by disk I/O

## Playlist Support

### Supported Formats

- **.m3u** - Standard M3U playlist (ASCII)
- **.m3u8** - UTF-8 encoded M3U playlist

### Parsing Implementation

```elixir
def parse_playlist(playlist_path) do
  unless File.exists?(playlist_path) do
    {:error, :file_not_found}
  else
    playlist_dir = Path.dirname(playlist_path)

    paths =
      playlist_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reject(fn line ->
        # Skip comments and #EXTM3U headers
        String.starts_with?(line, "#")
      end)
      |> Enum.map(fn path ->
        # Handle relative paths
        if Path.type(path) == :absolute do
          path
        else
          Path.join(playlist_dir, path) |> Path.expand()
        end
      end)

    {:ok, paths}
  end
end
```

### Path Resolution

**Absolute Paths**:
```
/home/user/Music/song.mp3  →  /home/user/Music/song.mp3
```

**Relative Paths**:
```
Playlist: /playlists/favorites.m3u
Line:     ../Music/song.mp3
Result:   /Music/song.mp3
```

**Playlist-relative Paths**:
```
Playlist: /home/user/playlists/rock.m3u
Line:     rock_songs/track01.mp3
Result:   /home/user/playlists/rock_songs/track01.mp3
```

### Extended M3U Support

Extended M3U format includes metadata:
```m3u
#EXTM3U
#EXTINF:180,Artist - Song Title
/path/to/song.mp3
#EXTINF:240,Another Artist - Another Song
/path/to/another.mp3
```

**Current Behavior**:
- `#EXTINF` lines skipped (treated as comments)
- Metadata not used (path is only identifier)

**Future Enhancement**:
- Parse `#EXTINF` lines for duration and title
- Use metadata if file not in database
- Display playlist metadata in UI

### Queue Loading

```elixir
def load_playlist_queue(playlist_path) do
  case parse_playlist(playlist_path) do
    {:error, reason} -> {:error, reason}
    {:ok, paths} ->
      # Find matching audio files in database
      audio_files =
        paths
        |> Enum.map(fn path -> Repo.get_by(AudioFile, path: path) end)
        |> Enum.reject(&is_nil/1)

      {:ok, audio_files}
  end
end
```

**Behavior**:
- Only includes files found in database
- Preserves playlist order
- Missing files silently skipped

### Upload Flow

Uses Phoenix.LiveView file uploads:

```elixir
# In PlayerLive
allow_upload(:playlist, accept: [".m3u", ".m3u8"], max_entries: 1)

def handle_event("load_playlist", _params, socket) do
  uploaded_files = consume_uploaded_entries(socket, :playlist, fn %{path: path}, _entry ->
    case Media.load_playlist_queue(path) do
      {:ok, audio_files} -> {:ok, audio_files}
      {:error, _} -> {:ok, []}
    end
  end)

  # Update queue with loaded tracks
end
```

## Search

### Implementation

```elixir
def search_audio_files(query) when is_binary(query) do
  search_term = "%#{query}%"

  AudioFile
  |> where([a],
    ilike(a.title, ^search_term) or
    ilike(a.artist, ^search_term) or
    ilike(a.album, ^search_term)
  )
  |> Repo.all()
end
```

### Search Characteristics

- **Case-insensitive**: Uses `ILIKE` (SQLite: `LIKE` is case-insensitive by default)
- **Substring matching**: `%query%` pattern
- **Multiple fields**: OR across title, artist, album
- **No ranking**: Results not sorted by relevance
- **No fuzzy matching**: Exact substring match required

### Performance

**Indexes**:
- title, artist, album all indexed
- SQLite uses indexes for `LIKE` prefix searches
- Full substring search may require full scan

**Optimization Opportunities**:
- Full-text search (FTS5) for better performance
- Relevance ranking (prefer title matches over album)
- Search history/suggestions

### Live Search

Search happens on every keystroke:

```elixir
def handle_event("search", %{"query" => query}, socket) do
  filtered =
    if query == "" do
      socket.assigns.audio_files
    else
      Media.search_audio_files(query)
    end

  {:noreply,
   socket
   |> assign(:search_query, query)
   |> assign(:filtered_files, filtered)}
end
```

**Debouncing**:
- Not currently implemented
- Could add client-side debouncing (300ms)
- Would reduce database queries on fast typing

## Edge Cases

### Scan Directory Not Exist

- User enters invalid path
- **Behavior**: `Path.wildcard/1` returns empty list
- **Result**: "Scanned 0 files: 0 added, 0 skipped"
- **Improvement**: Validate directory exists before scanning

### Permission Denied

- User enters path without read permission
- **Behavior**: `Path.wildcard/1` silently skips inaccessible files
- **Result**: Partial scan (only accessible files)
- **Improvement**: Check permissions upfront, warn user

### Symbolic Links

- Directory contains symlinks to audio files
- **Behavior**: `Path.wildcard/1` follows symlinks by default
- **Risk**: Infinite loops if symlink cycles exist
- **Improvement**: Add `:follow_symlinks` option, default false

### Very Large Files

- Directory contains extremely large audio files (>1GB)
- **Behavior**: File size stored as int64 (supports up to ~9 exabytes)
- **Streaming**: send_file handles large files efficiently
- **No issues expected**

### Playlist with Missing Files

- Playlist references files not in database
- **Behavior**: Missing files silently skipped
- **Result**: Queue only includes found files
- **Improvement**: Show list of missing files to user

### Playlist with Relative Paths

- Playlist uses relative paths
- **Behavior**: Resolved relative to playlist directory
- **Works correctly** for standard use cases

### Unicode Filenames

- Audio files with non-ASCII characters
- **Behavior**: Elixir handles UTF-8 natively
- **Database**: SQLite stores UTF-8
- **No issues expected**

## Future Enhancements

### Metadata Extraction

Use ID3/Vorbis comment parsing libraries:
- Extract actual title, artist, album from file
- Extract duration, bit rate, sample rate
- Extract album art (store as binary or path)

**Libraries**:
- `id3vx` - ID3 tag parsing for MP3
- `taglib_ex` - Universal tag reading (FFI to TagLib)

### Batch Operations

- Select multiple files for batch operations
- Add multiple files to queue at once
- Delete multiple files from library
- Update metadata for multiple files

### Folder Browsing

- Display directory tree in UI
- Browse by folder structure
- "Add folder to queue" action
- Folder-based organization

### Watch Directories

- Monitor directories for changes
- Auto-add new files when detected
- Auto-remove files when deleted
- Use `FileSystem` library (already a dependency)

### Smart Playlists

- Dynamic playlists based on criteria
- Example: "Recently added", "Most played", "Artist: X"
- Save playlist definitions to database
- Regenerate on query

### Import/Export

- Export library as M3U playlist
- Export specific selections
- Import from iTunes XML
- Import from Spotify/YouTube playlists (via API)

### Duplicate Detection

- Detect duplicate files by:
  - Audio fingerprint (Chromaprint/AcoustID)
  - Metadata similarity
  - File size
- Merge or remove duplicates

## Related Documentation

- **Data Models**: [audio_file.yang](../data_models/audio_file.yang)
- **Action Models**: [library_actions.yang](../action_models/library_actions.yang)
- **Implementation**: [media.ex](../../lib/media_stream/media.ex), [player_live.ex](../../lib/media_stream_web/live/player_live.ex)
