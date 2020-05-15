FactoryBot.define do
  factory :question, class: Survey::Question do
    sequence(:text) { |n| "Question no. #{n}" }
    head_number { "1" }
    description { "Just a regular question, but remember - be honest!" }
    questions_type_id { Survey::QuestionsType.questions_types[:multi_select] }
  end
end
