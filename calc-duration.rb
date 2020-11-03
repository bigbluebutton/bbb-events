
require 'time'

#joins = ["2020-10-26 08:04:51 +0000", "2020-10-26 08:05:37 +0000", "2020-10-26 08:06:26 +0000", "2020-10-26 08:06:28 +0000", "2020-10-26 08:07:20 +0000", "2020-10-26 08:08:03 +0000", "2020-10-26 08:17:43 +0000", "2020-10-26 08:53:50 +0000"]
#leaves = ["2020-10-26 08:07:55 +0000", "2020-10-26 08:56:31 +0000"]

#joins = ["2020-10-26 08:49:25 +0000", "2020-10-26 08:49:53 +0000", "2020-10-26 08:56:12 +0000"]
#leaves = ["2020-10-26 08:49:55 +0000", "2020-10-26 08:53:15 +0000", "2020-10-26 08:56:31 +0000"]

joins = ["2020-10-26 08:16:52 +0000", "2020-10-26 08:27:43 +0000", "2020-10-26 08:28:25 +0000"]
leaves = ["2020-10-26 08:26:55 +0000", "2020-10-26 08:28:25 +0000", "2020-10-26 08:53:25 +0000"]

#joins = ["2020-10-26 08:06:18 +0000", "2020-10-26 08:09:08 +0000", "2020-10-26 08:10:47 +0000", "2020-10-26 08:12:24 +0000", "2020-10-26 08:13:10 +0000"]
#leaves = ["2020-10-26 08:10:35 +0000", "2020-10-26 08:12:05 +0000", "2020-10-26 08:13:05 +0000", "2020-10-26 08:53:35 +0000", "2020-10-26 08:56:31 +0000"]

comb = joins + leaves
comb2 = comb.sort

puts comb2

joins_arr = []
joins.each { |j| joins_arr.append({:time => Time.parse(j).to_i, :datetime => j, :event => :join})}
leaves.each { |j| joins_arr.append({:time => Time.parse(j).to_i, :datetime => j, :event => :left})}

j_sorted = joins_arr.sort_by { |event| event[:time] }

puts j_sorted

jsorted_matched = []
total_duration = 0

prev_event = nil
j_sorted.each do |cur_event|
  duration = 0
  if prev_event != nil and cur_event[:event] == :join and prev_event[:event] == :left
    prev_event = cur_event
  elsif prev_event != nil
    duration = cur_event[:time] - prev_event[:time]
    total_duration += duration
    prev_event = cur_event
  else
    prev_event = cur_event
  end

  puts "#{cur_event[:datetime]} cur_duration=#{Time.at(duration).utc.strftime("%H:%M:%S")} duration=#{Time.at(total_duration).utc.strftime("%H:%M:%S")} join=#{cur_event[:event]} "
end

puts total_duration
puts Time.at(total_duration).utc.strftime("%H:%M:%S")
