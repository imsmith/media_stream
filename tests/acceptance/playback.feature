Feature: Audio Playback
  As a user
  I want to play audio files with full transport controls
  So that I can listen to my music collection

  Background:
    Given the application is running
    And the database is seeded with sample audio files
    And I am on the player page

  # Basic Playback

  Scenario: Play an audio file
    Given I see a list of audio files
    When I click the play button for "Dark Side of the Moon"
    Then the audio player should load the file
    And playback should start
    And I should see "Now Playing: Dark Side of the Moon"
    And the play button should change to a pause button

  Scenario: Pause playback
    Given I am playing "Bohemian Rhapsody"
    When I click the pause button
    Then playback should pause
    And the current position should be preserved
    And the pause button should change to a play button

  Scenario: Resume playback
    Given I have paused playback at position 45 seconds
    When I click the play button
    Then playback should resume from position 45 seconds
    And the play button should change to a pause button

  Scenario: Stop playback
    Given I am playing "Hotel California"
    When I click the stop button
    Then playback should stop
    And the position should reset to 0
    And the play button should be enabled

  # Seeking

  Scenario: Seek to position using seek bar
    Given I am playing a track with duration 180 seconds
    When I drag the seek bar to position 90 seconds
    Then playback should jump to position 90 seconds
    And the time display should show "1:30"

  Scenario: Seek by clicking seek bar
    Given I am playing a track with duration 240 seconds
    When I click at 25% position on the seek bar
    Then playback should jump to position 60 seconds
    And the time display should show "1:00"

  Scenario: Seek during paused state
    Given playback is paused at position 30 seconds
    When I seek to position 60 seconds
    Then the position should update to 60 seconds
    And playback should remain paused

  # Queue Management

  Scenario: Add track to queue
    Given I am viewing the library
    When I click "Add to Queue" for "Stairway to Heaven"
    Then "Stairway to Heaven" should appear in the queue
    And I should see a confirmation message

  Scenario: Remove track from queue
    Given the queue contains 5 tracks
    And "Sweet Child O' Mine" is in the queue
    When I click the remove button for "Sweet Child O' Mine"
    Then "Sweet Child O' Mine" should be removed from the queue
    And the queue should contain 4 tracks

  Scenario: Play next track in queue
    Given the queue contains ["Track 1", "Track 2", "Track 3"]
    And I am playing "Track 1"
    When I click the next button
    Then "Track 2" should start playing
    And the queue should contain ["Track 3"]
    And "Track 1" should be removed from the queue

  Scenario: Auto-advance to next track
    Given the queue contains ["Song A", "Song B"]
    And I am playing "Song A"
    When the current track ends
    Then "Song B" should automatically start playing
    And the queue should be empty
    And a history entry should be created for "Song A"

  Scenario: Next button with empty queue
    Given I am playing a track
    And the queue is empty
    When I click the next button
    Then playback should stop
    And I should see "No more tracks in queue"

  # Previous/Restart

  Scenario: Restart current track
    Given I am playing a track at position 45 seconds
    When I click the previous button
    Then the track should restart from position 0
    And playback should continue

  Scenario: Previous when at beginning
    Given I am playing a track at position 2 seconds
    When I click the previous button
    Then the track should restart from position 0

  # Playback State Persistence

  Scenario: Playback state persists on page reload
    Given I am playing "Imagine" at position 90 seconds
    And the queue contains ["Track X", "Track Y"]
    When I reload the page
    Then "Imagine" should be selected as current track
    And the position should be restored to 90 seconds
    And the queue should still contain ["Track X", "Track Y"]
    And I should be able to resume playback

  Scenario: Empty state on first visit
    Given I am visiting the application for the first time
    When I navigate to the player page
    Then no track should be playing
    And the queue should be empty
    And the position should be 0

  # Error Handling

  Scenario: File not found on disk
    Given the database contains "Missing File"
    But the file does not exist on the filesystem
    When I try to play "Missing File"
    Then I should see an error message "File not found"
    And playback should not start
    And the player should remain in stopped state

  Scenario: Network interruption during playback
    Given I am playing a track
    When the network connection is lost
    Then playback may continue from buffer
    And when the connection is restored
    Then the player should reconnect
    And state should sync with the server

  # Audio Element Events

  Scenario: Time updates during playback
    Given I start playing a track
    When playback progresses
    Then the time display should update continuously
    And the seek bar should move forward
    And the position should be saved periodically

  Scenario: Metadata loaded event
    Given I click play on a track
    When the audio metadata loads
    Then the duration should be displayed
    And the seek bar should be properly scaled

  Scenario: Audio ended event
    Given I am playing the last track
    And the queue is empty
    When the track finishes
    Then playback should stop
    And a completion history entry should be created
    And I should see "Playback complete"

  # Volume and Audio Settings (Future)

  @future
  Scenario: Adjust volume
    Given I am playing a track
    When I drag the volume slider to 50%
    Then the audio volume should be set to 50%
    And the volume setting should be persisted

  @future
  Scenario: Mute audio
    Given I am playing a track
    When I click the mute button
    Then the audio should be muted
    And the mute button should show muted state
    And the previous volume level should be remembered

  # Performance

  Scenario: Rapid seek operations
    Given I am playing a track
    When I seek to position 30 seconds
    And I immediately seek to position 60 seconds
    And I immediately seek to position 45 seconds
    Then the player should handle all seeks
    And the final position should be 45 seconds
    And no errors should occur

  Scenario: Quick play/pause cycles
    Given I am playing a track
    When I click pause
    And I immediately click play
    And I immediately click pause
    And I immediately click play
    Then the player should handle all commands
    And the final state should be playing
    And no errors should occur
