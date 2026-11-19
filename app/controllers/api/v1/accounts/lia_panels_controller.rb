# Painel da LIA (primeiro item do menu): autonomia, links, funil, por que foi para a equipe,
# quem esta com a LIA agora e a lista das conversas do periodo.
#
# Os numeros vem da LIA (Lia::StatusClient#panel), pedidos so com as caixas a que o atendente
# tem acesso; a loja escolhida no filtro so estreita essas caixas. Cada conversa que a LIA
# devolve e conferida aqui de novo (conta e caixa do atendente) antes de ganhar nome, caixa e
# responsavel: o navegador nunca recebe telefone nem conversa de caixa que nao ve.
class Api::V1::Accounts::LiaPanelsController < Api::V1::Accounts::BaseController
  PERIODS = %w[hoje 7d 30d].freeze
  WAIT_THRESHOLD = Api::V1::Accounts::LiaOverviewsController::WAIT_THRESHOLD

  def show
    inboxes = scoped_inbox_ids
    panel = inboxes.empty? ? nil : Lia::StatusClient.new.panel(account_id: Current.account.id, inbox_ids: inboxes, period: period)
    return render json: { lia_available: false, period: period } if panel.nil?

    conversations = conversations_by_display_id(panel, inboxes)
    render json: panel.slice(*%w[period summary previous links funnel stalled handoff_reasons trend]).merge(
      lia_available: true,
      live: enrich(panel['live'], conversations),
      conversations: enrich(panel['conversations'], conversations)
    )
  end

  private

  def period
    PERIODS.include?(params[:period].to_s) ? params[:period].to_s : 'hoje'
  end

  def user_inbox_ids
    @user_inbox_ids ||= Current.user.assigned_inboxes.pluck(:id)
  end

  # Loja escolhida: so as caixas dela que o atendente ve. Loja desconhecida: nenhuma caixa.
  def scoped_inbox_ids
    return user_inbox_ids if params[:store_id].blank?

    stores = Lia::StatusClient.new.account_stores(account_id: Current.account.id) || []
    store = stores.find { |item| item['store_id'] == params[:store_id].to_s }
    store ? store['inbox_ids'] & user_inbox_ids : []
  end

  def conversations_by_display_id(panel, inboxes)
    ids = (Array(panel['live']) + Array(panel['conversations'])).filter_map do |row|
      row['chatwoot_conversation_id'].to_i if row.is_a?(Hash) && row['chatwoot_conversation_id'].to_i.positive?
    end
    return {} if ids.empty?

    Current.account.conversations.where(display_id: ids.uniq, inbox_id: inboxes)
           .includes(:contact, :inbox, :assignee).index_by(&:display_id)
  end

  def enrich(rows, conversations)
    Array(rows).filter_map do |row|
      conversation = row.is_a?(Hash) ? conversations[row['chatwoot_conversation_id'].to_i] : nil
      row.except('inbox_id').merge(conversation_fields(conversation)) if conversation
    end
  end

  def conversation_fields(conversation)
    {
      'id' => conversation.display_id,
      'contact_name' => conversation.contact&.name,
      'inbox_id' => conversation.inbox_id,
      'inbox_name' => conversation.inbox&.name,
      'status' => conversation.status,
      'assignee_name' => conversation.assignee&.available_name,
      'waiting_since' => conversation.waiting_since&.iso8601,
      'waiting_team' => waiting_team?(conversation)
    }
  end

  def waiting_team?(conversation)
    conversation.open? && conversation.waiting_since.present? && conversation.waiting_since <= WAIT_THRESHOLD.ago
  end
end
