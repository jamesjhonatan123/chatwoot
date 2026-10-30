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

  # A LIA sabe o que cada atendente usou; quantas mensagens cada um mandou, so o Chatwoot sabe
  # (a LIA so ve as conversas que conhece). O total e a taxa do topo saem da mesma contagem
  # do ranking, para os dois numeros baterem.
  # reorder(nil): o default_scope de Message ordena por created_at, o que o GROUP BY recusa.
  def with_team_messages(payload, days)
    augmentation = payload.is_a?(Hash) && payload['augmentation']
    return payload unless augmentation.is_a?(Hash)

    counts = team_messages_by_agent(days)
    team = counts.values.sum
    helped = augmentation['suggestion_used'].to_i + augmentation['compose_used'].to_i
    augmentation['team_messages_by_agent'] = counts.transform_keys(&:to_s)
    augmentation['team_messages'] = team
    augmentation['rate'] = team.positive? ? [helped.fdiv(team), 1.0].min.round(4) : 0.0
    payload
  end

  def team_messages_by_agent(days)
    Current.account.messages.outgoing.where(private: false, sender_type: 'User')
           .where('messages.created_at >= ?', days.days.ago).reorder(nil).group(:sender_id).count
  end

  def ensure_administrator
    render json: { error: 'Apenas administradores' }, status: :forbidden unless Current.account_user&.administrator?
  end
end
