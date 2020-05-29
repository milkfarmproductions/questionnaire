FactoryBot.define do
  factory :section, class: Survey::Section do
    sequence(:name) { |n| "Section no. #{n}" }
    description { 'Just a section' }
    sequence(:position) { |n| n }
  end
end
