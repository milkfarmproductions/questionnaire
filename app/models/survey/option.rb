# frozen_string_literal: true

class Survey::Option < ActiveRecord::Base
  self.table_name = 'survey_options'
  # relations
  belongs_to :question
  has_many :answers

  # rails 3 attr_accessible support
  if Rails::VERSION::MAJOR < 4
    attr_accessible :text, :correct, :weight, :question_id, :locale_text, :options_type_id, :head_number
  end

  # validations
  validates :text, presence: true, allow_blank: false, if: proc { |o| [Survey::OptionsType.multi_choices, Survey::OptionsType.single_choice, Survey::OptionsType.single_choice_with_text, Survey::OptionsType.single_choice_with_number, Survey::OptionsType.multi_choices_with_text, Survey::OptionsType.multi_choices_with_number, Survey::OptionsType.large_text].include?(o.options_type_id) }
  validates :options_type_id, presence: true
  validates :options_type_id, inclusion: { in: Survey::OptionsType.options_type_ids, unless: proc { |o| o.options_type_id.blank? } }

  scope :correct, -> { where(correct: true) }
  scope :incorrect, -> { where(correct: false) }

  before_create :default_option_weigth

  def to_s
    text
  end

  def correct?
    correct == true
  end

  def text
    I18n.locale == I18n.default_locale ? super : locale_text.blank? ? super : locale_text
  end

  def is_custom_input
    options_type_id == Survey::OptionsType.options_types[:number]
  end

  def has_formula?
    weight_formula.present?
  end

  def value_for_answer(answer)
    @current_attempt_id = answer.attempt_id
    weight_from_formula(answer.option_number) || weight
  end

  def weight_from_formula(option_number)
    return nil unless has_formula?
    eval(weight_formula)
  end

  def value_for_question(question_id)
    question = Survey::Question.find_by_id(question_id)
    answer = question.answers.where(attempt_id: @current_attempt_id).last

    answer.present? ? answer.value : 0
  end

  #######

  private

  #######

  def default_option_weigth
    self.weight = 1 if correct && weight == 0
  end
end
