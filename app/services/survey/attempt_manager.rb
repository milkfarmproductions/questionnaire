# frozen_string_literal: true

class Survey::AttemptManager
  attr_reader :attempt

  def initialize(user, attempt = nil)
    @user = user
    @attempt = attempt
  end

  def create_by_survey_identifier(identifier)
    ActiveRecord::Base.transaction do
      cancel_previous_attempts!

      survey = Survey::Survey.active_by_identifier(identifier)
      @attempt = Survey::Attempt.create!(participant: @user, survey: survey)
    end
  end

  def edit(section)
    @attempt.current_section = section
    @attempt.current_question = @attempt.first_question_in_current_section
    @attempt.save!
  end

  def process_answer(params)
    raise_incorrect_question if params[:question_id].to_i != @attempt.current_question_id.to_i

    option = Survey::Option.find(params[:option_id])

    ActiveRecord::Base.transaction do
      Survey::Answer.where(
        attempt_id: @attempt.id,
        question_id: @attempt.current_question_id
      ).each(&:destroy!)

      Survey::Answer.create!(
        attempt_id: @attempt.id,
        question_id: @attempt.current_question_id,
        option_id: option.id,
        option_text: params[:custom_input].to_s,
        option_number: params[:custom_input],
      )

      assign_current_question(option.next_question_id)
      @attempt.collect_scores!
      @attempt.save!
    end
  end

  def skip_question
    assign_current_question(@attempt.current_question.skip_to_question_id)
    @attempt.save!
  end

  def previous_question
    ActiveRecord::Base.transaction do
      previous_question_with_answer = @attempt.previous_questions_with_answers.last

      @attempt.current_question_id = (previous_question_with_answer || @attempt.first_question_in_current_section).id
      @attempt.save!

      discard_next_answers!
    end
  end

  def confirm
    ActiveRecord::Base.transaction do
      expire_previous_attempts!
      @attempt.confirm!
    end
  end

  private

  def assign_current_question(question_id)
    next_question = Survey::Question.where(id: question_id).last
    if next_question.blank?
      @attempt.current_question_id = nil
      return
    end

    if @attempt.current_section_id.blank? || next_question.section_id == @attempt.current_section_id
      @attempt.current_question_id = next_question.id
    else
      @attempt.current_question_id = nil
    end
  end

  def raise_incorrect_question
    message = "You're trying to post answer to question from incorrect section.\n"
    message += "Current section is: '#{current_section.name}'"

    raise message
  end

  def cancel_previous_attempts!
    Survey::Attempt.where(participant_id: @user.id).in_progress.each(&:cancel!)
  end

  def expire_previous_attempts!
    Survey::Attempt.where(participant_id: @user.id).confirmed.each(&:expire!)
  end

  def discard_next_answers!
    ids_to_discard = @attempt.remaining_questions.pluck(:id)
    @attempt.answers.where(question_id: ids_to_discard).each(&:destroy)
  end
end
