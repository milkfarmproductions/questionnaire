# frozen_string_literal: true

class Survey::OptionsType
  @@options_types = { multi_choices: 1,
                      single_choice: 2,
                      number: 3,
                      text: 4,
                      multi_choices_with_text: 5,
                      single_choice_with_text: 6,
                      multi_choices_with_number: 7,
                      single_choice_with_number: 8,
                      large_text: 9}

  @@supported_options_types = {single_choice: 2, number: 3}

  def self.options_types
    @@supported_options_types
  end

  def self.options_types_title
    titled = {}
    Survey::OptionsType.options_types.each { |k, v| titled[k.to_s.titleize] = v }
    titled
  end

  def self.options_type_ids
    @@supported_options_types.values
  end

  def self.options_type_keys
    @@supported_options_types.keys
  end

  @@options_types.each do |key, val|
    define_singleton_method key.to_s do
      val
    end
  end
end
