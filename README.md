# bbbevents

![Travis CI](https://api.travis-ci.org/blindsidenetworks/bbb-events.svg?branch=master)

bbbevents is a simple ruby gem that makes it easier to parse data from a recordings events.xml file.

This gem is currently being used on the recording server to parse events and build meeting dashboards.

## Testing

```
bundle install --path vendor/bundle
```

Copy an `events.xml` file into `testdata/` dir.

```
bundle exec ruby example.rb testdata/events.xml
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bbbevents'
```

And then execute:

    $ bundle

## Usage

### Recordings
```ruby
require 'bbbevents'

# Parse the recording's events.xml.
recording = BBBEvents.parse("events.xml")

# Access recording data.
recording.metadata
recording.meeting_id

# Retrieve start, finish time objects or total duration in seconds.
recording.start
recording.finish
recording.duration

# Returns a list of Attendee objects.
recording.attendees
recording.moderators
recording.viewers

# Returns a list of Poll objects.
recording.polls
recording.published_polls
recording.unpublished_polls

# Returns a list of RecordedSegment objects.
recording.recorded_segments

# Returns a list of upload files (names only).
recording.files

# Generate a CSV file with the data.
recording.create_csv("data.csv")

```

### Attendees
```ruby
# Grab attendee info.
attendee.name
attendee.moderator?

# Fetch initial join, last leave, or total duration.
attendee.duration
attendee.joined
attendee.left

# Fetch all recorded join/leave times.
attendee.joins
attendee.leaves

# View attendee engagement.
attendee.engagement

# => {
# :chats => 11,
# :talks => 7,
# :raisehand => 2,
# :emojis => 5,
# :poll_votes => 2,
# :talk_time => 42
# }
```

### Polls
```ruby
# Determine if poll is published.
poll.published?

# Determine when the poll started.
poll.start

# Returns an Array containing possible options.
poll.options

# Returns a Hash mapping user_id's to their poll votes.
poll.votes
```

### Recorded segments
```ruby
# Determine when the recorded segment started.
recorded_segment.start

# Determine when the recorded segment stopped.
recorded_segment.stop

# Determine duration in seconds of the recorded segment.
recorded_segment.duration
```

## License

The gem is available as open source under the terms of the [LGPL 3.0 License](https://www.gnu.org/licenses/lgpl-3.0.txt).
