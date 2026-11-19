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
# autocompletar-meio.spec.mjs
seed[:meio] = loja('Loja E2E 3', 'Júlia Atendente', 'julia@e2e.test', '+5511999990002')
# atalho-por-palavra.spec.mjs: as respostas prontas da conta, como a LocFit cadastra.
seed[:atalho] = loja('Loja E2E 4', 'Bruna Atendente', 'bruna@e2e.test', '+5511999990003')
atalho = Account.find(seed[:atalho][:account_id])
CannedResponse.create!(account: atalho, short_code: 'Documentação solicitar rede social',
                       content: 'Você tem rede social, {{contact.name}}? Se puder, manda o link ou @ do seu perfil.')
CannedResponse.create!(account: atalho, short_code: 'Você prefere um plano mais flexível',
                       content: 'Você prefere um plano mais flexível, sem fidelidade?')
# lia-estado.spec.mjs: a caixa desta conta é vinculada à loja 777 na LIA (run.sh)
seed[:estado] = loja('Loja E2E 5', 'Rita Atendente', 'rita@e2e.test', '+5511999990004')
# faixa-na-hora.spec.mjs: a mensagem nova do cliente entra pela API do Chatwoot, com o
# token da atendente, enquanto ela está com a conversa aberta.
seed[:faixa] = loja('Loja E2E 6', 'Sofia Atendente', 'sofia@e2e.test', '+5511999990005')
seed[:faixa][:api_token] = User.find(seed[:faixa][:user_id]).access_token.token
# A pergunta antiga é antiga também no Chatwoot: a LIA só espera mensagem recém-chegada.
Message.where(account_id: seed[:faixa][:account_id]).update_all(created_at: 10.minutes.ago)
# autocompletar-lia.spec.mjs: a conversa pertence à loja 778 na LIA (run.sh), a única com
# o autocompletar escrito pela LIA ligado.
seed[:copiloto] = loja('Loja E2E 7', 'Helena Atendente', 'helena@e2e.test', '+5511999990006')
# lia-avisos.spec.mjs: faixa "LIA parada", fila "Esperando a equipe" e a passagem visivel.
# A caixa desta conta e vinculada a loja 888 na LIA (run.sh). Tres clientes escreveram ha
# 74, 20 e 5 minutos e ninguem respondeu; so os dois primeiros passam dos 15 minutos.
avisos = loja('Loja E2E 8', 'Lia Teixeira Atendente', 'teixeira@e2e.test', '+5511999990007')
avisos_account = Account.find(avisos[:account_id])
avisos_inbox = Inbox.find(avisos[:inbox_id])
avisos_user = User.find(avisos[:user_id])
primeira = avisos_account.conversations.find_by(display_id: avisos[:conversation_id])
primeira.update_columns(waiting_since: 74.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
avisos[:esperando] = { 'Paula Souza' => primeira.display_id }
[['Marcos Lima', '+5511999990008', 20, 'Vocês entregam em Joinville?'],
 ['Ana Costa', '+5511999990009', 5, 'Qual o valor da esteira?']].each do |nome, fone, minutos, texto|
  contato = Contact.create!(account: avisos_account, name: nome, phone_number: fone)
  ci = ContactInbox.create!(contact: contato, inbox: avisos_inbox, source_id: SecureRandom.uuid)
  conversa = Conversation.create!(account: avisos_account, inbox: avisos_inbox, contact: contato,
                                  contact_inbox: ci, status: :open, assignee: avisos_user)
  Message.create!(account: avisos_account, inbox: avisos_inbox, conversation: conversa,
                  message_type: :incoming, content: texto, sender: contato)
  conversa.update_columns(waiting_since: minutos.minutes.ago) # rubocop:disable Rails/SkipsModelValidations
  avisos[:esperando][nome] = conversa.display_id
end
# O token com que a LIA fala com o Chatwoot (a passagem visivel usa etiqueta e prioridade).
avisos[:token] = avisos_user.access_token.token
seed[:avisos] = avisos
# lia-painel.spec.mjs: Painel da LIA. Paula (da loja()) conversa com a LIA agora; Marcos foi
# transferido pela LIA e espera ha 40 min; Ana veio de campanha; Bruno pagou so com a LIA.
# lia-fila-recente.spec.mjs: Rita escreveu ha 150 dias e ninguem fechou (abandonada): fica fora
# da fila "Esperando a equipe" e aparece so na contagem das abandonadas.
painel = loja('Loja E2E 9', 'Vera Atendente', 'vera@e2e.test', '+5511999990020')
painel_account = Account.find(painel[:account_id])
painel_inbox = Inbox.find(painel[:inbox_id])
painel[:conversas] = { 'Paula Souza' => painel[:conversation_id] }
[['Marcos Lima', '+5511999990021', 40, 'Quero falar com uma pessoa'],
 ['Ana Costa', '+5511999990022', nil, 'Quanto fica com o desconto?'],
 ['Bruno Reis', '+5511999990023', nil, 'Fechado, pode mandar'],
 ['Rita Antiga', '+5511999990024', 150 * 24 * 60, 'Ainda tem a esteira?']].each do |nome, fone, minutos, texto|
  contato = Contact.create!(account: painel_account, name: nome, phone_number: fone)
  ci = ContactInbox.create!(contact: contato, inbox: painel_inbox, source_id: SecureRandom.uuid)
  conversa = Conversation.create!(account: painel_account, inbox: painel_inbox, contact: contato,
                                  contact_inbox: ci, status: :open)
  Message.create!(account: painel_account, inbox: painel_inbox, conversation: conversa,
                  message_type: :incoming, content: texto, sender: contato,
                  created_at: minutos ? minutos.minutes.ago : Time.zone.now)
  conversa.update_columns(waiting_since: minutos&.minutes&.ago) # rubocop:disable Rails/SkipsModelValidations
  painel[:conversas][nome] = conversa.display_id
end
Conversation.where(account_id: painel[:account_id], display_id: painel[:conversation_id])
            .update_all(waiting_since: nil) # rubocop:disable Rails/SkipsModelValidations
seed[:painel] = painel
Redis::Alfred.delete(Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
puts seed.to_json
