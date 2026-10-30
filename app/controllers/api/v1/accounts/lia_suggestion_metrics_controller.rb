# Relatório da sugestão pronta da LIA: aproveitamento, negadas e textos bloqueados.
# So administradores veem e liberam; o token da LIA nunca chega ao navegador.
class Api::V1::Accounts::LiaSuggestionMetricsController < Api::V1::Accounts::BaseController
  TEXT_KEY_FORMAT = /\A\h{40}\z/
  MAX_DAYS = 90

  before_action :ensure_administrator

  def show
    days = params[:days].to_i.clamp(1, MAX_DAYS)
    render json: with_team_messages(Lia::SuggestionClient.new.metrics(account_id: Current.account.id, days: days), days)
  end

  def release
    text_key = params[:text_key].to_s
    return render json: { error: 'text_key invalido' }, status: :unprocessable_entity unless TEXT_KEY_FORMAT.match?(text_key)

    render json: { ok: Lia::SuggestionClient.new.release(text_key, by: Current.user&.available_name) }
  end

  private

  # A LIA sabe o que cada atendente usou; quantas mensagens cada um mandou, so o Chatwoot sabe.
  def with_team_messages(payload, days)
    return payload unless payload.is_a?(Hash) && payload['augmentation'].is_a?(Hash)

    counts = Current.account.messages.outgoing.where(private: false, sender_type: 'User')
                    .where('messages.created_at >= ?', days.days.ago).group(:sender_id).count
    payload['augmentation']['team_messages_by_agent'] = counts.transform_keys(&:to_s)
    payload
  end

  def ensure_administrator
    render json: { error: 'Apenas administradores' }, status: :forbidden unless Current.account_user&.administrator?
  end
end
