module BBBEvents
  module Events
    RECORDABLE_EVENTS = [
      "participant_join_event",
      "participant_left_event",
      "conversion_completed_event",
      "public_chat_event",
      "participant_status_change_event",
      "participant_talking_event",
      "poll_started_record_event",
      "user_responded_to_poll_record_event",
      "add_shape_event",
    ]

    EMOJI_WHITELIST = %w(away neutral confused sad happy applause thumbsUp thumbsDown)
    RAISEHAND = "raiseHand"
    POLL_PUBLISHED_STATUS = "poll_result"

    private

    # Log a users join.
    def participant_join_event(e)
      id = e["userId"]

      @attendees[id] = Attendee.new(e) unless @attendees.key?(id)
      @attendees[id].joins << timestamp_conversion(e["timestamp"])
    end

    # Log a users leave.
    def participant_left_event(e)
      return unless attendee = @attendees[e["userId"]]

      left = timestamp_conversion(e["timestamp"])
      if attendee
        attendee.leaves << left
        attendee.duration += (left - attendee.joins.last)
      end
    end

    # Log the uploaded file name.
    def conversion_completed_event(e)
      @files << e["originalFilename"]
    end

    # Log a users public chat message
    def public_chat_event(e)
      return unless attendee = @attendees[e["senderId"]]

      attendee.engagement[:chats] += 1 if attendee
    end

    # Log user status changes.
    def participant_status_change_event(e)
      return unless attendee = @attendees[e["userId"]]
      status = e["value"]

      if attendee
        if status == RAISEHAND
          attendee.engagement[:raisehand] += 1
        elsif EMOJI_WHITELIST.include?(status)
          attendee.engagement[:emojis] += 1
        end
      end
    end

    # Log number of speaking events and total talk time.
    def participant_talking_event(e)
      return unless attendee = @attendees[e["participant"]]

      if e["talking"] == "true"
        attendee.engagement[:talks] += 1
        attendee.recent_talking_time = timestamp_conversion(e["timestamp"])
      else
        attendee.engagement[:talk_time] += timestamp_conversion(e["timestamp"]) - attendee.recent_talking_time
      end
    end

    # Log all polls with metadata, options and votes.
    def poll_started_record_event(e)
      id = e["pollId"]

      @polls[id] = Poll.new(e)
      @polls[id].start = timestamp_conversion(e["timestamp"])
    end

    # Log user responses to polls.
    def user_responded_to_poll_record_event(e)
      user_id = e["userId"]
      return unless attendee = @attendees[user_id]

      if poll = @polls[e["pollId"]]
        poll.votes[user_id] = poll.options[e["answerId"].to_i]
      end

      attendee.engagement[:poll_votes] += 1
    end

    # Log if the poll was published.
    def add_shape_event(e)
      if e["type"] == POLL_PUBLISHED_STATUS
        if poll = @polls[e["id"]]
          poll.published = true
        end
      end
    end
  end
end
