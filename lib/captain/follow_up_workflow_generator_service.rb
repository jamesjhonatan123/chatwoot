class Captain::FollowUpWorkflowGeneratorService < Captain::BaseTaskService
  ALLOWED_ACTIONS = %w[
    send_message
    add_private_note
    notify_assignee
    add_label
    resolve_conversation
    open_conversation
    change_priority
  ].freeze
  ALLOWED_UNITS = %w[minutes hours days weeks].freeze
  ALLOWED_TRIGGER_MODES = %w[manual automation both].freeze
  ALLOWED_ON_FAIL = %w[abort skip].freeze
  ALLOWED_PRIORITIES = %w[low medium high urgent].freeze
  MEDIA_FORMATS = %w[IMAGE VIDEO DOCUMENT].freeze
  TEMPLATE_LIMIT = 40

  pattr_initialize [:account!, :prompt!, { language: 'en' }]

  def perform
    return { error: 'Prompt is required', error_code: 400 } if prompt.blank?

    api_response = make_api_call(
      model: GPT_MODEL,
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: prompt.to_s.strip }
      ]
    )

    return api_response if api_response[:error]

    workflow = sanitize_workflow(parse_json_response(api_response[:message]))
    return { error: 'Invalid LLM response format' } if workflow.blank?

    { workflow: workflow, message: api_response[:message] }
  end

  private

  def system_prompt
    Liquid::Template.parse(prompt_from_file('follow_up_workflow')).render(
      'language' => language.to_s.presence || 'en',
      'labels' => account.labels.limit(50).pluck(:title).join(', ').presence || 'none',
      'whatsapp_templates' => whatsapp_templates_prompt_text
    )
  end

  def whatsapp_templates_prompt_text
    entries = available_templates.first(TEMPLATE_LIMIT).map do |template|
      [
        "inbox_id=#{template[:inbox_id]}",
        "inbox=#{template[:inbox_name]}",
        "name=#{template[:name]}",
        "language=#{template[:language]}",
        "category=#{template[:category]}",
        "variables=#{template[:variables].join('|').presence || 'none'}",
        "body=#{template[:body]}"
      ].join('; ')
    end

    entries.presence&.join("\n") || 'none'
  end

  def available_templates
    @available_templates ||= begin
      templates = []

      whatsapp_inboxes.each do |inbox|
        Array(inbox_templates(inbox)).each do |raw|
          next unless template_eligible?(raw)
          next if media_header?(raw)

          body = body_text(raw)
          next if body.blank?

          templates << {
            inbox_id: inbox.id,
            inbox_name: inbox.name,
            name: raw['name'],
            language: raw['language'],
            category: raw['category'],
            namespace: raw['namespace'],
            body: body.truncate(180),
            variables: body_variables(body),
            raw: raw
          }
        end
      end

      prefer_language = language.to_s.downcase
      templates.sort_by do |template|
        [
          template[:language].to_s.downcase.start_with?(prefer_language.split(/[_-]/).first) ? 0 : 1,
          template[:name].to_s
        ]
      end
    end
  end

  def whatsapp_inboxes
    account.inboxes.includes(:channel).select do |inbox|
      inbox.channel_type == 'Channel::Whatsapp' ||
        (inbox.channel_type == 'Channel::TwilioSms' && inbox.channel.try(:medium) == 'whatsapp')
    end
  end

  def inbox_templates(inbox)
    channel = inbox.channel
    channel.try(:message_templates).presence ||
      channel.try(:additional_attributes)&.dig('message_templates').presence ||
      inbox.try(:additional_attributes)&.dig('message_templates')
  end

  def template_eligible?(template)
    return false if template.blank? || template['name'].blank? || template['components'].blank?
    return false unless template['status'].to_s.downcase == 'approved'
    return false if template['category'].to_s.upcase == 'AUTHENTICATION'
    return false if template['name'].to_s.start_with?('customer_satisfaction_survey')

    unsupported = Array(template['components']).any? do |component|
      %w[LIST PRODUCT CATALOG CALL_PERMISSION_REQUEST].include?(component['type'].to_s) ||
        (component['type'] == 'HEADER' && component['format'] == 'LOCATION')
    end
    !unsupported
  end

  def media_header?(template)
    header = Array(template['components']).find { |component| component['type'] == 'HEADER' }
    MEDIA_FORMATS.include?(header&.dig('format').to_s.upcase)
  end

  def body_text(template)
    Array(template['components']).find { |component| component['type'] == 'BODY' }&.dig('text').to_s
  end

  def body_variables(body)
    body.to_s.scan(/\{\{([^}]+)\}\}/).flatten.map { |key| key.to_s.strip }
  end

  def parse_json_response(content)
    raw = content.to_s.strip
    json = raw.match(/```json\s*(.*?)\s*```/m)&.captures&.first || raw
    JSON.parse(json)
  rescue JSON::ParserError
    nil
  end

  def sanitize_workflow(parsed)
    return nil unless parsed.is_a?(Hash)

    steps = Array(parsed['steps']).first(8).filter_map { |step| sanitize_step(step) }
    return nil if steps.blank?

    {
      'name' => parsed['name'].to_s.truncate(120).presence || 'AI follow-up',
      'description' => parsed['description'].to_s.truncate(500),
      'trigger_mode' => normalize_trigger_mode(parsed['trigger_mode']),
      'steps' => steps
    }
  end

  def sanitize_step(step)
    return nil unless step.is_a?(Hash)

    actions = Array(step['actions']).first(5).filter_map { |action| sanitize_action(action) }
    return nil if actions.blank?

    wait = step['wait'].is_a?(Hash) ? step['wait'] : {}
    {
      'type' => 'wait_then_act',
      'wait' => {
        'value' => [[wait['value'].to_i, 1].max, 365].min,
        'unit' => ALLOWED_UNITS.include?(wait['unit'].to_s) ? wait['unit'].to_s : 'hours',
        'business_hours' => ActiveModel::Type::Boolean.new.cast(wait['business_hours']) || false
      },
      'conditions' => [
        {
          'attribute_key' => 'no_incoming_since_anchor',
          'filter_operator' => 'equal_to',
          'values' => [true]
        }
      ],
      'on_fail' => ALLOWED_ON_FAIL.include?(step['on_fail'].to_s) ? step['on_fail'].to_s : 'abort',
      'actions' => actions,
      'branch' => nil
    }
  end

  def sanitize_action(action)
    return nil unless action.is_a?(Hash)

    name = action['action_name'].to_s
    return nil unless ALLOWED_ACTIONS.include?(name)

    params = Array(action['action_params'])
    case name
    when 'send_message'
      sanitize_send_message(params.first)
    when 'add_private_note'
      content = params.first.to_s.strip
      return nil if content.blank?

      { 'action_name' => name, 'action_params' => [content.truncate(2000)] }
    when 'add_label'
      labels = params.map(&:to_s).map(&:strip).reject(&:blank?).first(5)
      return nil if labels.blank?

      { 'action_name' => name, 'action_params' => labels }
    when 'change_priority'
      priority = params.first.to_s
      return nil unless ALLOWED_PRIORITIES.include?(priority)

      { 'action_name' => name, 'action_params' => [priority] }
    else
      { 'action_name' => name, 'action_params' => [] }
    end
  end

  def sanitize_send_message(payload)
    if payload.is_a?(Hash)
      return sanitize_template_message(payload)
    end

    content = payload.to_s.strip
    return nil if content.blank?

    { 'action_name' => 'send_message', 'action_params' => [content.truncate(2000)] }
  end

  def sanitize_template_message(payload)
    payload = payload.with_indifferent_access
    template = find_available_template(
      payload[:inbox_id],
      payload[:name].presence || payload[:template_name],
      payload[:language]
    )
    return nil if template.blank?

    processed_params = normalize_processed_params(template, payload[:processed_params])
    return nil if missing_required_variables?(template, processed_params)

    {
      'action_name' => 'send_message',
      'action_params' => [{
        'message' => render_template_body(template[:raw], processed_params),
        'inbox_id' => template[:inbox_id],
        'template_params' => {
          'name' => template[:name],
          'category' => template[:category],
          'language' => template[:language],
          'namespace' => template[:namespace],
          'processed_params' => processed_params
        }
      }]
    }
  end

  def find_available_template(inbox_id, name, language)
    candidates = available_templates.select do |template|
      template[:name].to_s == name.to_s &&
        (inbox_id.blank? || template[:inbox_id].to_s == inbox_id.to_s)
    end
    return nil if candidates.blank?

    if language.present?
      matched = candidates.find { |template| template[:language].to_s.casecmp(language.to_s).zero? }
      return matched if matched
    end

    candidates.first
  end

  def normalize_processed_params(template, processed_params)
    raw = processed_params.is_a?(Hash) ? processed_params.with_indifferent_access : {}
    body = {}

    template[:variables].each do |variable|
      value = raw.dig(:body, variable).presence || raw[variable].presence
      body[variable] = value.to_s.strip.truncate(200) if value.present?
    end

    { 'body' => body }
  end

  def missing_required_variables?(template, processed_params)
    template[:variables].any? { |variable| processed_params.dig('body', variable).blank? }
  end

  def render_template_body(template, processed_params)
    body_text(template).gsub(/\{\{([^}]+)\}\}/) do
      key = Regexp.last_match(1).to_s.strip
      processed_params.dig('body', key).presence || "{{#{key}}}"
    end
  end

  def normalize_trigger_mode(value)
    ALLOWED_TRIGGER_MODES.include?(value.to_s) ? value.to_s : 'manual'
  end

  def event_name
    'follow_up_workflow_generator'
  end

  def build_follow_up_context?
    false
  end
end
