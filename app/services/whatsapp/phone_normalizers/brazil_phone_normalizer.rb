# Handles Brazil phone number normalization
# ref: https://github.com/chatwoot/chatwoot/issues/5840
#
# Brazil changed its mobile number system by adding a "9" prefix to existing numbers.
# This normalizer adds the "9" digit if the number is 12 digits (making it 13 digits total)
# to match the new format: 55 + DDD + 9 + number
class Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer < Whatsapp::PhoneNormalizers::BasePhoneNormalizer
  COUNTRY_CODE_LENGTH = 2
  DDD_LENGTH = 2

  def normalize(waid)
    return waid unless handles_country?(waid)

    ddd = waid[COUNTRY_CODE_LENGTH, DDD_LENGTH]
    number = waid[COUNTRY_CODE_LENGTH + DDD_LENGTH, waid.length - (COUNTRY_CODE_LENGTH + DDD_LENGTH)]
    normalized_number = "55#{ddd}#{number}"
    normalized_number = "55#{ddd}9#{number}" if normalized_number.length != 13
    normalized_number
  end

  # Brazilian mobiles live in the wild in both shapes: 55 + DDD + 9 + 8 digits
  # (current) and 55 + DDD + 8 digits (pre-2012 accounts, which is what WhatsApp
  # still uses as the JID for most of them). Looking up only one shape splits the
  # same person into two contacts.
  def variants(waid)
    return [waid] unless handles_country?(waid)

    ddd = waid[COUNTRY_CODE_LENGTH, DDD_LENGTH].to_s
    number = waid[(COUNTRY_CODE_LENGTH + DDD_LENGTH)..].to_s
    bare = number.length == 9 && number.start_with?('9') ? number[1..] : number

    ["55#{ddd}9#{bare}", "55#{ddd}#{bare}", waid].uniq
  end

  private

  def country_code_pattern
    /^55/
  end
end
