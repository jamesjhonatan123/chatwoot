class Api::V1::Accounts::KanbanController < Api::V1::Accounts::BaseController
  def index
    labels = current_account.labels.order(:title).pluck(:title)
    @kanban_data = {}

    base_query = current_account.conversations.includes(
      :taggings, :inbox, { assignee: { avatar_attachment: [:blob] } },
      { contact: { avatar_attachment: [:blob] } }, :team, :contact_inbox
    )

    accessible_conversations = Conversations::PermissionFilterService.new(
      base_query, current_user, current_account
    ).perform

    if params[:group_by] == 'team'
      teams = current_account.teams.order(:name)
      teams.each do |team|
        conversations = accessible_conversations.where(team_id: team.id)
        conversations = conversations.page(params[:page] || 1).per(20)
        @kanban_data[team.name] = conversations
      end

      unassigned = accessible_conversations.where(team_id: nil)
      unassigned = unassigned.page(params[:page] || 1).per(20)
      @kanban_data['Unassigned'] = unassigned
    else
      labels = current_account.labels.order(:title).pluck(:title)
      labels.each do |label|
        conversations = accessible_conversations.tagged_with(label)
        conversations = conversations.page(params[:page] || 1).per(20)

        @kanban_data[label] = conversations
      end
    end
  end
end
