require 'rails_helper'

describe Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer do
  subject(:normalizer) { described_class.new }

  describe '#normalize' do
    it 'adds the ninth digit to a 12 digit number' do
      expect(normalizer.normalize('554196957934')).to eq('5541996957934')
    end

    it 'keeps a 13 digit number as is' do
      expect(normalizer.normalize('5541996957934')).to eq('5541996957934')
    end

    it 'leaves other countries alone' do
      expect(normalizer.normalize('351912345678')).to eq('351912345678')
    end
  end

  describe '#variants' do
    it 'returns both shapes for a 12 digit number, canonical first' do
      expect(normalizer.variants('554196957934')).to eq(%w[5541996957934 554196957934])
    end

    it 'returns both shapes for a 13 digit number, canonical first' do
      expect(normalizer.variants('5541996957934')).to eq(%w[5541996957934 554196957934])
    end

    it 'returns the number untouched for other countries' do
      expect(normalizer.variants('351912345678')).to eq(['351912345678'])
    end
  end
end
