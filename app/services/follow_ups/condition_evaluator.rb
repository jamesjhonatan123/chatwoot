class FollowUps::ConditionEvaluator
  pattr_initialize [:conversation!, :run!, :conditions!]

  def perform
    return true if conditions.blank?

    conditions.all? { |condition| evaluate(condition.with_indifferent_access) }
  end

  private

  def evaluate(condition)
    key = condition[:attribute_key].to_s
    operator = condition[:filter_operator].to_s
    values = Array(condition[:values])

    case key
    when 'no_incoming_since_anchor'
      compare_bool(no_incoming_since_anchor?, operator, values)
    when 'no_outgoing_since_anchor'
      compare_bool(no_outgoing_since_anchor?, operator, values)
    when 'status'
      compare_list(conversation.status, operator, values)
    when 'priority'
      compare_list(conversation.priority, operator, values)
    when 'assignee_id'
      compare_list(conversation.assignee_id, operator, values.map(&:to_i))
    when 'team_id'
      compare_list(conversation.team_id, operator, values.map(&:to_i))
    when 'labels'
      compare_labels(operator, values)
    when 'follow_up_step_index'
      compare_list(run.current_step_index, operator, values.map(&:to_i))
    else
      true
    end
  end

  def no_incoming_since_anchor?
    !conversation.messages.incoming.where('created_at > ?', run.anchor_at).exists?
  end

  def no_outgoing_since_anchor?
    !conversation.messages.outgoing.where(private: false).where('created_at > ?', run.anchor_at).exists?
  end

  def compare_bool(actual, operator, values)
    expected = ActiveModel::Type::Boolean.new.cast(values.first)
    case operator
    when 'equal_to', 'is' then actual == expected
    when 'not_equal_to', 'is_not' then actual != expected
    else actual == expected
    end
  end

  def compare_list(actual, operator, values)
    case operator
    when 'equal_to', 'is', 'contains' then values.map(&:to_s).include?(actual.to_s)
    when 'not_equal_to', 'is_not', 'does_not_contain' then values.map(&:to_s).exclude?(actual.to_s)
    else values.map(&:to_s).include?(actual.to_s)
    end
  end

  def compare_labels(operator, values)
    current = conversation.label_list.map(&:to_s)
    expected = values.map(&:to_s)
    case operator
    when 'equal_to', 'is', 'contains'
      (expected - current).empty? || expected.any? { |label| current.include?(label) }
    when 'not_equal_to', 'is_not', 'does_not_contain'
      expected.none? { |label| current.include?(label) }
    else
      expected.any? { |label| current.include?(label) }
    end
  end
end
