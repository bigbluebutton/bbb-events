#!/usr/bin/ruby

require './lib/bbbevents'
require 'trollop'

path = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH << path

opts = Trollop::options do
  opt :events, "events.xml file", :type => String, :default => "events.xml"
end

eventsxml = opts[:events]

# Parse the recording's events.xml.
recording = BBBEvents.parse(eventsxml)

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

# Returns a list of upload files (names only).
recording.files

# Generate a CSV file with the data.
recording.create_csv("data.csv")

# Write JSON data to file.
File.open("data.json", 'w') do |f|
  f.write(recording.to_json)
end


