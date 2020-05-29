# frozen_string_literal: true

class AddFieldsToSurveyTables < ActiveRecord::Migration[5.1]
  def change
    # Survey Surveys table
    add_column :survey_surveys, :identifier, :string

    # Survey Attempts table
    add_column :survey_attempts, :current_section_id, :integer
    add_column :survey_attempts, :current_question_id, :integer
    add_column :survey_attempts, :status, :string

    # Survey Sections table
    add_column :survey_sections, :position, :integer

    # Survey Questions table
    add_column :survey_questions, :icon_file_name, :string
    add_column :survey_questions, :icon_content_type, :string
    add_column :survey_questions, :icon_file_size, :integer, default: 0
    add_column :survey_questions, :icon_updated_at, :datetime
    add_column :survey_questions, :position, :integer
    add_column :survey_questions, :skip_to_question_id, :integer

    # Survey Options table
    add_column :survey_options, :next_question_id, :integer
    add_column :survey_options, :position, :integer
  end
end
