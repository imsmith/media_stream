Feature: Library Management
  As a user
  I want to manage my audio library
  So that I can organize and access my music collection

  Background:
    Given the application is running
    And I am on the player page

  # Directory Scanning

  Scenario: Scan directory for audio files
    Given I have a directory "/test/music" with 10 audio files
    When I enter "/test/music" in the directory path field
    And I click the "Scan Directory" button
    Then the system should scan the directory recursively
    And I should see "Scanned 10 files: 10 added, 0 skipped"
    And all 10 files should appear in the library
    And each file should have extracted metadata

  Scenario: Scan directory with subdirectories
    Given I have a directory structure:
      | /test/music/rock       | 5 files  |
      | /test/music/jazz       | 3 files  |
      | /test/music/classical  | 7 files  |
    When I scan "/test/music"
    Then the system should find all 15 files
    And I should see "Scanned 15 files: 15 added, 0 skipped"
    And files from all subdirectories should be in the library

  Scenario: Scan directory with existing files
    Given the library already contains 5 files from "/test/music"
    And the directory "/test/music" has 8 files total
    When I scan "/test/music" again
    Then the system should detect duplicates by path
    And I should see "Scanned 8 files: 3 added, 5 skipped"
    And the library should contain 8 unique files
    And no duplicate entries should exist

  Scenario: Scan directory with mixed file types
    Given I have a directory with:
      | File Type | Count |
      | .mp3      | 5     |
      | .flac     | 3     |
      | .jpg      | 2     |
      | .txt      | 1     |
    When I scan the directory
    Then only audio files should be added
    And I should see "Scanned 8 files: 8 added, 0 skipped"
    And .jpg and .txt files should be ignored

  Scenario: Scan empty directory
    Given I have an empty directory "/test/empty"
    When I scan "/test/empty"
    Then I should see "Scanned 0 files: 0 added, 0 skipped"
    And no files should be added to the library

  Scenario: Scan non-existent directory
    Given the directory "/test/nonexistent" does not exist
    When I attempt to scan "/test/nonexistent"
    Then I should see an error "Directory not found"
    And no changes should be made to the library

  Scenario: Scan directory without read permission
    Given I have a directory "/test/restricted" without read permission
    When I attempt to scan "/test/restricted"
    Then I should see an error "Permission denied"
    And no files should be added

  # Supported Audio Formats

  Scenario Outline: Scan supported audio formats
    Given I have a file "test.<extension>" in the scan directory
    When I scan the directory
    Then the file should be added to the library
    And the file type should be ".<extension>"

    Examples:
      | extension |
      | mp3       |
      | m4a       |
      | flac      |
      | ogg       |
      | wav       |
      | aac       |

  # Metadata Extraction

  Scenario: Basic metadata extraction
    Given I scan a directory with audio files
    When the scan completes
    Then each file should have:
      | Field           | Source           |
      | path            | Full file path   |
      | title           | Filename         |
      | artist          | "Unknown"        |
      | album           | "Unknown"        |
      | duration        | 0 (placeholder)  |
      | file_type       | Extension        |
      | file_size       | Actual size      |

  # Playlist Loading

  Scenario: Load M3U playlist
    Given I have a playlist file "favorites.m3u" containing:
      """
      /music/song1.mp3
      /music/song2.mp3
      /music/song3.mp3
      """
    And all files exist in the library
    When I upload "favorites.m3u"
    Then the queue should be replaced with the playlist tracks
    And I should see "Loaded 3 tracks from playlist"
    And the tracks should be in playlist order

  Scenario: Load M3U8 playlist
    Given I have a UTF-8 playlist "日本の音楽.m3u8"
    And it contains files with Unicode names
    When I upload the playlist
    Then Unicode filenames should be handled correctly
    And all matching tracks should load

  Scenario: Load playlist with relative paths
    Given I have a playlist at "/playlists/rock.m3u"
    And it contains relative paths like "../music/song.mp3"
    When I upload the playlist
    Then relative paths should be resolved
    And matching files should be loaded

  Scenario: Load playlist with comments
    Given I have a playlist with:
      """
      #EXTM3U
      #EXTINF:180,Artist - Title
      /music/song1.mp3
      # This is a comment
      /music/song2.mp3
      """
    When I upload the playlist
    Then comments should be ignored
    And 2 tracks should be loaded

  Scenario: Load playlist with missing files
    Given I have a playlist containing 5 tracks
    But only 3 tracks exist in the library
    When I upload the playlist
    Then only the 3 matching tracks should be added to queue
    And I should see "Loaded 3 tracks from playlist"
    And missing tracks should be silently skipped

  Scenario: Load empty playlist
    Given I have an empty playlist file
    When I upload the playlist
    Then I should see "No matching tracks found in playlist"
    And the queue should remain unchanged

  Scenario: Load playlist with all files missing
    Given I have a playlist with 5 tracks
    But none of the files are in the library
    When I upload the playlist
    Then I should see "No matching tracks found in playlist"
    And the queue should be empty

  # Search

  Scenario: Search by title
    Given the library contains:
      | Title               | Artist      | Album          |
      | Bohemian Rhapsody   | Queen       | A Night at Opera |
      | Another One Bites   | Queen       | The Game       |
      | Imagine             | John Lennon | Imagine        |
    When I search for "rhapsody"
    Then I should see 1 result
    And "Bohemian Rhapsody" should be displayed

  Scenario: Search by artist
    Given the library contains multiple tracks by "Queen"
    When I search for "queen"
    Then all tracks by "Queen" should be displayed
    And the search should be case-insensitive

  Scenario: Search by album
    Given the library contains tracks from "Dark Side of the Moon"
    When I search for "dark side"
    Then all tracks from that album should be displayed

  Scenario: Search across multiple fields
    Given the library contains:
      | Title    | Artist  | Album     |
      | Hello    | Adele   | 25        |
      | Hello    | Lionel  | Can't Slow Down |
    When I search for "hello"
    Then both tracks should be displayed
    And results should include different artists

  Scenario: Search with no results
    Given the library is populated
    When I search for "nonexistent123"
    Then I should see "No results found"
    And the library list should be empty

  Scenario: Clear search returns all results
    Given I have searched for "queen"
    And the results are filtered
    When I clear the search box
    Then all library files should be displayed
    And the full library should be visible

  Scenario: Live search updates
    Given the library contains many tracks
    When I type "b" in the search box
    Then results should filter to tracks matching "b"
    When I type "e" (making "be")
    Then results should further filter to tracks matching "be"
    And the search should update in real-time

  # Library Display

  Scenario: View all library files
    Given the library contains 50 audio files
    When I navigate to the player page
    Then all 50 files should be displayed
    And each file should show title, artist, and album
    And each file should have a play button

  Scenario: Empty library state
    Given the library contains no files
    When I navigate to the player page
    Then I should see "No audio files found"
    And I should see instructions to scan a directory

  Scenario: Library sorted by title
    Given the library contains unsorted files
    When I view the library
    Then files should be sorted alphabetically by title
    And the sort order should be consistent

  # File Management (Future)

  @future
  Scenario: Delete file from library
    Given the library contains "Test Track"
    When I click the delete button for "Test Track"
    And I confirm the deletion
    Then "Test Track" should be removed from the library
    And the database record should be deleted
    But the physical file should remain on disk

  @future
  Scenario: Edit file metadata
    Given I select "Track Name" in the library
    When I click "Edit Metadata"
    And I change the title to "New Title"
    And I save the changes
    Then the title should update to "New Title"
    And the changes should persist

  @future
  Scenario: Bulk add to queue
    Given I select 5 tracks in the library
    When I click "Add Selected to Queue"
    Then all 5 tracks should be added to the queue
    And they should maintain their selection order

  # Performance

  Scenario: Scan large directory
    Given I have a directory with 1000 audio files
    When I scan the directory
    Then the scan should complete within 30 seconds
    And all 1000 files should be added
    And the UI should remain responsive

  Scenario: Search large library
    Given the library contains 10000 tracks
    When I search for a term
    Then results should appear within 1 second
    And the search should be performant

  # Error Recovery

  Scenario: Resume after failed scan
    Given a directory scan fails halfway through
    When I retry the scan
    Then previously added files should be skipped
    And the scan should continue from where it failed
    And no duplicate entries should be created
