module BBBEvents
  module Events
    RECORDABLE_EVENTS = [
      "participant_join_event",
      "participant_left_event",
      "conversion_completed_event",
      "public_chat_event",
      "participant_status_change_event",
      "participant_talking_event",
      "participant_muted_event",
      "poll_started_record_event",
      "user_responded_to_poll_record_event",
      "add_shape_event",
      "poll_published_record_event",
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
      end

      join_ts = Time.at(timestamp_conversion(e["timestamp"]))

      # Handle updates for re-joining users
      att = @attendees[extUserId]
      att.joins << join_ts
      att.name = e['name']
      if e['role'] == 'MODERATOR'
        att.moderator = true
      end

      join_2 = {:timestamp => join_ts, :userid => intUserId, :ext_userid => extUserId, :event => :join}

      unless att.sessions.key?(intUserId)
        att.sessions[intUserId] = { :joins => [], :lefts => []}
      end

      att.sessions[intUserId][:joins] << join_2
    end

    # Log a users leave.
    def participant_left_event(e)
      intUserId = e['userId']
      # If the attendee exists, set their leave time.
      if att = @attendees[@externalUserId[intUserId]]
        left_ts = Time.at(timestamp_conversion(e["timestamp"]))
        att.leaves << left_ts

        extUserId = 'missing'
        if @externalUserId.key?(intUserId)
          extUserId = @externalUserId[intUserId]
        end

        left_2 = {:timestamp => left_ts, :userid => intUserId, :ext_userid => extUserId, :event => :left}
        att.sessions[intUserId][:lefts] << left_2

        record_stop_talking(att, e["timestamp"])
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
        record_stop_talking(attendee, e["timestamp"])
      end
    end

    def record_stop_talking(attendee, timestamp_s)
      return if attendee.recent_talking_time == 0

      attendee.engagement[:talk_time] += timestamp_conversion(timestamp_s) - attendee.recent_talking_time
      attendee.recent_talking_time = 0
    end

    def participant_muted_event(e)
      intUserId = e["participant"]

      return unless attendee = @attendees[@externalUserId[intUserId]]

      if e["muted"] == "true"
        record_stop_talking(attendee, e["timestamp"])
      end
    end

    # Log all polls with metadata, options and votes.
    def poll_started_record_event(e)
      id = e["pollId"]

      @polls[id] = Poll.new(e)
      @polls[id].start = Time.at(timestamp_conversion(e["timestamp"]))
    end

    # Log user responses to polls.
    def user_responded_to_poll_record_event(e)
      intUserId = e['userId']
      poll_id = e['pollId']

      return unless attendee = @attendees[@externalUserId[intUserId]]

      if poll = @polls[poll_id]
        if poll.type == 'R-'
          poll.votes[@externalUserId[intUserId]] = e["answer"]
        else
          poll.votes[@externalUserId[intUserId]] = poll.options[e["answerId"].to_i]
        end
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

    def poll_published_record_event(e)
      unless e["pollId"].nil?
        if poll = @polls[e["pollId"]]
          poll.published = true
        end
      end
    end
  end
end
