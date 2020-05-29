# frozen_string_literal: true

class AddLessonIdToSurveySurveys < ActiveRecord::Migration[5.1]
  def change
    add_column :survey_surveys, :lesson_id, :integer
  end
end
