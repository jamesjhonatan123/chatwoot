account = Account.find_or_create_by!(name: 'Locfit E2E')
user = User.find_by(email: 'e2e@example.com') || User.new(email: 'e2e@example.com')
user.assign_attributes(name: 'Atendente E2E', password: 'E2e-Pass!2026', password_confirmation: 'E2e-Pass!2026', confirmed_at: Time.current)
user.skip_confirmation! rescue nil
user.save!
AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = :administrator }
channel = Channel::Api.find_or_create_by!(account: account) { |c| c.webhook_url = nil }
inbox = Inbox.find_or_create_by!(account: account, channel: channel) { |i| i.name = 'API E2E' }
InboxMember.find_or_create_by!(inbox: inbox, user: user)
contact = Contact.find_or_create_by!(account: account, name: 'Ana Souza')
ci = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) { |c| c.source_id = 'e2e-ana' }
conv = Conversation.where(account: account, inbox: inbox, contact: contact).first || Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: ci, status: :open)
if conv.messages.none?
  conv.messages.create!(account: account, inbox: inbox, message_type: :outgoing, content: 'Oi Ana! Sou a assistente da Locfit. Como posso ajudar?', sender: nil)
  sleep 1
  conv.messages.create!(account: account, inbox: inbox, message_type: :incoming, content: 'Qual o prazo de entrega da bike depois que eu assino?', sender: contact)
end
{ '/prazo' => 'Oi {{contact.first_name}}! A entrega sai em até dois dias úteis depois da assinatura confirmada.',
  '/horario' => 'Nosso horário de atendimento é de segunda a sexta, das 9h às 18h.',
  '/pagamento' => 'Aceitamos cartão de crédito recorrente e PIX para a primeira cobrança.',
  '/troca' => 'Para trocar o equipamento, avise por aqui que agendamos a retirada e a nova entrega.' }.each do |sc, c|
  CannedResponse.find_or_create_by!(account: account, short_code: sc.delete_prefix('/')) { |r| r.content = c }
end
puts({ account_id: account.id, inbox_id: inbox.id, conversation_id: conv.display_id, conversation_pk: conv.id, user_id: user.id, token: user.access_token.token }.to_json)
