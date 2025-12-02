# Media Stream Plan

## Completed Features ✅

- [x] Generate Phoenix LiveView project with SQLite
- [x] Create audio file schema and migration
- [x] Create playback state schema and migration  
- [x] Implement Media context with:
  - [x] `scan_directory/1` - scans for audio files
  - [x] `list_audio_files/0` - lists all files
  - [x] `search_audio_files/1` - searches by title/artist/album
  - [x] `get_playback_state/1` - gets state for device
  - [x] `update_playback_state/2` - updates state + PubSub broadcast
  - [x] `parse_playlist/1` - parses .m3u and .m3u8 files
  - [x] `load_playlist_queue/1` - loads playlist and returns AudioFile structs in order
- [x] Create PlayerLive with real-time sync via PubSub
- [x] Implement HTML5 audio playback with range request support
- [x] Add playlist upload support (.m3u and .m3u8 files)
- [x] Add queue management (add, remove, next, prev)
- [x] Add listening history tracking
- [x] Create HistoryLive with search and filter
- [x] Match brutalist design across all layouts
- [x] Server running on port 4000

## How to Use

1. **Scan audio files**: `iex -S mix` → `Media.scan_directory("/path/to/music")`
2. **Load playlist**: Upload a .m3u or .m3u8 file via the player UI
3. **Play audio**: Click files from library or use playlist queue
4. **View history**: Visit http://localhost:4000/history

