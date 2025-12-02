Feature: Listening History
  As a user
  I want to track my listening history
  So that I can see what I've played and discover patterns

  Background:
    Given the application is running
    And I have an established listening history

  # Viewing History

  Scenario: View listening history
    Given I have played 10 tracks today
    When I navigate to the history page
    Then I should see 10 history entries
    And entries should be ordered by most recent first
    And each entry should show:
      | Field            |
      | Track title      |
      | Artist name      |
      | Album name       |
      | Started time     |
      | Completed status |
      | Duration         |

  Scenario: Empty history state
    Given I have never played any tracks
    When I navigate to the history page
    Then I should see "No listening history yet"
    And I should see instructions to start playing music

  Scenario: History shows only completed entries
    Given I have:
      | Track      | Status     |
      | Track 1    | Completed  |
      | Track 2    | Completed  |
      | Track 3    | Incomplete |
    When I view the history
    Then I should see all 3 entries
    And completed entries should show completion time
    And incomplete entries should show "In Progress" or blank completion time

  # Recording History

  Scenario: Create history entry on playback start
    Given I am on the player page
    When I start playing "Bohemian Rhapsody"
    Then a history entry should be created
    And the entry should have:
      | Field          | Value                    |
      | audio_file_id  | ID of track              |
      | device_id      | Current device ID        |
      | started_at     | Current timestamp        |
      | completed_at   | NULL                     |
      | duration       | 0                        |

  Scenario: Update history entry on completion
    Given I am playing a track
    And a history entry exists for this session
    When the track plays to the end
    Then the history entry should be updated
    And completed_at should be set to current timestamp
    And duration_listened_seconds should reflect playback time

  Scenario: Partial listening recorded
    Given I start playing a 180-second track
    When I listen for 60 seconds
    And I skip to the next track
    Then the history entry should show:
      | Field                      | Value         |
      | completed_at               | NULL          |
      | duration_listened_seconds  | ~60           |

  Scenario: Multiple plays of same track
    Given I play "Imagine" at 10:00 AM
    And I play "Imagine" again at 2:00 PM
    When I view the history
    Then I should see 2 separate entries for "Imagine"
    And they should have different started_at timestamps

  # Date Filtering

  Scenario: Filter history by date range
    Given I have listening history spanning 30 days
    When I select date range from "2025-01-01" to "2025-01-07"
    And I click "Filter"
    Then I should see only entries within that date range
    And entries outside the range should not be displayed

  Scenario: Filter by single day
    Given I have history from multiple days
    When I select today's date for both start and end
    Then I should see only today's listening history

  Scenario: Filter with invalid date range
    Given I am on the history page
    When I set start date to "2025-01-31"
    And I set end date to "2025-01-01"
    And I attempt to filter
    Then I should see an error "End date must be after start date"
    And the filter should not be applied

  Scenario: Clear date filter
    Given I have applied a date filter
    And the results are filtered
    When I click "Clear Filter" or "Show All"
    Then all history entries should be displayed
    And the date filter should be reset

  # Search History

  Scenario: Search history by track title
    Given my history contains:
      | Title              | Artist       |
      | Bohemian Rhapsody  | Queen        |
      | Another One Bites  | Queen        |
      | Imagine            | John Lennon  |
    When I search history for "rhapsody"
    Then I should see 1 result
    And "Bohemian Rhapsody" should be displayed

  Scenario: Search history by artist
    Given my history includes multiple tracks by "Queen"
    When I search history for "queen"
    Then all "Queen" tracks in history should be displayed
    And the search should be case-insensitive

  Scenario: Combine date filter and search
    Given I have history spanning 90 days
    When I filter to last 7 days
    And I search for "beatles"
    Then I should see only "Beatles" tracks from last 7 days
    And both filters should be applied

  # Device Filtering

  Scenario: View all devices' history
    Given I have used multiple devices
    And Device A has 10 history entries
    And Device B has 5 history entries
    When I view history with "Show All Devices"
    Then I should see 15 entries total
    And entries from both devices should be visible

  Scenario: Filter to current device only
    Given I have used 3 different devices
    And my current device has 7 history entries
    When I toggle to "Current Device Only"
    Then I should see only 7 entries
    And they should all be from my current device

  Scenario: Toggle between device filters
    Given I am viewing "All Devices" history
    When I click "Current Device Only"
    Then the view should update to show current device
    When I click "Show All Devices"
    Then the view should update to show all devices
    And the toggle should update accordingly

  # Sorting and Display

  Scenario: History sorted by most recent
    Given I have played tracks at different times
    When I view the history
    Then entries should be ordered by started_at DESC
    And the most recently played track should be first

  Scenario: History shows track metadata
    Given I play a track with full metadata
    When I view the history entry
    Then I should see:
      | Title   | From audio file metadata |
      | Artist  | From audio file metadata |
      | Album   | From audio file metadata |
    And the data should be preloaded (no N+1 queries)

  Scenario: History entry links to audio file
    Given I have a history entry for "Test Track"
    When I click on the entry
    Then I should be able to play that track
    And the track should load in the player

  # Analytics and Statistics

  @future
  Scenario: View listening statistics
    Given I have 30 days of listening history
    When I navigate to the statistics page
    Then I should see:
      | Metric                    |
      | Total plays               |
      | Total time listened       |
      | Unique tracks played      |
      | Most played track         |
      | Most played artist        |
      | Average session duration  |

  @future
  Scenario: Top played tracks
    Given I have listening history
    When I view "Top Tracks"
    Then I should see tracks ranked by play count
    And each track should show number of plays

  @future
  Scenario: Listening trends over time
    Given I have 90 days of history
    When I view "Listening Trends"
    Then I should see a chart of listening activity
    And I should see patterns by day, week, or month

  # Data Management

  Scenario: History persists after file deletion
    Given I have a history entry for "Track X"
    When the audio file "Track X" is deleted from library
    Then the history entry should be deleted (CASCADE)
    And I should no longer see it in history

  Scenario: Large history dataset
    Given I have 1000 history entries
    When I view the history page
    Then the first 100 entries should load
    And pagination or infinite scroll should be available
    And the page should load within 2 seconds

  # Privacy and Data

  Scenario: History is device-specific by default
    Given I use Device A to play tracks
    And I switch to Device B
    When I view history on Device B
    Then I should see Device B's history
    And Device A's history should not be visible
    Unless I toggle "Show All Devices"

  @future
  Scenario: Export history data
    Given I have listening history
    When I click "Export History"
    Then I should be able to download a CSV file
    And the file should contain all history entries
    And it should include all fields

  @future
  Scenario: Clear history
    Given I have listening history
    When I click "Clear All History"
    And I confirm the action
    Then all my history entries should be deleted
    And I should see "No listening history yet"

  @future
  Scenario: Delete specific history entry
    Given I have a history entry I want to remove
    When I click the delete button for that entry
    And I confirm the deletion
    Then that entry should be removed from history
    But other entries should remain

  # Completion Tracking

  Scenario: Track marked complete when finished
    Given I play a 180-second track
    When the track plays to completion (audio_ended event)
    Then completed_at should be set
    And duration_listened_seconds should be ~180

  Scenario: Track marked incomplete on skip
    Given I play a 180-second track
    When I listen for 30 seconds
    And I click next or stop
    Then completed_at should remain NULL
    And duration_listened_seconds should be ~30

  Scenario: Track marked incomplete on navigation
    Given I play a track
    When I navigate away from the page mid-playback
    Then completed_at should remain NULL
    And duration reflects time listened before navigation

  # Edge Cases

  Scenario: Same track played twice in succession
    Given I play "Test Track"
    When the track completes
    And I immediately play "Test Track" again
    Then 2 separate history entries should be created
    And each should have distinct timestamps

  Scenario: Rapid play/stop cycles
    Given I play "Track A"
    And I immediately stop it after 1 second
    And I play "Track B"
    And I immediately stop it after 1 second
    When I view the history
    Then I should see 2 incomplete entries
    And each should show ~1 second duration

  Scenario: History with clock skew
    Given the system time is correct
    When history entries are created
    Then timestamps should be accurate
    And entries should sort correctly chronologically

  Scenario: History during network interruption
    Given I am playing a track
    And a history entry is being tracked
    When the network connection is lost
    Then the history entry may not update in real-time
    But when the connection is restored
    Then pending updates should sync

  # Query Performance

  Scenario: Fast history queries
    Given the database contains 10000 history entries
    When I view the history page
    Then the query should use indexes
    And results should load within 500ms

  Scenario: Efficient metadata joins
    Given I am viewing history
    When the page renders
    Then audio_file data should be preloaded
    And there should be no N+1 query issues
    And the database should perform efficient joins
