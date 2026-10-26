# Cliente server-to-server do backend LIA (sugestao de resposta pronta).
# O token nunca chega ao navegador: o painel fala com o Chatwoot e o Chatwoot com a LIA.
class Lia::SuggestionClient
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 8
  SUGGESTION_KEYS = %w[id text source].freeze
  OPTION_KEYS = %w[text source].freeze
  MAX_OPTIONS = 3
  # Lacunas "[slot]" que a LIA deixa no texto; qualquer outro nome e descartado.
  ALLOWED_SLOTS = %w[valor data hora número link e-mail].freeze
  MAX_SLOTS = 6
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
  EMPTY_ERROR = { suggestion: nil, options: [], options_id: nil, reason: 'error' }.freeze
  EMPTY_DISABLED = { suggestion: nil, options: [], options_id: nil, reason: 'disabled' }.freeze

  def self.enabled?
    ENV['LIA_API_URL'].present? && ENV['LIA_ADMIN_API_TOKEN'].present?
  end

  # Retorna sempre { suggestion:, options:, options_id:, reason: }; nunca levanta.
  # `agent` e o atendente logado ({ id:, name: }): o x dele so esconde a sugestao para ele.
  def fetch(account_id:, inbox_id:, conversation_id:, agent: nil)
    return EMPTY_DISABLED unless self.class.enabled?

    response = post('/api/chatwoot/suggestion',
                    { account_id: account_id, inbox_id: inbox_id, conversation_id: conversation_id }.merge(agent_fields(agent)))
    return log_error(response.code) unless response.code == 200

    parse(response.parsed_response)
  rescue StandardError => e
    log_error(e.class.name)
  end

  # Retorna true quando a LIA confirmou o descarte.
  def discard(suggestion_id, agent: nil)
    return false unless self.class.enabled?

    response = post("/api/chatwoot/suggestion/#{suggestion_id}/discard", agent_fields(agent))
    response.code == 200 && response.parsed_response.is_a?(Hash) && response.parsed_response['ok'] == true
  rescue StandardError => e
    log_error(e.class.name)
    false
  end

  private

  def agent_fields(agent)
    return {} if agent.blank? || agent[:id].blank?

    { agent_id: agent[:id], agent_name: agent[:name].to_s.first(120).presence }.compact
  end

  def post(path, body)
    token = ENV.fetch('LIA_ADMIN_API_TOKEN')
    HTTParty.post(
      "#{ENV.fetch('LIA_API_URL').chomp('/')}#{path}",
      headers: { 'Authorization' => "Bearer #{token}", 'X-Admin-Token' => token, 'Content-Type' => 'application/json' },
      body: body.to_json,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT
    )
  end

  def parse(payload)
    return log_error('invalid_payload') unless payload.is_a?(Hash)

    suggestion = payload['suggestion']
    suggestion = suggestion.slice(*SUGGESTION_KEYS).merge('slots' => parse_slots(suggestion['slots'])) if suggestion.is_a?(Hash)
    suggestion = nil unless suggestion.is_a?(Hash) && suggestion['text'].present?
    options_id = payload['options_id'].to_s
    {
      suggestion: suggestion,
      options: parse_options(payload['options']),
      options_id: UUID_FORMAT.match?(options_id) ? options_id : nil,
      reason: payload['reason'].to_s.presence || 'error'
    }
  end

  # Ate MAX_OPTIONS opcoes, so com as chaves text e source, ambas texto.
  def parse_options(options)
    return [] unless options.is_a?(Array)

    options.filter_map do |option|
      next unless option.is_a?(Hash) && option['text'].is_a?(String) && option['text'].present?

      { 'text' => option['text'], 'source' => option['source'].to_s, 'slots' => parse_slots(option['slots']) }
    end.first(MAX_OPTIONS)
  end

  # So nomes da lista permitida, ate MAX_SLOTS.
  def parse_slots(slots)
    return [] unless slots.is_a?(Array)

    slots.select { |slot| ALLOWED_SLOTS.include?(slot) }.first(MAX_SLOTS)
  end

  # Loga so status ou classe da excecao: nada de texto de mensagem nem token.
  def log_error(detail)
    Rails.logger.error("[LiaSuggestion] falha: #{detail}")
    EMPTY_ERROR
  end
end
