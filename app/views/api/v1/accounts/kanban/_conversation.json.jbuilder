json.meta do
  json.sender do
    json.partial! 'api/v1/models/contact', formats: [:json], resource: conversation.contact
  end

  if conversation.assigned_entity.is_a?(AgentBot)
    json.assignee do
      json.partial! 'api/v1/models/agent_bot_slim', formats: [:json], resource: conversation.assigned_entity
    end
    json.assignee_type 'AgentBot'
  elsif conversation.assigned_entity&.account
    json.assignee do
      json.partial! 'api/v1/models/agent', formats: [:json], resource: conversation.assigned_entity
    end
    json.assignee_type 'User'
  end

  if conversation.team.present?
    json.team do
      json.partial! 'api/v1/models/team', formats: [:json], resource: conversation.team
    end
  end

  json.hmac_verified conversation.contact_inbox&.hmac_verified
end

json.id conversation.display_id
json.messages do
  json.array! [last_message].compact do |message|
    json.partial! 'api/v1/models/message', formats: [:json], message: message
  end
end
json.additional_attributes conversation.additional_attributes
json.inbox_id conversation.inbox_id
json.labels conversation.cached_label_list_array
json.status conversation.status
json.created_at conversation.created_at.to_i
json.timestamp conversation.last_activity_at.to_i
json.unread_count unread_count
json.priority conversation.priority
json.sla_policy_id conversation.sla_policy_id

json.partial! 'enterprise/api/v1/conversations/partials/conversation', conversation: conversation if ChatwootApp.enterprise?
