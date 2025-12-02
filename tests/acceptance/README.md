# Acceptance Tests

Comprehensive acceptance tests for MediaStream written in Gherkin (BDD) format.

## Overview

These acceptance tests define the expected behavior of MediaStream from a user's perspective. They are written in Gherkin, a business-readable domain-specific language that describes software behavior without detailing how that behavior is implemented.

## Structure

```
tests/acceptance/
├── playback.feature               # Audio playback and transport controls
├── library_management.feature     # Library scanning, search, playlists
├── listening_history.feature      # History tracking and analytics
├── real_time_sync.feature        # Multi-tab synchronization
└── README.md                      # This file
```

## Gherkin Format

### Basic Syntax

```gherkin
Feature: Feature Name
  As a [role]
  I want to [feature]
  So that [benefit]

  Scenario: Scenario Name
    Given [precondition]
    When [action]
    Then [expected result]
    And [additional result]
```

### Keywords

- **Feature**: High-level description of a software feature
- **Scenario**: Concrete example illustrating a business rule
- **Given**: Preconditions/context
- **When**: Action/event
- **Then**: Expected outcome
- **And/But**: Additional steps
- **Background**: Steps that run before each scenario
- **Scenario Outline**: Template with examples
- **@tag**: Metadata for filtering/organization

## Feature Files

### [playback.feature](playback.feature)

**Scenarios**: 25+ scenarios covering audio playback

**Key Areas**:
- Basic playback controls (play, pause, resume, stop)
- Seeking (drag, click, during pause)
- Queue management (add, remove, next, auto-advance)
- Previous/restart functionality
- State persistence across page reloads
- Error handling (missing files, network issues)
- Audio element events (time updates, metadata, ended)
- Performance (rapid operations)

**Example**:
```gherkin
Scenario: Play an audio file
  Given I see a list of audio files
  When I click the play button for "Dark Side of the Moon"
  Then the audio player should load the file
  And playback should start
  And I should see "Now Playing: Dark Side of the Moon"
```

### [library_management.feature](library_management.feature)

**Scenarios**: 30+ scenarios covering library operations

**Key Areas**:
- Directory scanning (recursive, subdirectories, existing files)
- Supported audio formats (mp3, flac, m4a, ogg, wav, aac)
- Metadata extraction
- Playlist loading (M3U/M3U8, relative paths, comments, missing files)
- Search (by title, artist, album, live updates)
- Library display and sorting
- Error handling (permissions, non-existent paths)
- Performance (large directories, large libraries)

**Example**:
```gherkin
Scenario: Scan directory for audio files
  Given I have a directory "/test/music" with 10 audio files
  When I enter "/test/music" in the directory path field
  And I click the "Scan Directory" button
  Then the system should scan the directory recursively
  And I should see "Scanned 10 files: 10 added, 0 skipped"
```

### [listening_history.feature](listening_history.feature)

**Scenarios**: 25+ scenarios covering history tracking

**Key Areas**:
- Viewing history (all entries, empty state, completed/incomplete)
- Recording history (create on start, update on completion, partial listening)
- Date filtering (range, single day, invalid range)
- Search (by title, artist, combined with date filter)
- Device filtering (all devices, current device only)
- Sorting and display
- Analytics and statistics (future)
- Data management (persistence, large datasets)
- Completion tracking
- Edge cases (rapid cycles, clock skew)

**Example**:
```gherkin
Scenario: Create history entry on playback start
  Given I am on the player page
  When I start playing "Bohemian Rhapsody"
  Then a history entry should be created
  And the entry should have:
    | Field          | Value              |
    | audio_file_id  | ID of track        |
    | device_id      | Current device ID  |
    | started_at     | Current timestamp  |
```

### [real_time_sync.feature](real_time_sync.feature)

**Scenarios**: 30+ scenarios covering synchronization

**Key Areas**:
- Multi-tab synchronization (playback, pause, seek, queue)
- Device ID management (same session, different browsers, persistence)
- State persistence (reload, new tab, first visit)
- PubSub communication (broadcasts, subscriptions)
- Synchronization latency (<50ms target)
- Conflict resolution (last write wins)
- Multiple tabs scenarios (3+ tabs, many tabs)
- Network interruption and recovery
- Database persistence (write before broadcast)
- Session restoration (complex state, browser restart)
- Edge cases (self-broadcast, rapid changes, closed tabs)
- Performance (large queues, many updates)

