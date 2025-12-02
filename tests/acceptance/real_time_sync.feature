Feature: Real-Time Synchronization
  As a user
  I want my playback state to sync across browser tabs
  So that I can seamlessly switch between tabs

  Background:
    Given the application is running
    And I am using Chrome browser

  # Multi-Tab Synchronization

  Scenario: Sync playback across two tabs
    Given I open the player in Tab 1
    And I open the player in Tab 2
    And both tabs have the same device ID
    When I play "Bohemian Rhapsody" in Tab 1
    Then Tab 2 should automatically update within 1 second
    And Tab 2 should show "Bohemian Rhapsody" as now playing
    And both tabs should display the same track

  Scenario: Sync pause state across tabs
    Given I have 2 tabs open
    And "Track A" is playing in both tabs
    When I pause playback in Tab 1
    Then Tab 2 should show paused state within 1 second
    And both tabs should display the same position

  Scenario: Sync seek position across tabs
    Given I have 2 tabs open
    And a track is playing in both tabs at position 30 seconds
    When I seek to position 90 seconds in Tab 1
    Then Tab 2 should jump to position 90 seconds within 1 second
    And both tabs should be at the same position

  Scenario: Sync queue changes across tabs
    Given I have 2 tabs open
    When I add "Track X" to queue in Tab 1
    Then Tab 2 should show updated queue within 1 second
    And "Track X" should appear in Tab 2's queue

  Scenario: Sync queue removal across tabs
    Given I have 2 tabs open
    And the queue contains ["Song 1", "Song 2", "Song 3"]
    When I remove "Song 2" from queue in Tab 1
    Then Tab 2 should show updated queue within 1 second
    And Tab 2's queue should show ["Song 1", "Song 3"]

  Scenario: Sync next track across tabs
    Given I have 2 tabs open
    And the queue contains ["Track A", "Track B"]
    And "Track A" is playing
    When I click next in Tab 1
    Then Tab 2 should switch to "Track B" within 1 second
    And both tabs should play "Track B"
    And both tabs should show updated queue

  # Device ID Management

  Scenario: Same device ID in multiple tabs
    Given I open Tab 1
    And the device ID is "ABC123"
    When I open Tab 2 in the same browser session
    Then Tab 2 should have device ID "ABC123"
    And both tabs should share the same playback state

  Scenario: Different device IDs in different browsers
    Given I open the player in Chrome with device ID "CHROME1"
    And I open the player in Firefox with device ID "FIREFOX1"
    When I play a track in Chrome
    Then Firefox should not sync
    And each browser should maintain separate state

  Scenario: Device ID persists across page reloads
    Given I am using device ID "DEVICE789"
    When I reload the page
    Then the device ID should still be "DEVICE789"
    And my playback state should be restored

  Scenario: Device ID cleared on session end
    Given I am using device ID "TEMP123"
    When I close all browser tabs
    And I reopen the browser (new session)
    Then a new device ID should be generated
    And the old playback state should not be loaded

  # State Persistence

  Scenario: Restore playback state after page reload
    Given I am playing "Imagine" at position 90 seconds
    And the queue contains ["Track 1", "Track 2"]
    When I reload the page
    Then "Imagine" should be selected
    And the position should be 90 seconds
    And the queue should contain ["Track 1", "Track 2"]
    And I should be able to resume playback

  Scenario: Restore state in new tab
    Given I am playing a track in Tab 1
    When I open a new tab (Tab 2) in the same session
    Then Tab 2 should load the current playback state
    And Tab 2 should show the same track and position
    And both tabs should be synchronized

  Scenario: Empty state on first visit
    Given I am visiting the application for the first time
    When the page loads
    Then no track should be selected
    And the queue should be empty
    And the position should be 0
    And a new device ID should be generated

  # PubSub Communication

  Scenario: PubSub broadcast on play
    Given I have 2 tabs open with same device ID
    When I play a track in Tab 1
    Then a PubSub message should be broadcast to "playback:{device_id}"
    And Tab 2 should receive the message
    And Tab 2 should update its state

  Scenario: PubSub broadcast on state change
    Given I have tabs open
    When any playback state changes (play, pause, seek, queue)
    Then a broadcast should be sent via PubSub
    And all subscribed tabs should receive the update
    And all tabs should sync within 100ms

  Scenario: Tab subscribes to PubSub on connect
    Given I open a new tab
    When the LiveView connection establishes
    Then the tab should subscribe to "playback:{device_id}"
    And it should start receiving state updates
    And it should load current state from database

  Scenario: Tab unsubscribes on close
    Given I have Tab 1 open and subscribed
    When I close Tab 1
    Then the subscription should be cleaned up
    And no more messages should be sent to that tab

  # Synchronization Latency

  Scenario: Fast synchronization
    Given I have 2 tabs open
    When I make a state change in Tab 1
    Then Tab 2 should receive the update within 50ms
    And the sync should feel instantaneous to the user

  Scenario: Position updates throttled
    Given I am playing a track
    When the position updates continuously during playback
    Then updates should be throttled to ~1 per second
    And not every position update should broadcast
    And database writes should be minimized

  # Conflict Resolution

  Scenario: Concurrent seek operations
    Given I have 2 tabs open
    When I seek to 30 seconds in Tab 1
    And I simultaneously seek to 60 seconds in Tab 2
    Then the last write should win
    And both tabs should converge to the same position
    And one of the positions (last written) should be final

  Scenario: Concurrent queue modifications
    Given I have 2 tabs open
    And the queue contains ["A", "B", "C"]
    When I remove "B" in Tab 1
    And I simultaneously add "D" in Tab 2
    Then the last write should win
    And both tabs should show the same queue
    And the queue should be in a consistent state

  # Multiple Tabs Scenarios

  Scenario: Three tabs synchronized
    Given I have 3 tabs open (Tab 1, Tab 2, Tab 3)
    And all have the same device ID
    When I play a track in Tab 1
    Then Tab 2 should sync
    And Tab 3 should sync
    And all 3 tabs should show the same state

  Scenario: Sync with many tabs open
    Given I have 10 tabs open with the same device ID
    When I make a state change in any tab
    Then all 10 tabs should receive the update
    And all should sync within 1 second
    And there should be no performance degradation

  # Network Interruption

  Scenario: Sync after network reconnection
    Given I have 2 tabs open
    And Tab 1 loses network connection
    When I make changes in Tab 2
    Then Tab 1 should not receive updates while offline
    When Tab 1's connection is restored
    Then Tab 1 should reload state from database
    And Tab 1 should sync to current state

  Scenario: Offline changes don't sync
    Given I have 2 tabs open
    And Tab 1 goes offline
    When I make changes in Tab 1 (offline)
    Then Tab 2 should not receive updates
    And the changes should only be local to Tab 1

  Scenario: Reconnection syncs state
    Given a tab was disconnected
    When the WebSocket reconnects
    Then the LiveView should fetch current state
    And the UI should update to match server state
    And synchronization should resume

  # Database Persistence

  Scenario: State persists to database
    Given I play a track
    When the state changes
    Then the change should be written to playback_states table
    And the database should be the source of truth
    And the state should be queryable

  Scenario: Database updated before broadcast
    Given I make a state change
    Then the database should be updated first
    And only after successful update should broadcast occur
    And this ensures consistency

  Scenario: Upsert pattern for playback state
    Given my device has no playback state record
    When I play a track
    Then a new playback_states record should be INSERTed
    When I make another change
    Then the existing record should be UPDATEd
    And there should only be one record per device_id

  # Session Restoration

  Scenario: Restore complex state
    Given I have a complex playback state:
      | Current track | Track ID 42                    |
      | Position      | 125.5 seconds                  |
      | Queue         | [10, 15, 20, 25, 30]           |
      | Playing       | true                           |
    When I reload the page
    Then all state should be restored exactly
    And the queue should be in the same order
    And I can continue playback from the same position

  Scenario: Restore after browser restart
    Given I have saved playback state
    When I close the browser completely
    And I reopen the browser (same session cookie)
    Then my device ID should be restored
    And my playback state should be loaded
    And I can resume where I left off

  # Edge Cases

  Scenario: Self-broadcast reception
    Given I have Tab 1 open
    When I make a change in Tab 1
    Then Tab 1 receives its own broadcast
    But Tab 1 should handle it gracefully
    And it should be idempotent (no double-update)

  Scenario: Rapid state changes
    Given I have 2 tabs open
    When I make 10 rapid state changes in Tab 1
    Then all changes should propagate
    And Tab 2 should receive all updates
    And Tab 2 should converge to the final state
    And no updates should be lost

  Scenario: Tab closed during sync
    Given I have 2 tabs open
    When I make a change in Tab 1
    And I immediately close Tab 2 (during sync)
    Then the system should handle it gracefully
    And no errors should occur
    And Tab 1 should continue working normally

  # Performance

  Scenario: Sync with large queue
    Given I have a queue with 100 tracks
    When I modify the queue in Tab 1
    Then Tab 2 should sync efficiently
    And the entire queue should be transmitted
    And sync should complete within 1 second

  Scenario: Many rapid position updates
    Given I am playing a track
    When position updates fire every 250ms
    Then updates should be throttled
    And only periodic updates should broadcast
    And the database should not be overwhelmed

  Scenario: PubSub scales with users
    Given there are 100 concurrent users
    And each user has 2-3 tabs open
    When state changes occur
    Then PubSub should handle the load
    And each user's tabs should sync independently
    And there should be no cross-user leakage

  # Audio Element Sync

  Scenario: Audio element plays on sync
    Given I have 2 tabs open
    And Tab 1 is playing a track
    When Tab 2 receives the sync update
    Then Tab 2's audio element should load the track
    And Tab 2's audio should start playing
    And Tab 2 should seek to the current position

  Scenario: Audio element pauses on sync
    Given I have 2 tabs open
    And both tabs are playing
    When I pause in Tab 1
    Then Tab 2's audio element should pause
    And no audio should be playing in Tab 2

  Scenario: Prevent audio feedback loop
    Given I have 2 tabs open
    When position updates fire from audio element
    Then updates should not create infinite loops
    And sync should be threshold-based (>1 second difference)
    And minor position differences should be ignored
