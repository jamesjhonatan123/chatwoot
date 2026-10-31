# Selo da LIA no cabecalho da conversa: ela esta respondendo na loja desta caixa?
# Qualquer atendente com acesso a conversa ve e liga/desliga (vale para a loja
# inteira); desligar sempre tem prazo e o nome de quem clicou fica registrado.
class Api::V1::Accounts::Conversations::LiaStatusesController < Api::V1::Accounts::Conversations::BaseController
  def show
    render json: Lia::StatusClient.new.fetch(account_id: Current.account.id, inbox_id: @conversation.inbox_id)
  end

  def toggle
    status, body = Lia::StatusClient.new.toggle(
      account_id: Current.account.id,
      inbox_id: @conversation.inbox_id,
      action: params[:lia_action].to_s,
      by: Current.user&.available_name.presence || Current.user&.name
    )
    render json: body, status: status
  end
end
