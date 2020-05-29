# frozen_string_literal: true

class Lesson < ActiveRecord::Base
  has_many_surveys
end
