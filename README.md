# bbbevents

bbbevents is a simple ruby gem that makes it easier to parse data from a recordings events.xml file.

This gem is currently being used on the recording server to parse events and build meeting dashboards.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bbbevents'
```

And then execute:

    $ bundle

## Usage

```ruby
require 'bbbevents'

# Parse the recording's events.xml.
recording = BBBEvents.parse("events.xml")

# Access recording data.
recording.metadata
recording.meeting_id

# Retrieve start, finish dates or total duration.
recording.start
recording.finish
recording.duration

# Returns a hash that maps user_id to Attendee object.
# ex: pslzjdvacnlt => <BBBEvents::Attendee>
recording.attendees
recording.moderators
recording.viewers

# Returns an array of poll information.
recording.polls
recording.published_polls
recording.unpublished_polls

# Returns a list of upload files (names only).
recording.files

# Generate a CSV file with the data.
recording.create_csv("data.csv")

# Fetch the first attendee.
attendee = recording.values.first

# Grab attendee info.
attendee.name
attendee.moderator?

# Fetch join/leave times, or total duration.
attendee.duration
attendee.join_format
attendee.leave_format

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

## License

The gem is available as open source under the terms of the [LGPL 3.0 License](https://www.gnu.org/licenses/lgpl-3.0.txt).