**Example**:
```gherkin
Scenario: Sync playback across two tabs
  Given I open the player in Tab 1
  And I open the player in Tab 2
  And both tabs have the same device ID
  When I play "Bohemian Rhapsody" in Tab 1
  Then Tab 2 should automatically update within 1 second
  And both tabs should show the same state
```

## Running Tests

### Prerequisites

To run these Gherkin tests, you'll need a BDD test framework. Options for Elixir:

**Option 1: White Bread** (Gherkin for Elixir)
```bash
# Add to mix.exs
{:white_bread, "~> 4.5", only: [:test]}

# Generate step definitions
mix white_bread.run --only acceptance

# Run tests
mix test --only acceptance
```

**Option 2: Cabbage** (Pure Elixir BDD)
```bash
# Add to mix.exs
{:cabbage, "~> 0.3.0", only: [:test]}

# Run tests
mix test
```

**Option 3: Manual Implementation**
Implement step definitions using ExUnit and use feature files as documentation.

### Running Specific Features

```bash
# Run all acceptance tests
mix test tests/acceptance/

# Run specific feature
mix test tests/acceptance/playback.feature

# Run specific scenario (if framework supports)
mix test tests/acceptance/playback.feature:10

# Run tagged scenarios
mix test --only @future  # Run future scenarios
mix test --exclude @future  # Skip future scenarios
```

## Implementing Step Definitions

### Example Step Implementation (White Bread)

```elixir
# tests/acceptance/steps/playback_steps.exs
defmodule MediaStream.AcceptanceSteps.Playback do
  use WhiteBread.Context
  use Hound.Helpers

  given_ ~r/^I see a list of audio files$/, fn state ->
    navigate_to("/")
    assert visible_in_page?(~r/Audio Files/)
    {:ok, state}
  end

  when_ ~r/^I click the play button for "(?<title>[^"]+)"$/,
    fn state, %{title: title} ->
      click({:css, "[data-title='#{title}'] .play-button"})
      {:ok, Map.put(state, :playing_title, title)}
    end

  then_ ~r/^playback should start$/, fn state ->
    assert visible_in_page?(~r/Now Playing/)
    {:ok, state}
  end
end
```

### Example with ExUnit

```elixir
# tests/acceptance/playback_test.exs
defmodule MediaStream.PlaybackAcceptanceTest do
  use MediaStreamWeb.ConnCase
  use Hound.Helpers

  describe "Play an audio file" do
    setup do
      # Given: I see a list of audio files
      {:ok, view, _html} = live(conn, "/")
      %{view: view}
    end

    test "plays audio when play button clicked", %{view: view} do
      # When: I click the play button
      view |> element(".play-button") |> render_click()

      # Then: playback should start
      assert render(view) =~ "Now Playing"
    end
  end
end
```

## Test Data Setup

### Database Seeding

```elixir
# tests/support/fixtures/audio_files.ex
defmodule MediaStream.Fixtures.AudioFiles do
  def audio_file_fixture(attrs \\ %{}) do
    {:ok, audio_file} =
      attrs
      |> Enum.into(%{
        path: "/test/music/#{Enum.random(1..1000)}.mp3",
        title: "Test Track",
        artist: "Test Artist",
        album: "Test Album",
        duration_seconds: 180,
        file_type: ".mp3",
        file_size: 5_000_000
      })
      |> MediaStream.Media.create_audio_file()

    audio_file
  end

  def create_sample_library(count \\ 10) do
    Enum.map(1..count, fn i ->
      audio_file_fixture(%{
        title: "Track #{i}",
        artist: "Artist #{rem(i, 3) + 1}",
        album: "Album #{rem(i, 2) + 1}"
      })
    end)
  end
end
```

### Test Helpers

```elixir
# tests/support/acceptance_helpers.ex
defmodule MediaStream.AcceptanceHelpers do
  use Hound.Helpers

  def play_track(title) do
    find_element(:css, "[data-title='#{title}'] .play-button")
    |> click()
  end

  def wait_for_playback_start do
    retry_until(fn ->
      visible_in_page?(~r/Now Playing/)
    end)
  end

  def get_queue_tracks do
    find_all_elements(:css, ".queue-item")
    |> Enum.map(&visible_text/1)
  end

  def seek_to_position(seconds) do
    find_element(:css, ".seek-bar")
    |> click()
    # Calculate position based on seek bar width and target seconds
  end
end
```

