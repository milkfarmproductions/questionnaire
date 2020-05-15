# frozen_string_literal: true

class AddIdentifierToSectionsTable < ActiveRecord::Migration[5.1]
  def change
    add_column :survey_sections, :identifier, :string
  end
end
