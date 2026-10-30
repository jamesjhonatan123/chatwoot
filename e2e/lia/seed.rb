# Conta, atendente, inbox de API e uma conversa com a pergunta do cliente.
# Roda dentro do container do Chatwoot (rails runner); imprime os ids em JSON.
account = Account.create!(name: 'Loja E2E', locale: 'pt_BR')
user = User.new(name: 'Carla Atendente', email: 'carla@e2e.test',
                password: 'Senha-e2e-123!', password_confirmation: 'Senha-e2e-123!')
user.skip_confirmation!
user.save!
AccountUser.create!(account: account, user: user, role: :administrator)
channel = Channel::Api.create!(account: account)
inbox = Inbox.create!(account: account, channel: channel, name: 'WhatsApp E2E')
InboxMember.create!(inbox: inbox, user: user)
contact = Contact.create!(account: account, name: 'Paula Souza', phone_number: '+5511999990000')
contact_inbox = ContactInbox.create!(contact: contact, inbox: inbox, source_id: SecureRandom.uuid)
conversation = Conversation.create!(account: account, inbox: inbox, contact: contact,
                                    contact_inbox: contact_inbox, status: :open, assignee: user)
Message.create!(account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                content: 'Oi, quero alugar uma bike. Quanto custa?', sender: contact)
Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
puts({ account_id: account.id, inbox_id: inbox.id, conversation_id: conversation.display_id, user_id: user.id }.to_json)
