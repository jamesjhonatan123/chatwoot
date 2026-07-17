class FollowUps::WaitCalculator
  pattr_initialize [:conversation!, :wait_config!, :from!]

  def perform
    value = wait_config['value'].to_i
    unit = wait_config['unit'].to_s
    use_business_hours = ActiveModel::Type::Boolean.new.cast(wait_config['business_hours'])

    return from + absolute_offset(value, unit) unless use_business_hours

    advance_business_hours(value, unit)
  end

  private

  def absolute_offset(value, unit)
    case unit
    when 'minutes' then value.minutes
    when 'hours' then value.hours
    when 'days' then value.days
    when 'weeks' then value.weeks
    else value.hours
    end
  end

  def advance_business_hours(value, unit)
    hours_needed = case unit
                   when 'minutes' then (value / 60.0)
                   when 'hours' then value
                   when 'days' then value * business_hours_per_day
                   when 'weeks' then value * business_hours_per_day * 5
                   else value
                   end

    cursor = from
    remaining = hours_needed.to_f
    max_iterations = (hours_needed * 24).to_i + 500
    iterations = 0

    while remaining.positive? && iterations < max_iterations
      cursor += 1.hour
      remaining -= 1 if within_business_hours?(cursor)
      iterations += 1
    end

    cursor
  end

  def within_business_hours?(time)
    working_hours = conversation.inbox.working_hours
    return time.on_weekday? if working_hours.blank?

    local = time.in_time_zone(conversation.inbox.timezone)
    hour_record = working_hours.find { |wh| wh.day_of_week == local.wday }
    return false if hour_record.blank? || hour_record.closed_all_day?
    return true if hour_record.open_all_day?

    open_time = local.change(hour: hour_record.open_hour, min: hour_record.open_minutes)
    close_time = local.change(hour: hour_record.close_hour, min: hour_record.close_minutes)
    local >= open_time && local <= close_time
  end

  def business_hours_per_day
    8
  end
end
