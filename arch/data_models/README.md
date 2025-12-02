# Data Models

This directory contains YANG data models for all MediaStream database schemas.

## Overview

YANG (Yet Another Next Generation) is an industry-standard data modeling language defined by IETF RFC 6020 and RFC 7950. We use YANG to provide:

- **Strong typing** with built-in constraints
- **Machine-readable** documentation for tooling
- **Hierarchical structure** that matches Ecto schemas
- **Relationship modeling** via leafref
- **Validation rules** and constraints

## Data Models

### [audio_file.yang](audio_file.yang)

Represents audio files in the media library.

**Key Fields**:
- `path` - Unique filesystem path (UK)
- `title`, `artist`, `album` - Metadata (indexed)
- `duration_seconds` - Track length
- `file_type`, `file_size` - File characteristics

**Constraints**:
- Unique constraint on `path`
- Indexes on `title`, `artist`, `album` for search

**Relationships**:
- Referenced by PlaybackState (`current_file_id`)
- Referenced by ListeningHistory (`audio_file_id`)

### [playback_state.yang](playback_state.yang)

Per-device playback state for multi-device sync.

**Key Fields**:
- `device_id` - Unique device identifier (UK)
- `current_file_id` - FK to currently playing file
- `position_seconds` - Playback position (float)
- `queue_json` - Serialized queue (JSON array of IDs)

**Constraints**:
- Unique constraint on `device_id` (one state per device)
- Foreign key to AudioFile with `ON DELETE NILIFY_ALL`

**Purpose**:
- Enables session persistence
- Supports multi-tab synchronization via PubSub
- Stores playback queue

### [listening_history.yang](listening_history.yang)

Tracks listening sessions for analytics and history.

**Key Fields**:
- `audio_file_id` - FK to played file
- `device_id` - Device that played the file
- `started_at` - Session start time (indexed)
- `completed_at` - Session end time (optional, indexed)
- `duration_listened_seconds` - Time listened

**Constraints**:
- Foreign key to AudioFile with `ON DELETE CASCADE`
- Required: `audio_file_id`, `device_id`, `started_at`

**Purpose**:
- Analytics and insights
- Listening history display
- Usage tracking per device

## Type Mappings

YANG types are mapped to Ecto types as follows:

| Ecto Type | YANG Type | Notes |
|-----------|-----------|-------|
| `:string` | `string` | Variable length text |
| `:integer` | `int32` or `int64` | 32-bit for durations, 64-bit for IDs/sizes |
| `:float` | `decimal64` | Precise decimal with fraction-digits |
| `:utc_datetime` | `yang:date-and-time` | ISO 8601 timestamp |
| `:text` | `string` | Long text (note in description) |
| `:id` (auto) | `int64` | Auto-incremented primary key |

## Constraint Representation

Ecto constraints are represented in YANG using:

| Ecto | YANG | Example |
|------|------|---------|
| `unique_constraint` | Custom extension `ecto-unique` | `audio:ecto-unique;` |
| `validate_required` | `mandatory true` | Built-in YANG statement |
| `foreign_key` | `leafref` | Points to referenced leaf path |
| `default` | `default` | Built-in YANG statement |
| Indexes | Custom extension `ecto-index` | `audio:ecto-index;` |

## Relationship Diagram

```
AudioFile (1) ──┬── (0..N) PlaybackState
                │         └─ ON DELETE: NILIFY_ALL
                │
                └── (0..N) ListeningHistory
                          └─ ON DELETE: CASCADE
```

See [../diagrams/data_relationships.mmd](../diagrams/data_relationships.mmd) for full ER diagram.

## YANG Extensions

Custom extensions for Ecto-specific concepts:

```yang
extension ecto-index {
  description "Marks field as indexed in database";
}

extension ecto-unique {
  description "Marks field as having unique constraint";
}
```

These extensions annotate fields but don't affect YANG validation.

## Validation

YANG models can be validated using standard tools:

```bash
# Install pyang (Python-based YANG validator)
pip install pyang

# Validate a YANG module
pyang audio_file.yang

# Generate tree view
pyang -f tree audio_file.yang

# Generate documentation
pyang -f html audio_file.yang > audio_file.html
```

## Usage in Development

### Understanding Schema

Before modifying a schema:
1. Read the corresponding YANG model
2. Understand constraints and relationships
3. Update YANG model alongside Ecto schema
4. Keep models in sync

### Adding New Fields

When adding a field to an Ecto schema:
1. Add corresponding `leaf` to YANG model
2. Specify type and constraints
3. Add description documentation
4. Update migration
5. Regenerate documentation if needed

### Changing Relationships

When modifying foreign keys:
1. Update `leafref` in YANG model
2. Update `on-delete` behavior documentation
3. Update migration
4. Update relationship diagrams

## Related Documentation

- **Diagrams**: [../diagrams/data_relationships.mmd](../diagrams/data_relationships.mmd)
- **Implementation**: [../../lib/media_stream/media/](../../lib/media_stream/media/)
- **Migrations**: [../../priv/repo/migrations/](../../priv/repo/migrations/)
