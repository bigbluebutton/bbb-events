# bbbevents

bbbevents is a simple ruby gem that makes it easier to parse data from a recordings events.xml file.

Currently it can parse data such as...

* Meeting metadata.
* List of attendees.
* Join and leave times.
* Attendee roles.
* Number of chat, talk and emoji status events. 
* Uploaded presentation files.
* Chat log.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bbbevents', :git => 'https://github.com/blindsidenetworks/bbb-events'
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
puts rec.attendees
puts rec.moderators
puts rec.viewers
puts rec.chat
puts rec.files
puts rec.polls
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
