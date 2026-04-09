account = Account.find_by!(name: 'Acme Inc')
inbox = Inbox.find_by!(name: 'Acme Support', account_id: account.id)

user = User.find_or_initialize_by(email: 'filters@acme.inc')
user.name = 'Filter Tester'
user.password = 'Password1!' if user.new_record?
user.password_confirmation = 'Password1!' if user.new_record?
user.type = 'SuperAdmin'
user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
user.save!

AccountUser.find_or_create_by!(account: account, user: user) do |account_user|
  account_user.role = :administrator
end

InboxMember.find_or_create_by!(user: user, inbox: inbox)

%w[vip billing bug sales].each do |label_name|
  ActsAsTaggableOn::Tag.find_or_create_by!(name: label_name)
end

conversation_specs = [
  {
    key: 'filter-unread-open-high',
    contact_name: 'Unread Open High',
    email: 'unread-open-high@example.com',
    phone: '+5511999990001',
    status: :open,
    priority: :high,
    assignee: user,
    labels: %w[vip bug],
    browser_language: 'en',
    unread: true,
    last_incoming_body: 'Customer sent an unread message for filter testing'
  },
  {
    key: 'filter-read-open-low',
    contact_name: 'Read Open Low',
    email: 'read-open-low@example.com',
    phone: '+5511999990002',
    status: :open,
    priority: :low,
    assignee: user,
    labels: ['sales'],
    browser_language: 'pt_BR',
    unread: false,
    last_incoming_body: 'This conversation should be marked as read'
  },
  {
    key: 'filter-unread-pending-medium',
    contact_name: 'Unread Pending Medium',
    email: 'unread-pending-medium@example.com',
    phone: '+5511999990003',
    status: :pending,
    priority: :medium,
    assignee: nil,
    labels: ['billing'],
    browser_language: 'es',
    unread: true,
    last_incoming_body: 'Pending unread conversation'
  },
  {
    key: 'filter-read-resolved-urgent',
    contact_name: 'Read Resolved Urgent',
    email: 'read-resolved-urgent@example.com',
    phone: '+5511999990004',
    status: :resolved,
    priority: :urgent,
    assignee: user,
    labels: %w[vip billing],
    browser_language: 'fr',
    unread: false,
    last_incoming_body: 'Resolved conversation already read'
  },
  {
    key: 'filter-unread-snoozed-low',
    contact_name: 'Unread Snoozed Low',
    email: 'unread-snoozed-low@example.com',
    phone: '+5511999990005',
    status: :snoozed,
    priority: :low,
    assignee: user,
    labels: ['bug'],
    browser_language: 'de',
    unread: true,
    last_incoming_body: 'Snoozed but still unread'
  },
  {
    key: 'filter-read-pending-high',
    contact_name: 'Read Pending High',
    email: 'read-pending-high@example.com',
    phone: '+5511999990006',
    status: :pending,
    priority: :high,
    assignee: nil,
    labels: %w[sales billing],
    browser_language: 'it',
    unread: false,
    last_incoming_body: 'Pending conversation already read'
  }
]

conversation_specs.each do |spec|
  contact_inbox = ContactInboxWithContactBuilder.new(
    inbox: inbox,
    source_id: spec[:key],
    hmac_verified: true,
    contact_attributes: {
      name: spec[:contact_name],
      email: spec[:email],
      phone_number: spec[:phone],
      additional_attributes: { company_name: 'Acme QA' }
    }
  ).perform

  conversation = Conversation.find_or_initialize_by(contact_inbox: contact_inbox)
  conversation.account = account
  conversation.inbox = inbox
  conversation.contact = contact_inbox.contact
  conversation.status = spec[:status]
  conversation.priority = spec[:priority]
  conversation.assignee = spec[:assignee]
  conversation.additional_attributes = (conversation.additional_attributes || {}).merge('browser_language' => spec[:browser_language])
  conversation.save!

  conversation.update_column(:agent_last_seen_at, nil)

  unless conversation.messages.exists?(content: 'Initial outgoing message for filter fixture')
    Message.create!(
      content: 'Initial outgoing message for filter fixture',
      account: account,
      inbox: inbox,
      conversation: conversation,
      sender: user,
      message_type: :outgoing
    )
  end

  incoming_message = conversation.messages.where(content: spec[:last_incoming_body]).first_or_create!(
    account: account,
    inbox: inbox,
    sender: contact_inbox.contact,
    message_type: :incoming
  )

  conversation.label_list = spec[:labels]
  conversation.save!

  conversation.update_columns(
    status: Conversation.statuses[spec[:status]],
    priority: Conversation.priorities[spec[:priority]],
    assignee_id: spec[:assignee]&.id,
    snoozed_until: spec[:status] == :snoozed ? 1.day.from_now : nil,
    agent_last_seen_at: spec[:unread] ? incoming_message.created_at - 5.minutes : incoming_message.created_at + 5.minutes,
    updated_at: Time.current
  )
end

summary = Conversation.joins(:contact_inbox)
                      .where(account: account)
                      .where("contact_inboxes.source_id LIKE ?", 'filter-%')
                      .order(:display_id)
                      .map do |conversation|
  {
    display_id: conversation.display_id,
    contact: conversation.contact.name,
    status: conversation.status,
    priority: conversation.priority,
    assignee: conversation.assignee&.email,
    unread_count: conversation.unread_incoming_messages.count,
    labels: conversation.label_list,
    browser_language: conversation.additional_attributes['browser_language']
  }
end

puts(
  {
    login: {
      email: user.email,
      password: 'Password1!',
      account_id: account.id,
      inbox_id: inbox.id
    },
    conversations: summary
  }.inspect
)
