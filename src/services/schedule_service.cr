module Scribe::Services::ScheduleService
  # Check whether the current time falls within configured work hours.
  # Returns true if work hours are disabled (default behavior).
  #
  # Settings:
  #   work_hours_enabled: "true"/"false"
  #   work_hours_start:   "HH:MM" (24h format, e.g. "09:00")
  #   work_hours_end:     "HH:MM" (24h format, e.g. "18:00")
  #   work_hours_days:    "1,2,3,4,5" (ISO weekday: 1=Mon ... 7=Sun)
  #
  # Epic 13.3
  def self.within_work_hours? : Bool
    return true unless Scribe::Settings::Manager.work_hours_enabled?

    now = Time.local
    allowed_days = parse_days(Scribe::Settings::Manager.work_hours_days)
    start_minutes = parse_time_to_minutes(Scribe::Settings::Manager.work_hours_start)
    end_minutes = parse_time_to_minutes(Scribe::Settings::Manager.work_hours_end)

    # Check day of week (Crystal: Monday=1 ... Sunday=7 via .day_of_week.value)
    day_value = now.day_of_week.value
    return false unless allowed_days.includes?(day_value)

    # Check time of day
    current_minutes = now.hour * 60 + now.minute
    current_minutes >= start_minutes && current_minutes < end_minutes
  end

  # Calculate the next time that falls within work hours.
  # Useful for scheduling delayed queue processing.
  def self.next_work_window_start : Time
    now = Time.local
    allowed_days = parse_days(Scribe::Settings::Manager.work_hours_days)
    start_minutes = parse_time_to_minutes(Scribe::Settings::Manager.work_hours_start)

    start_hour = start_minutes // 60
    start_minute = start_minutes % 60

    # Try today first (if current time is before start and today is an allowed day)
    day_value = now.day_of_week.value
    current_minutes = now.hour * 60 + now.minute

    if allowed_days.includes?(day_value) && current_minutes < start_minutes
      return Time.local(now.year, now.month, now.day, start_hour, start_minute, 0)
    end

    # Try next days (up to 8 days ahead to handle all cases)
    (1..8).each do |offset|
      candidate = now + offset.days
      candidate_day = candidate.day_of_week.value
      if allowed_days.includes?(candidate_day)
        return Time.local(candidate.year, candidate.month, candidate.day, start_hour, start_minute, 0)
      end
    end

    # Fallback: 24 hours from now (should never reach here if days are configured)
    now + 24.hours
  end

  # Parse "HH:MM" to total minutes since midnight.
  private def self.parse_time_to_minutes(time_str : String) : Int32
    parts = time_str.split(":")
    return 0 if parts.size < 2
    hour = parts[0].to_i32 rescue 0
    minute = parts[1].to_i32 rescue 0
    hour * 60 + minute
  end

  # Parse "1,2,3,4,5" to array of day-of-week integers.
  private def self.parse_days(days_str : String) : Array(Int32)
    days_str.split(",").compact_map { |d| d.strip.to_i32 rescue nil }
  end
end
