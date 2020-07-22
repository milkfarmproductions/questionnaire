# frozen_string_literal: true

class UpdateOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :survey_options, :total_weight, :decimal
    add_column :survey_options, :weight_formula, :string

    change_column :survey_options, :weight, :decimal
  end
end
