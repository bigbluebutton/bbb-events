path = File.expand_path(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH << path

require "bbbevents/base"
require 'bbbevents/version'
require 'bbbevents/attendee'
require 'bbbevents/events'
require 'bbbevents/poll'
require 'bbbevents/recording'