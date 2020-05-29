FactoryBot.define do
  factory :option, class: Survey::Option do
    sequence(:text) { |n| "Option no. #{n}" }
    sequence(:weight) { |n| n }
    sequence(:position) { |n| n }

    options_type_id { Survey::OptionsType.options_types[:single_choice] }
  end
end
