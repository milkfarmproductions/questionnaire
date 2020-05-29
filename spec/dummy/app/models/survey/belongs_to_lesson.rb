# frozen_string_literal: true

module Survey
  module BelongsToLesson
    extend ActiveSupport::Concern
    included do
      belongs_to :lesson
    end
  end
end
