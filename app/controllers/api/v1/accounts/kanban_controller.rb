class Api::V1::Accounts::KanbanController < Api::V1::Accounts::BaseController
  def index
    @kanban_data = {}

    base_query = current_account.conversations.includes(
      :assignee_agent_bot, { assignee: { avatar_attachment: [:blob] } },
      { contact: { avatar_attachment: [:blob] } }, :team, :contact_inbox
    )

    accessible_conversations = Conversations::PermissionFilterService.new(
      base_query, current_user, current_account
    ).perform

    accessible_conversations = accessible_conversations
                              .where(status: [:open, :pending])
                              .order(last_activity_at: :desc)

    if params[:group_by] == 'team'
      selected_team_ids = Array(params[:team_ids]).map(&:to_i)
      selected_team_ids = current_account.teams.order(:name).pluck(:id) if selected_team_ids.empty?

      teams = current_account.teams.where(id: selected_team_ids.reject(&:zero?)).order(:name)
      teams.each do |team|
        conversations = accessible_conversations.where(team_id: team.id)
        conversations = conversations.page(params[:page] || 1).per(20)
        @kanban_data[team.name] = conversations
      end

      if selected_team_ids.include?(0)
        unassigned = accessible_conversations.where(team_id: nil)
        unassigned = unassigned.page(params[:page] || 1).per(20)
        @kanban_data['Unassigned'] = unassigned
      end
    else
      labels = Array(params[:labels]).presence || current_account.labels.order(:title).pluck(:title)
      labels.each do |label|
        conversations = accessible_conversations.tagged_with(label)
        conversations = conversations.page(params[:page] || 1).per(20)

        @kanban_data[label] = conversations
      end
    end

    preload_kanban_metadata
  end

  private

  def preload_kanban_metadata
    conversation_ids = @kanban_data.values.flatten.map(&:id).uniq
    @kanban_last_messages = {}
    @kanban_unread_counts = {}
    return if conversation_ids.empty?

    @kanban_last_messages = Message.unscoped
                                  .where(account_id: current_account.id, conversation_id: conversation_ids)
                                  .chat
                                  .includes(:conversation, :sender, attachments: [{ file_attachment: [:blob] }])
                                  .select('DISTINCT ON (conversation_id) messages.*')
                                  .reorder('conversation_id, created_at DESC')
                                  .index_by(&:conversation_id)

    @kanban_unread_counts = Message.unscoped
                                   .where(account_id: current_account.id, conversation_id: conversation_ids)
                                   .incoming
                                   .joins(:conversation)
                                   .where('conversations.agent_last_seen_at IS NULL OR messages.created_at > conversations.agent_last_seen_at')
                                   .group(:conversation_id)
                                   .count
  end
end
