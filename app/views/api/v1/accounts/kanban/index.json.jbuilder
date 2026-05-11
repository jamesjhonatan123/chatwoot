json.data do
  @kanban_data.each do |column_name, conversations|
    json.set! column_name do
      json.array! conversations do |conversation|
        json.partial!(
          'api/v1/accounts/kanban/conversation',
          formats: [:json],
          conversation: conversation,
          last_message: @kanban_last_messages[conversation.id],
          unread_count: @kanban_unread_counts[conversation.id] || 0
        )
      end
    end
  end
end
