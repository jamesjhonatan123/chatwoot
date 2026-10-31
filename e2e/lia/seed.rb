# Por teste, uma conta com atendente, inbox de API e uma conversa com a pergunta do
# cliente: um teste não conta as mensagens e os usos do outro no relatório.
# Roda dentro do container do Chatwoot (rails runner); imprime os ids em JSON.
def loja(name, agent_name, email, phone)
  account = Account.create!(name: name, locale: 'pt_BR')
  user = User.new(name: agent_name, email: email,
                  password: 'Senha-e2e-123!', password_confirmation: 'Senha-e2e-123!')
  user.skip_confirmation!
  user.save!
  AccountUser.create!(account: account, user: user, role: :administrator)
  channel = Channel::Api.create!(account: account)
  inbox = Inbox.create!(account: account, channel: channel, name: 'WhatsApp E2E')
  InboxMember.create!(inbox: inbox, user: user)
  contact = Contact.create!(account: account, name: 'Paula Souza', phone_number: phone)
  contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
  conversation = Conversation.create!(account: account, inbox: inbox, contact: contact,
                                      contact_inbox: contact_inbox, status: :open, assignee: user)
  Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                  content: 'Oi, quero alugar uma bike. Quanto custa?', sender: contact)
  { account_id: account.id, inbox_id: inbox.id, conversation_id: conversation.display_id, user_id: user.id }
end

seed = loja('Loja E2E', 'Carla Atendente', 'carla@e2e.test', '+5511999990000')
# autocompletar-apresentacao.spec.mjs
seed[:apresentacao] = loja('Loja E2E 2', 'Marina Atendente', 'marina@e2e.test', '+5511999990001')
Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
puts seed.to_json
