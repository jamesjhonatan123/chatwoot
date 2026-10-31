# Estado da LIA na loja da caixa de entrada, e o atalho para ligar/desligar.
# Server-to-server: o token da LIA nunca chega ao navegador. A loja sai da caixa
# no lado da LIA; caixa sem loja nunca muda nada (nem o padrao global).
class Lia::StatusClient
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 8
  STATES = %w[respondendo silencio desligada].freeze
  ACTIONS = %w[ligar desligar].freeze
  KEYS = %w[store_id state reason label until by action].freeze
  UNAVAILABLE = { 'state' => nil, 'label' => 'Estado da LIA indisponível', 'error' => 'unavailable' }.freeze

  def self.enabled?
    ENV['LIA_API_URL'].present? && ENV['LIA_ADMIN_API_TOKEN'].present?
  end

  # Sempre devolve um Hash; nunca levanta.
  def fetch(account_id:, inbox_id:)
    return UNAVAILABLE.merge('error' => 'disabled') unless self.class.enabled?

    response = request(:get, '/api/lia-status/chatwoot', query: { account_id: account_id, inbox_id: inbox_id })
    return UNAVAILABLE unless response.code == 200

    clean(response.parsed_response)
  rescue StandardError => e
    Rails.logger.warn("[LIA status] #{e.class.name}")
    UNAVAILABLE
  end

  # Devolve [status_http, corpo]. 409 = nada a fazer (o corpo traz o estado atual).
  def toggle(account_id:, inbox_id:, action:, by:)
    return [422, { 'error' => 'acao invalida' }] unless ACTIONS.include?(action)
    return [503, UNAVAILABLE.merge('error' => 'disabled')] unless self.class.enabled?

    response = request(:post, '/api/lia-status/chatwoot',
                       body: { account_id: account_id, inbox_id: inbox_id, action: action, by: by.to_s.first(80).presence }.compact)
    payload = response.parsed_response
    case response.code
    when 200 then [200, clean(payload)]
    when 404, 409
      detail = payload.is_a?(Hash) ? payload['detail'] : nil
      body = detail.is_a?(Hash) && detail['status'].is_a?(Hash) ? clean(detail['status']) : {}
      [response.code, body.merge('message' => detail.is_a?(Hash) ? detail['message'].to_s : '')]
    else [502, UNAVAILABLE]
    end
  rescue StandardError => e
    Rails.logger.warn("[LIA status] #{e.class.name}")
    [502, UNAVAILABLE]
  end

  private

  def clean(payload)
    return UNAVAILABLE unless payload.is_a?(Hash)

    data = payload.slice(*KEYS)
    data['state'] = nil unless STATES.include?(data['state'])
    data['action'] = nil unless ACTIONS.include?(data['action'])
    data['label'] = data['label'].to_s.first(200)
    data
  end

  def request(verb, path, query: nil, body: nil)
    token = ENV.fetch('LIA_ADMIN_API_TOKEN')
    headers = { 'Authorization' => "Bearer #{token}", 'X-Admin-Token' => token, 'Content-Type' => 'application/json' }
    url = "#{ENV.fetch('LIA_API_URL').chomp('/')}#{path}"
    options = { headers: headers, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT }
    options[:query] = query if query
    options[:body] = body.to_json if body
    HTTParty.public_send(verb, url, options)
  end
end
