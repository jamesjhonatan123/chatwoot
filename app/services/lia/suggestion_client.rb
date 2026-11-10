# Cliente server-to-server do backend LIA (sugestao de resposta pronta).
# O token nunca chega ao navegador: o painel fala com o Chatwoot e o Chatwoot com a LIA.
class Lia::SuggestionClient
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 8
  # Autocompletar escrito pela LIA: roda enquanto o atendente digita; passado disso
  # o texto ja mudou e a resposta nao serve.
  COMPLETE_READ_TIMEOUT = 5
  MAX_COMPLETE_CHARS = 1200
  EMPTY_COMPLETION = { completion: nil, source: 'lia', slots: [] }.freeze
  SUGGESTION_KEYS = %w[id text source].freeze
  OPTION_KEYS = %w[text source].freeze
  MAX_OPTIONS = 3
  MAX_ALTERNATIVES = 2
  # Repertorio do autocompletar: teto de textos e de tamanho de cada um.
  MAX_COMPOSE_TEXTS = 300
  MAX_COMPOSE_CHARS = 4096
  COMPOSE_OUTCOMES = %w[accepted edited ignored].freeze
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
  # `last_incoming` e a ultima mensagem do contato ({ id:, at: }): se a LIA ainda nao a
  # recebeu, ela responde reason "waiting" e o painel pergunta de novo, em vez de
  # mostrar a sugestao da mensagem anterior.
  def fetch(account_id:, inbox_id:, conversation_id:, agent: nil, last_incoming: nil)
    return EMPTY_DISABLED unless self.class.enabled?

    response = post('/api/chatwoot/suggestion',
                    { account_id: account_id, inbox_id: inbox_id, conversation_id: conversation_id }
                      .merge(agent_fields(agent)).merge(last_incoming_fields(last_incoming)))
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

  # Repertorio do autocompletar da conversa: { texts: [{ text:, source: }], reason: }; nunca levanta.
  def compose_library(account_id:, inbox_id:, conversation_id:, agent: nil)
    return { texts: [], reason: 'disabled', generative: false } unless self.class.enabled?

    response = post('/api/chatwoot/compose-library',
                    { account_id: account_id, inbox_id: inbox_id, conversation_id: conversation_id }.merge(agent_fields(agent)))
    return compose_error(response.code) unless response.code == 200 && response.parsed_response.is_a?(Hash)

    {
      texts: parse_compose_texts(response.parsed_response['texts']),
      reason: response.parsed_response['reason'].to_s.presence || 'error',
      # A loja tem o autocompletar escrito pela LIA: o painel so chama compose_complete com isto.
      generative: response.parsed_response['generative'] == true
    }
  rescue StandardError => e
    compose_error(e.class.name)
  end

  # Continuacao do que o atendente comecou a digitar, escrita pela LIA com o texto do time.
  # Retorna sempre { completion:, source:, slots:, reason: }; nunca levanta.
  def compose_complete(account_id:, inbox_id:, conversation_id:, typed:, agent: nil)
    return EMPTY_COMPLETION.merge(reason: 'disabled') unless self.class.enabled?

    body = { account_id: account_id, inbox_id: inbox_id, conversation_id: conversation_id, typed: typed.to_s.last(MAX_COMPLETE_CHARS) }
    parse_completion(post('/api/chatwoot/compose-complete', body.merge(agent_fields(agent)), read_timeout: COMPLETE_READ_TIMEOUT))
  rescue StandardError => e
    log_error(e.class.name)
    EMPTY_COMPLETION.merge(reason: 'error')
  end

  # Autocompletar aceito e enviado; devolve o desfecho (accepted/edited/ignored) ou nil.
  def compose_used(account_id:, inbox_id:, conversation_id:, usage:, agent: nil)
    return nil unless self.class.enabled?

    body = { account_id: account_id, inbox_id: inbox_id, conversation_id: conversation_id }.merge(compose_usage(usage))
    response = post('/api/chatwoot/compose-used', body.compact.merge(agent_fields(agent)))
    return nil unless response.code == 200 && response.parsed_response.is_a?(Hash)

    outcome = response.parsed_response['outcome'].to_s
    COMPOSE_OUTCOMES.include?(outcome) ? outcome : nil
  rescue StandardError => e
    log_error(e.class.name)
    nil
  end

  # Metricas do relatorio (repassadas como vieram); em falha, um corpo vazio com erro.
  def metrics(account_id:, days:)
    return { error: 'disabled' } unless self.class.enabled?

    response = get('/api/chatwoot/suggestion-metrics', account_id: account_id, days: days)
    return { error: 'unavailable' } unless response.code == 200 && response.parsed_response.is_a?(Hash)

    response.parsed_response
  rescue StandardError => e
    log_error(e.class.name)
    { error: 'unavailable' }
  end

  # Libera um texto bloqueado pela LIA; true quando a LIA confirmou.
  def release(text_key, by: nil)
    return false unless self.class.enabled?

    response = post("/api/chatwoot/suggestion-blocklist/#{text_key}/release", { by: by.to_s.first(120).presence }.compact)
    response.code == 200 && response.parsed_response.is_a?(Hash) && response.parsed_response['ok'] == true
  rescue StandardError => e
    log_error(e.class.name)
    false
  end

  private

  def get(path, query)
    token = ENV.fetch('LIA_ADMIN_API_TOKEN')
    HTTParty.get(
      "#{ENV.fetch('LIA_API_URL').chomp('/')}#{path}",
      headers: { 'Authorization' => "Bearer #{token}", 'X-Admin-Token' => token },
      query: query,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: READ_TIMEOUT * 2
    )
  end

  # Textos cortados no limite que a LIA aceita; a origem e so um rotulo curto.
  def compose_usage(usage)
    {
      completion: usage[:completion].to_s.first(MAX_COMPOSE_CHARS),
      sent_text: usage[:sent_text].to_s.first(MAX_COMPOSE_CHARS),
      source: usage[:source].to_s.first(20).presence,
      typed_chars: usage[:typed_chars].to_i.clamp(0, MAX_COMPOSE_CHARS)
    }
  end

  def agent_fields(agent)
    return {} if agent.blank? || agent[:id].blank?

    { agent_id: agent[:id], agent_name: agent[:name].to_s.first(120).presence }.compact
  end

  # So manda quando ha mensagem do contato; `at` em segundos (com fracao) desde 1970.
  def last_incoming_fields(last_incoming)
    return {} if last_incoming.blank? || last_incoming[:id].blank? || last_incoming[:at].blank?

    { last_incoming_message_id: last_incoming[:id], last_incoming_at: last_incoming[:at].to_f }
  end

  # So a continuacao (texto) e as lacunas permitidas; sem texto, devolve o motivo da LIA.
  def parse_completion(response)
    payload = response.parsed_response
    return EMPTY_COMPLETION.merge(reason: 'error') unless response.code == 200 && payload.is_a?(Hash)

    completion = payload['completion']
    return EMPTY_COMPLETION.merge(reason: payload['reason'].to_s.presence || 'empty') unless completion.is_a?(String) && completion.present?

    { completion: completion.first(MAX_COMPLETE_CHARS), source: 'lia', slots: parse_slots(payload['slots']), reason: 'ok' }
  end

  def post(path, body, read_timeout: READ_TIMEOUT)
    token = ENV.fetch('LIA_ADMIN_API_TOKEN')
    HTTParty.post(
      "#{ENV.fetch('LIA_API_URL').chomp('/')}#{path}",
      headers: { 'Authorization' => "Bearer #{token}", 'X-Admin-Token' => token, 'Content-Type' => 'application/json' },
      body: body.to_json,
      open_timeout: OPEN_TIMEOUT,
      read_timeout: read_timeout
    )
  end

  def parse(payload)
    return log_error('invalid_payload') unless payload.is_a?(Hash)

    suggestion = payload['suggestion']
    if suggestion.is_a?(Hash)
      suggestion = suggestion.slice(*SUGGESTION_KEYS).merge(
        'slots' => parse_slots(suggestion['slots']),
        'alternatives' => parse_options(suggestion['alternatives']).first(MAX_ALTERNATIVES)
      )
    end
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

  # Ate MAX_COMPOSE_TEXTS textos nao vazios, so com text e source.
  def parse_compose_texts(texts)
    return [] unless texts.is_a?(Array)

    texts.filter_map do |item|
      next unless item.is_a?(Hash) && item['text'].is_a?(String) && item['text'].present?

      { 'text' => item['text'].first(MAX_COMPOSE_CHARS), 'source' => item['source'].to_s }
    end.first(MAX_COMPOSE_TEXTS)
  end

  def compose_error(detail)
    log_error(detail)
    { texts: [], reason: 'error', generative: false }
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
