# Faixa "LIA parada" no topo de todas as telas e fila "Esperando a equipe".
#
# Em 16/11/2026 a LIA ficou desligada numa loja das 13h10 a meia-noite e cinco clientes
# transferidos pela LIA passaram o fim de semana sem resposta: o Chatwoot so mostrava o
# estado da LIA dentro de cada conversa, e nada juntava quem estava esperando.
#
# "Esperando" e a conversa aberta cujo cliente escreveu e ninguem (LIA ou equipe) respondeu
# ha mais de 15 minutos: e o waiting_since do proprio Chatwoot, que a resposta publica de
# qualquer um zera e a nota privada nao. Cada atendente so ve as caixas a que tem acesso.
#
# So entra quem espera ha ate 7 dias (MAX_WAIT). Em 19/11/2026 a fila tinha 208 conversas,
# quase todas abertas e sem resposta ha mais de 140 dias: ninguem fechou as abandonadas, e elas
# escondiam quem escreveu hoje. As mais antigas vem so contadas (stale), para serem fechadas.
class Api::V1::Accounts::LiaOverviewsController < Api::V1::Accounts::BaseController
  WAIT_THRESHOLD = 15.minutes
  MAX_WAIT = 7.days
  LIST_LIMIT = 50
  HANDOFF_LABEL = 'lia-transferiu'.freeze
  RESPONDING = 'respondendo'.freeze

  def show
    stores = visible_stores
    waiting = waiting_scope
    stale = stale_scope
    render json: {
      lia_available: !stores.nil?,
      threshold_minutes: WAIT_THRESHOLD.in_minutes.to_i,
      max_wait_days: MAX_WAIT.in_days.to_i,
      stale: { count: stale.count },
      stores: store_summaries(stores || [], waiting, stale),
      waiting: { count: waiting.count, conversations: waiting_rows(waiting, stores || []) }
    }
  end

  # Ligar a LIA de uma loja pela faixa. A LIA resolve a loja pela caixa; vai a primeira caixa
  # da loja que o atendente pode ver, entao ninguem liga loja de caixa que nao acessa.
  def toggle
    return render json: { message: 'A LIA não respondeu.' }, status: :service_unavailable if visible_stores.nil?

    store = requested_store
    return render json: { message: 'Loja não encontrada.' }, status: :not_found if store.nil?

    status, body = Lia::StatusClient.new.toggle(
      account_id: Current.account.id,
      inbox_id: store['inbox_ids'].first,
      action: params[:lia_action].to_s,
      by: Current.user&.available_name.presence || Current.user&.name
    )
    render json: body, status: status
  end

  private

  def requested_store
    visible_stores.find { |item| item['store_id'] == params[:store_id].to_s }
  end

  def inbox_ids
    @inbox_ids ||= Current.user.assigned_inboxes.pluck(:id)
  end

  def visible_stores
    return @visible_stores if defined?(@visible_stores)

    stores = Lia::StatusClient.new.account_stores(account_id: Current.account.id)
    @visible_stores = stores&.filter_map do |store|
      ids = store['inbox_ids'] & inbox_ids
      store.merge('inbox_ids' => ids) if ids.any?
    end
  end

  def open_in_inboxes
    Current.account.conversations.open.where(inbox_id: inbox_ids)
  end

  def unanswered
    open_in_inboxes.where('conversations.waiting_since <= ?', WAIT_THRESHOLD.ago)
  end

  # O teto de 7 dias olha a ultima fala do cliente, nao o waiting_since: o Chatwoot so o grava
  # quando esta vazio, e quem esperava ha meses e escreve de novo hoje tem de voltar a fila.
  def recent_incoming
    @wait_cutoff ||= MAX_WAIT.ago
    Message.unscope(:order).incoming
           .where('messages.conversation_id = conversations.id')
           .where('messages.created_at >= ?', @wait_cutoff)
  end

  def waiting_scope
    unanswered.where(recent_incoming.arel.exists)
  end

  # Abertas e sem resposta, mas o cliente nao escreve ha mais de 7 dias: so contadas.
  def stale_scope
    unanswered.where(recent_incoming.arel.exists.not)
  end

  # Consultas agrupadas por caixa para todas as lojas, em vez de varias por loja.
  def store_summaries(stores, waiting, stale)
    counts = waiting.group(:inbox_id).count
    oldest = waiting.group(:inbox_id).minimum(:waiting_since)
    stale_counts = stale.group(:inbox_id).count
    stores.map do |store|
      ids = store['inbox_ids']
      store.merge(
        'waiting_count' => ids.sum { |id| counts[id].to_i },
        'stale_count' => ids.sum { |id| stale_counts[id].to_i },
        'oldest_waiting_since' => oldest.values_at(*ids).compact.min&.iso8601
      )
    end
  end

  def waiting_rows(waiting, stores)
    paused = stores.reject { |store| store['state'] == RESPONDING }.flat_map { |store| store['inbox_ids'] }
    conversations = waiting.reorder(waiting_since: :asc).limit(LIST_LIMIT).includes(:contact, :inbox).to_a
    last_messages = last_incoming(conversations.map(&:id))
    conversations.map { |conversation| waiting_row(conversation, paused, last_messages[conversation.id]) }
  end

  def waiting_row(conversation, paused, last_message)
    labels = conversation.cached_label_list.to_s.split(',').map(&:strip).compact_blank
    {
      id: conversation.display_id,
      contact_name: conversation.contact&.name,
      inbox_id: conversation.inbox_id,
      inbox_name: conversation.inbox&.name,
      waiting_since: conversation.waiting_since&.iso8601,
      priority: conversation.priority,
      labels: labels,
      last_message: last_message.to_s.squish.first(140),
      reason: reason_for(conversation, labels, paused)
    }
  end

  def reason_for(conversation, labels, paused)
    return 'lia_transferiu' if labels.include?(HANDOFF_LABEL)
    return 'lia_parada' if paused.include?(conversation.inbox_id)

    'sem_resposta'
  end

  # A última fala do cliente de cada conversa da fila, numa consulta só.
  def last_incoming(conversation_ids)
    return {} if conversation_ids.empty?

    Message.incoming.where(conversation_id: conversation_ids)
           .select('DISTINCT ON (conversation_id) conversation_id, content')
           .reorder(:conversation_id, created_at: :desc)
           .to_h { |message| [message.conversation_id, message.content] }
  end
end
