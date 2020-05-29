FactoryBot.define do
  factory :survey, class: Survey::Survey do
    name { 'The Best Survey on da Planet!' }
    description { 'We want to know everything about everyone some please provide honest answers' }
    active { true }
    identifier { 'the-best' }
  end
end
