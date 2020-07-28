# frozen_string_literal: true

class Survey::Question < ActiveRecord::Base
  include Paperclip::Glue

  self.table_name = 'survey_questions'
  # relations

  # https://makandracards.com/makandra/1023-paperclip-image-resize-options
  has_attached_file :icon, styles: { thumbnail: "400x140>" }
  has_many   :options
  has_many   :predefined_values
  has_many   :answers
  belongs_to :section

  # rails 3 attr_accessible support
  if Rails::VERSION::MAJOR < 4
    attr_accessible :options_attributes, :predefined_values_attributes, :text, :section_id, :head_number, :description, :locale_text, :locale_head_number, :locale_description, :questions_type_id
  end

  accepts_nested_attributes_for :options,
                                reject_if: ->(a) { a[:options_type_id].blank? },
                                allow_destroy: true

  accepts_nested_attributes_for :predefined_values,
                                reject_if: ->(a) { a[:name].blank? },
                                allow_destroy: true

  # validations
  validates_attachment :icon, content_type: { content_type: ["image/jpeg", "image/gif", "image/png"] }
  validates :text, presence: true, allow_blank: false
  validates :questions_type_id, presence: true
  validates :questions_type_id, inclusion: { in: Survey::QuestionsType.questions_type_ids, unless: proc { |q| q.questions_type_id.blank? } }

  scope :mandatory_only, -> { where(mandatory: true) }

  def icon_url
    return nil if icon.blank?
    "https://#{ENV['S3_BUCKET_NAME']}.s3.#{ENV['AWS_REGION']}.amazonaws.com#{icon.path}"
  end

  def icon_thumb_url
    return nil if icon.blank?
    "https://#{ENV['S3_BUCKET_NAME']}.s3.#{ENV['AWS_REGION']}.amazonaws.com#{icon.path(:thumbnail)}"
  end

  def correct_options
    options.correct
  end

  def incorrect_options
    options.incorrect
  end

  def text
    I18n.locale == I18n.default_locale ? super : locale_text.blank? ? super : locale_text
  end

  def description
    I18n.locale == I18n.default_locale ? super : locale_description.blank? ? super : locale_description
  end

  def head_number
    I18n.locale == I18n.default_locale ? super : locale_head_number.blank? ? super : locale_head_number
  end

  def mandatory?
    mandatory == true
  end

  def sorted_options
    options.sort_by(&:position)
  end
end
