json.id @scheduled_message.id
json.content @scheduled_message.content
json.set! :private, @scheduled_message[:private]
json.is_private @scheduled_message[:private]
json.status @scheduled_message.status
json.scheduled_at @scheduled_message.scheduled_at.to_i
json.created_at @scheduled_message.created_at.to_i
json.template_params @scheduled_message.template_params
json.user do
  json.id @scheduled_message.user.id
  json.name @scheduled_message.user.name
  json.available_name @scheduled_message.user.available_name
  json.avatar_url @scheduled_message.user.avatar_url
end
