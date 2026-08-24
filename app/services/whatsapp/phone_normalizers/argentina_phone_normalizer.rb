# Handles Argentina phone number normalization
#
# Argentina phone numbers can appear with or without "9" after country code
# This normalizer removes the "9" when present to create consistent format: 54 + area + number
class Whatsapp::PhoneNormalizers::ArgentinaPhoneNormalizer < Whatsapp::PhoneNormalizers::BasePhoneNormalizer
  def normalize(waid)
    return waid unless handles_country?(waid)

    # Remove "9" after country code if present (549 → 54)
    waid.sub(/^549/, '54')
  end

  # Same subscriber appears as 54... and 549...; try both on lookup.
  def variants(waid)
    return [waid] unless handles_country?(waid)

    without_ninth = waid.sub(/^549/, '54')
    with_ninth = without_ninth.sub(/^54/, '549')

    [without_ninth, with_ninth, waid].uniq
  end

  private

  def country_code_pattern
    /^54/
  end
end
