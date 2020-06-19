# frozen_string_literal: true

class Survey::Survey < ActiveRecord::Base
  self.table_name = 'survey_surveys'

  # relations
  has_many :attempts
  has_many :sections
  has_many :questions, through: :sections

  # rails 3 attr_accessible support
  if Rails::VERSION::MAJOR < 4
    attr_accessible :name, :description, :finished, :active, :sections_attributes, :attempts_number, :locale_name, :locale_description
  end

  accepts_nested_attributes_for :sections,
                                reject_if: ->(q) { q[:name].blank? }, allow_destroy: true

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validates :attempts_number,
            numericality: { only_integer: true, greater_than: -1 }

  # validations
  validates :description, :name, presence: true, allow_blank: false
  validate  :check_active_requirements

  def self.active_by_identifier!(identifier)
    self.active.order(:created_at).where(identifier: identifier).last!
  end

  # returns all the correct options for current surveys
  def correct_options
    Survey::Question.where(section_id: section_ids).map(&:correct_options).flatten
  end

  # returns all the incorrect options for current surveys
  def incorrect_options
    Survey::Question.where(section_id: sections.collect(&:id)).map(&:incorrect_options).flatten
  end

  def questions_as_collection
    titled = {}
    questions.map {|q| titled[q.text] = q.id}
    titled
  end

  def avaliable_for_participant?(participant)
    current_number_of_attempts =
      attempts.for_participant(participant).size
    upper_bound = attempts_number
    !((current_number_of_attempts >= upper_bound && upper_bound != 0))
  end

  def name
    I18n.locale == I18n.default_locale ? super : locale_name.blank? ? super : locale_name
  end

  def description
    I18n.locale == I18n.default_locale ? super : locale_description.blank? ? super : locale_description
  end

  #######

  private

  #######

  # a surveys only can be activated if has one or more sections and questions
  def check_active_requirements
    if sections.empty? || sections.collect(&:questions).empty?
      errors.add(:base, 'Survey without sections or questions cannot be saved')
    end
  end
end