## Tags and Organization

### Using Tags

```gherkin
@wip
Scenario: Work in progress scenario
  # Test under development

@smoke
Scenario: Critical smoke test
  # Must pass for release

@future
Scenario: Planned feature
  # Not yet implemented

@slow
Scenario: Long-running test
  # Takes >5 seconds
```

### Running Tagged Tests

```bash
# Run only smoke tests
mix test --only acceptance:smoke

# Skip slow tests
mix test --exclude acceptance:slow

# Run WIP tests
mix test --only acceptance:wip
```

## Best Practices

### Writing Good Scenarios

**DO**:
- Write from user perspective
- Focus on behavior, not implementation
- Use business language
- Be specific about expected outcomes
- Keep scenarios independent
- Use scenario outlines for similar tests with different data

**DON'T**:
- Reference UI elements specifically (buttons, IDs, classes)
- Include technical implementation details
- Make scenarios dependent on each other
- Write overly long scenarios (>10 steps)
- Use vague assertions ("it should work")

### Example: Good vs Bad

**Bad**:
```gherkin
Scenario: Click button
  Given I am on the page
  When I click the #play-button-42
  Then the JavaScript function playAudio() should be called
```

**Good**:
```gherkin
Scenario: Play audio file
  Given I see a list of audio files
  When I play "Bohemian Rhapsody"
  Then playback should start
  And I should hear the audio
```

## Maintenance

### Keeping Tests Updated

1. **Update scenarios when features change**
   - Modify existing scenarios to reflect new behavior
   - Add new scenarios for new features
   - Mark removed features with `@deprecated` or delete

2. **Keep step definitions DRY**
   - Reuse common steps across features
   - Extract helper functions
   - Use shared contexts

3. **Review regularly**
   - Run tests in CI/CD pipeline
   - Fix failing tests immediately
   - Remove obsolete tests
   - Update documentation

### Test Coverage

Current coverage by feature:
- ✅ Playback: 25+ scenarios
- ✅ Library Management: 30+ scenarios
- ✅ Listening History: 25+ scenarios
- ✅ Real-Time Sync: 30+ scenarios

**Total**: 110+ acceptance scenarios

## Integration with CI/CD

### GitHub Actions Example

```yaml
# .github/workflows/acceptance_tests.yml
name: Acceptance Tests

on: [push, pull_request]

jobs:
  acceptance:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'

      - name: Install dependencies
        run: mix deps.get

      - name: Setup database
        run: mix ecto.setup

      - name: Run acceptance tests
        run: mix test tests/acceptance/ --only acceptance

      - name: Generate coverage report
        run: mix coveralls.html
```

## Future Enhancements

### Planned Improvements

1. **Visual Testing**
   - Screenshot comparison
   - Visual regression detection
   - Accessibility testing

2. **Performance Testing**
   - Load time measurements
   - Memory usage tracking
   - Database query counting

3. **API Testing**
   - REST API scenarios (if added)
   - WebSocket testing
   - Integration with external services

4. **Mobile Testing**
   - Responsive design tests
   - Touch gesture support
   - Mobile browser compatibility

## Related Documentation

- **Architecture**: [../../arch/](../../arch/)
- **Feature Docs**: [../../arch/features/](../../arch/features/)
- **Data Models**: [../../arch/data_models/](../../arch/data_models/)
- **Action Models**: [../../arch/action_models/](../../arch/action_models/)
- **Implementation**: [../../lib/](../../lib/)

## Resources

### Gherkin

- **Cucumber Documentation**: https://cucumber.io/docs/gherkin/
- **Gherkin Reference**: https://cucumber.io/docs/gherkin/reference/
- **Best Practices**: https://cucumber.io/docs/bdd/better-gherkin/

### Elixir BDD Tools

- **White Bread**: https://github.com/meadsteve/white-bread
- **Cabbage**: https://github.com/cabbage-ex/cabbage
- **ExUnit**: https://hexdocs.pm/ex_unit/ExUnit.html

### Testing Tools

- **Hound**: https://github.com/HashNuke/hound (Browser automation)
- **Wallaby**: https://github.com/elixir-wallaby/wallaby (Feature testing)
- **Phoenix.LiveViewTest**: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
