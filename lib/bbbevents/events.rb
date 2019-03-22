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
      intUserId = e['userId']
      extUserId = e['externalUserId']

      # If they don't exist, initialize the user.
      unless @externalUserId.key?(intUserId)
        @externalUserId[intUserId] = extUserId
      end

      # We need to track the user using external userids so that 3rd party
      # integrations will be able to correlate the users with their own data.
      unless @attendees.key?(extUserId)
        @attendees[extUserId] = Attendee.new(e) unless @attendees.key?(extUserId)
        @attendees[extUserId].joins << Time.at(timestamp_conversion(e["timestamp"]))
      end

      # Handle updates for re-joining users
      att = @attendees[extUserId]
      att.name = e['name']
      if e['role'] == 'MODERATOR'
        att.moderator = true
      end
    end

    # Log a users leave.
    def participant_left_event(e)
      intUserId = e['userId']
      # If the attendee exists, set their leave time.
      if att = @attendees[@externalUserId[intUserId]]
        left = Time.at(timestamp_conversion(e["timestamp"]))
        att.leaves << left
      end
    end

    # Log the uploaded file name.
    def conversion_completed_event(e)
      @files << e["originalFilename"]
    end

    # Log a users public chat message
    def public_chat_event(e)
      intUserId = e['senderId']
      # If the attendee exists, increment their messages.
      if att = @attendees[@externalUserId[intUserId]]
        att.engagement[:chats] += 1
      end
    end

    # Log user status changes.
    def participant_status_change_event(e)
      intUserId = e['userId']

      return unless attendee = @attendees[@externalUserId[intUserId]]
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
      intUserId = e["participant"]

      return unless attendee = @attendees[@externalUserId[intUserId]]

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
      intUserId = e['userId']
      poll_id = e['pollId']

      return unless attendee = @attendees[@externalUserId[intUserId]]

      if poll = @polls[poll_id]
        poll.votes[@externalUserId[intUserId]] = poll.options[e["answerId"].to_i]
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
