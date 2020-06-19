# frozen_string_literal: true

class UpdateOptions2 < ActiveRecord::Migration
  def change
    remove_column :survey_options, :total_weight, :decimal

    change_column :survey_answers, :option_number, :decimal
  end
end
