require 'rails_helper'

describe Whatsapp::PhoneNumberNormalizationService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:service) { described_class.new(inbox) }

  # Brazilian mobiles exist in two shapes in the wild:
  #   5541996957934 -> 55 + DDD + 9 + 8 digits (current numbering)
  #   554196957934  -> 55 + DDD + 8 digits     (JID WhatsApp still uses for most)
  # Looking up a single shape is what splits one person into two contacts.
  let(:with_ninth) { '5541996957934' }
  let(:without_ninth) { '554196957934' }

  def contact_inbox_with(source_id)
    create(:contact_inbox, inbox: inbox, contact: create(:contact, account: account), source_id: source_id)
  end

  describe '#normalize_and_find_contact_by_provider' do
    context 'when the contact already exists in the other shape' do
      it 'finds the with-ninth contact for a without-ninth inbound' do
        contact_inbox_with(with_ninth)

        expect(service.normalize_and_find_contact_by_provider(without_ninth, :cloud)).to eq(with_ninth)
      end

      it 'finds the without-ninth contact for a with-ninth inbound' do
        contact_inbox_with(without_ninth)

        expect(service.normalize_and_find_contact_by_provider(with_ninth, :cloud)).to eq(without_ninth)
      end
    end

    context 'when both shapes exist' do
      it 'prefers the canonical normalized shape' do
        contact_inbox_with(without_ninth)
        contact_inbox_with(with_ninth)

        expect(service.normalize_and_find_contact_by_provider(without_ninth, :cloud)).to eq(with_ninth)
      end
    end

    context 'when no contact exists' do
      it 'returns the raw number so the caller creates it' do
        expect(service.normalize_and_find_contact_by_provider(without_ninth, :cloud)).to eq(without_ninth)
      end
    end

    context 'with an unsupported country' do
      it 'returns the raw number untouched' do
        expect(service.normalize_and_find_contact_by_provider('351912345678', :cloud)).to eq('351912345678')
      end
    end

    context 'with the twilio provider' do
      it 'matches across shapes keeping the twilio prefix' do
        contact_inbox_with("whatsapp:+#{with_ninth}")

        expect(service.normalize_and_find_contact_by_provider("whatsapp:+#{without_ninth}", :twilio))
          .to eq("whatsapp:+#{with_ninth}")
      end
    end
  end
end
