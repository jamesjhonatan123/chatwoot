require 'rails_helper'

RSpec.describe FollowUps::ConditionEvaluator do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:run) do
    create(
      :follow_up_run,
      account: account,
      conversation: conversation,
      user: user,
      anchor_at: 1.hour.ago
    )
  end

  it 'passes when there is no incoming message since the anchor' do
    result = described_class.new(
      conversation: conversation,
      run: run,
      conditions: [
        {
          'attribute_key' => 'no_incoming_since_anchor',
          'filter_operator' => 'equal_to',
          'values' => [true]
        }
      ]
    ).perform

    expect(result).to be(true)
  end

  it 'fails when an incoming message arrives after the anchor' do
    create(
      :message,
      account: account,
      inbox: inbox,
      conversation: conversation,
      message_type: :incoming,
      content: 'customer replied',
      created_at: 30.minutes.ago
    )

    result = described_class.new(
      conversation: conversation,
      run: run,
      conditions: [
        {
          'attribute_key' => 'no_incoming_since_anchor',
          'filter_operator' => 'equal_to',
          'values' => [true]
        }
      ]
    ).perform

    expect(result).to be(false)
  end

  it 'evaluates conversation status' do
    result = described_class.new(
      conversation: conversation,
      run: run,
      conditions: [
        {
          'attribute_key' => 'status',
          'filter_operator' => 'equal_to',
          'values' => ['open']
        }
      ]
    ).perform

    expect(result).to be(true)
  end
end
