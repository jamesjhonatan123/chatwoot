# Configuracao multi-praca da Conversions API da Meta, indexada por phone_number_id.
#
# Cada praca da loc.fit (Ponta Grossa, Curitiba Barigui, Uberlandia) tem a sua conta de
# anuncios, numero de WhatsApp e Pagina do Facebook, e pode ou nao compartilhar o mesmo
# dataset (pixel). O phone_number_id vem do provider_config do canal, entao a praca certa
# e resolvida a partir da propria inbox que recebeu a mensagem.
#
# Formato esperado em META_CAPI_CONFIG (JSON):
#
#   {
#     "1171321216059936": {
#       "name": "Ponta Grossa",
#       "dataset_id": "550018626702869",
#       "page_id": "1234567890",
#       "purchase_labels": ["alugou"],
#       "value_attribute": "valor_aluguel",
#       "default_value": 129.90
#     }
#   }
#
# access_token e opcional por praca; sem ele, cai no META_CAPI_ACCESS_TOKEN global.
class MetaCapi::Config
  Praca = Struct.new(:phone_number_id, :name, :dataset_id, :page_id, :access_token, :purchase_labels, :value_attribute,
                     :default_value, keyword_init: true)

  DEFAULT_PURCHASE_LABELS = %w[alugou].freeze
  DEFAULT_VALUE_ATTRIBUTE = 'valor_aluguel'.freeze

  class << self
    def for_phone_number_id(phone_number_id)
      return if phone_number_id.blank?

      key = phone_number_id.to_s
      entry = registry[key]
      return if entry.blank?

      build_praca(key, entry)
    end

    def configured?
      registry.present?
    end

    # Usado nos specs e apos mudanca de env em console.
    def reload!
      @registry = nil
    end

    private

    def registry
      @registry ||= parse_registry
    end

    def parse_registry
      raw = ENV.fetch('META_CAPI_CONFIG', nil)
      return {} if raw.blank?

      parsed = JSON.parse(raw)
      return {} unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError => e
      Rails.logger.error("[MetaCapi] META_CAPI_CONFIG invalido, ignorando: #{e.message}")
      {}
    end

    # Uma praca sem dataset ou sem token nao tem como despachar evento: trata como nao configurada.
    def build_praca(phone_number_id, entry)
      token = entry['access_token'].presence || ENV.fetch('META_CAPI_ACCESS_TOKEN', nil)
      return if entry['dataset_id'].blank? || token.blank?

      Praca.new(
        phone_number_id: phone_number_id,
        name: entry['name'].presence || entry['dataset_id'],
        dataset_id: entry['dataset_id'],
        page_id: entry['page_id'],
        access_token: token,
        purchase_labels: purchase_labels(entry),
        value_attribute: entry['value_attribute'].presence || DEFAULT_VALUE_ATTRIBUTE,
        default_value: entry['default_value']
      )
    end

    def purchase_labels(entry)
      Array(entry['purchase_labels'].presence || DEFAULT_PURCHASE_LABELS).map { |label| label.to_s.downcase }
    end
  end
end
