# Sugestao de resposta pronta escolhida pelo backend LIA, mostrada dentro do campo de resposta.
class Api::V1::Accounts::Conversations::LiaSuggestionsController < Api::V1::Accounts::Conversations::BaseController
  UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  def show
    render json: Lia::SuggestionClient.new.fetch(
      account_id: Current.account.id,
      inbox_id: @conversation.inbox_id,
      conversation_id: @conversation.display_id,
      agent: current_agent
    )
  end

  def dismiss
    suggestion_id = params[:suggestion_id].to_s
    return render json: { error: 'suggestion_id invalido' }, status: :unprocessable_entity unless UUID_FORMAT.match?(suggestion_id)

    render json: { ok: Lia::SuggestionClient.new.discard(suggestion_id, agent: current_agent) }
  end

  private

  # O x de um atendente esconde a sugestao so para ele; os outros continuam vendo.
  def current_agent
    { id: Current.user&.id, name: Current.user&.available_name.presence || Current.user&.name }
  end
end
