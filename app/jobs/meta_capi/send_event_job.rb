# Despacha um evento para a Conversions API da Meta.
#
# Fica em job proprio para nao segurar o listener e para herdar o retry do Sidekiq: uma
# indisponibilidade do Graph nao pode custar a atribuicao de um lead. O event_id e estavel
# por origem (mensagem/conversa), entao uma reentrega e deduplicada pela propria Meta.
#
# O job recebe o phone_number_id e resolve a praca sozinho, de proposito: assim o token de
# acesso nunca e serializado na fila do Sidekiq.
class MetaCapi::SendEventJob < ApplicationJob
  # Erro de rede ou 5xx do Graph: vale tentar de novo.
  class RetryableError < StandardError; end

  queue_as :low

  retry_on RetryableError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED,
           wait: :polynomially_longer, attempts: 5

  API_VERSION = 'v21.0'.freeze

  def perform(phone_number_id:, event:)
    praca = MetaCapi::Config.for_phone_number_id(phone_number_id)
    return if praca.blank?

    event = event.deep_symbolize_keys
    response = post_event(praca, event)

    return log_success(praca, event, response) if response.success?
    raise RetryableError, "Graph #{response.code} para o dataset #{praca.dataset_id}" if response.code.to_i >= 500

    # 4xx e payload invalido ou token sem permissao: repetir nao resolve.
    log_failure(praca, event, response)
  end

  private

  def post_event(praca, event)
    HTTParty.post(
      "#{api_base_path}/#{API_VERSION}/#{praca.dataset_id}/events",
      headers: { 'Authorization' => "Bearer #{praca.access_token}", 'Content-Type' => 'application/json' },
      body: { data: [event] }.to_json
    )
  end

  def api_base_path
    ENV.fetch('META_CAPI_BASE_URL', 'https://graph.facebook.com')
  end

  # Nunca logar ctwa_clid nem o telefone hasheado: sao dados do lead.
  def log_success(praca, event, response)
    received = response.parsed_response.is_a?(Hash) ? response.parsed_response['events_received'] : nil
    Rails.logger.info("[MetaCapi] #{praca.name} #{event[:event_name]} enviado (#{event[:event_id]}) events_received=#{received}")
  end

  def log_failure(praca, event, response)
    Rails.logger.error("[MetaCapi] #{praca.name} #{event[:event_name]} recusado (#{event[:event_id]}) status=#{response.code} body=#{response.body}")
  end
end
