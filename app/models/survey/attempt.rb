# frozen_string_literal: true

class Survey::Attempt < ActiveRecord::Base
  self.table_name = 'survey_attempts'

  class Status
    IN_PROGRESS = 'in_progress'
    CANCELLED = 'cancelled'
    CONFIRMED = 'confirmed'
    EXPIRED = 'expired'
  end

  # relations

  has_many :answers, dependent: :destroy
  belongs_to :survey
  belongs_to :participant, polymorphic: true
  belongs_to :current_section, class_name: 'Survey::Section'
  belongs_to :current_question, class_name: 'Survey::Question'

  # rails 3 attr_accessible support
  if Rails::VERSION::MAJOR < 4
    attr_accessible :participant_id, :survey_id, :answers_attributes, :survey, :winner, :participant
  end

  # validations
  validates :participant_id, :participant_type,
            presence: true

  accepts_nested_attributes_for :answers,
                                reject_if: ->(q) { q[:question_id].blank? && q[:option_id].blank? },
                                allow_destroy: true

  # scopes

  scope :for_survey, ->(survey) {
    where(survey_id: survey.try(:id))
  }

  scope :exclude_survey, ->(survey) {
    where("NOT survey_id = #{survey.try(:id)}")
  }

  scope :for_participant, ->(participant) {
    where(participant_id: participant.try(:id),
          participant_type: participant.class.to_s)
  }

  scope :wins, -> { where(winner: true) }
  scope :looses, -> { where(winner: false) }
  scope :scores, -> { order('score DESC') }

  scope :in_progress, -> { where(status: Status::IN_PROGRESS)}
  scope :cancelled, -> { where(status: Status::CANCELLED)}
  scope :confirmed, -> { where(status: Status::CONFIRMED)}
  scope :expired, -> { where(status: Status::EXPIRED)}

  # callbacks

  validate :check_number_of_attempts_by_survey, on: :create
  after_create :collect_scores
  before_create :setup_defaults

  def correct_answers
    answers.where(correct: true)
  end

  def incorrect_answers
    answers.where(correct: false)
  end

  def collect_scores!
    collect_scores
    save
  end

  def current_progress
    questions_left_count = remaining_questions.count + 1
    questions_answered_count = answers.count

    questions_answered_count.to_f / (questions_answered_count + questions_left_count)
  end

  def questions_scoped_by_section
    result = survey.questions
    result = result.where(section_id: current_section_id) if current_section_id.present?
    result = result.order("survey_sections.position asc, survey_questions.position asc")
    result
  end

  def is_last_question
    current_question.blank? || current_question.id == last_question_in_current_section.id
  end

  def is_first_question
    current_question.present? && current_question.id == first_question_in_current_section.id
  end

  def first_question
    survey.questions.order("survey_sections.position asc, survey_questions.position asc").first
  end

  def first_question_in_current_section
    questions_scoped_by_section.first
  end

  def last_question_in_current_section
    questions_scoped_by_section.last
  end

  def score_by_section
    answers_with_questions = self.answers.includes(question: :section)
    grouped_answers = answers_with_questions.group_by do |answer|
      answer.question.section.name
    end
    
    grouped_answers.map do |category, answers|
      {
        identifier: category,
        score: answers.map(&:value).map(&:to_f).reduce(:+)
      }
    end
  end

  def remaining_questions
    return [] if current_question.blank?

    survey.questions
      .order("survey_sections.position asc, survey_questions.position asc")
      .where("
        survey_sections.position >= :current_questions_section_position
        AND (
          survey_questions.position > :current_question_position
          OR survey_sections.position > :current_questions_section_position
        )", {
          current_questions_section_position: current_question.section.position,
          current_question_position: current_question.position
        }
      )
  end

  def previous_questions_with_answers
    result = survey.questions
      .order("survey_sections.position asc, survey_questions.position asc")
      .joins("
        JOIN survey_answers
        ON survey_answers.question_id = survey_questions.id
        AND survey_answers.attempt_id = #{id}
      ")
    if current_question.present?
      result = result.where("
        survey_sections.position <= :current_questions_section_position
        AND (
          survey_questions.position < :current_question_position
          OR survey_sections.position < :current_questions_section_position
        )", {
          current_questions_section_position: current_question.section.position,
          current_question_position: current_question.position
        }
      )
    end

    result = result.where(section_id: current_section_id) if current_section_id.present?
    result
  end

  def cancel!
    self.status = Status::CANCELLED
    self.save!
  end

  def confirm!
    self.status = Status::CONFIRMED
    self.save!
  end

  def expire!
    self.status = Status::EXPIRED
    self.save!
  end

  def self.high_score
    scores.first.score
  end

  private

  def setup_defaults
    self.current_question ||= first_question
    self.status ||= Status::IN_PROGRESS
  end

  def check_number_of_attempts_by_survey
    attempts = self.class.for_survey(survey).for_participant(participant)
    upper_bound = survey.attempts_number
    errors.add(:questionnaire_id, 'Number of attempts exceeded') if attempts.size >= upper_bound && upper_bound.nonzero?
  end

  def collect_scores
    multi_select_questions = Survey::Question.joins(:section)
                                             .where(survey_sections: { survey_id: survey.id },
                                                    survey_questions: {
                                                      questions_type_id: Survey::QuestionsType.multi_select
                                                    })
    if multi_select_questions.empty? # No multi-select questions
      total_scores_by_section = score_by_section
      raw_score = total_scores_by_section.map do |section|
        section[:score]
      end
      self.score = raw_score.reduce(:+)
    else
      # Initial score without multi-select questions
      raw_score = answers.where.not(question_id: multi_select_questions.ids).map(&:value).reduce(:+) || 0
      multi_select_questions.each do |question|
        options = question.options
        correct_question_answers = answers.where(question_id: question.id, correct: true)
        break if correct_question_answers.empty? # If they didn't select any correct answers, then skip this step
        correct_options_sum = options.correct.map(&:weight).reduce(:+)
        correct_percentage = correct_question_answers.map(&:value).reduce(:+).fdiv(correct_options_sum)
        raw_score += correct_percentage
        if correct_percentage == 1
          option_value = 1 / options.count.to_f
          raw_score -= (option_value * answers.where(question_id: question.id, correct: false).count)
        end
      end
      self.score = raw_score || 0
      save
    end
  end
end
