# bbbevents

bbbevents is a simple ruby gem that makes it easier to parse data from a recordings events.xml file.

This gem is currently being used on the recording server to parse events and build meeting dashboards.

Currently it can parse data such as...

* Meeting metadata.
* List of attendees.
* Join and leave times.
* Attendee roles.
* Number of chat, talk and emoji status events.
* Uploaded presentation files.
* Chat log.
* Total talk time per user.
* Polls and user votes.

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
rec = BBBEvents.parse('events.xml')

# Access recording data.
puts rec.metadata
puts rec.start
puts rec.finish
puts rec.attendees
puts rec.moderators
puts rec.viewers
puts rec.chat
puts rec.files
puts rec.polls
puts rec.published_polls
puts rec.unpublished_polls

# Get a hash with all of the parsed data.
puts rec.data

# Generate a CSV file with the data.
rec.create_csv('data.csv')
```

## License

The gem is available as open source under the terms of the [LGPL 3.0 License](https://www.gnu.org/licenses/lgpl-3.0.txt).
