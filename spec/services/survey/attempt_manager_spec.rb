require 'rails_helper'

describe Survey::AttemptManager do
  let!(:user) { FactoryBot.create(:user) }
  let!(:survey) do
    questions_1 = [
      FactoryBot.build(:question, position: 1),
      FactoryBot.build(:question, position: 2)
    ]
    questions_2 = [
      FactoryBot.build(:question, position: 1),
      FactoryBot.build(:question, position: 2)
    ]
    section_1 = FactoryBot.build :section, questions: questions_1, position: 1, identifier: "S1"
    section_2 = FactoryBot.build :section, questions: questions_2, position: 2, identifier: "S2"
    result = FactoryBot.create :survey, sections: [section_1, section_2]

    (result.sections.map(&:questions).flatten).each do |question|
      FactoryBot.create :option, question_id: question.id, position: 1, weight: 1
      FactoryBot.create :option, question_id: question.id, position: 2, weight: 2
    end

    questions_1.first.update_attributes(skip_to_question_id: questions_1.last.id)
    questions_1.first.options.update_all(next_question_id: questions_1.last.id)

    questions_1.last.update_attributes(skip_to_question_id: questions_2.first.id)
    questions_1.last.options.update_all(next_question_id: questions_2.first.id)

    questions_2.first.update_attributes(skip_to_question_id: questions_2.last.id)
    questions_2.first.options.update_all(next_question_id: questions_2.last.id)

    questions_2.last.update_attributes(skip_to_question_id: nil)
    questions_2.last.options.update_all(next_question_id: nil)

    result
  end

  let!(:section_one) { survey.sections.where(position: 1).first }
  let!(:section_two) { survey.sections.where(position: 2).first }

  let!(:questions_section_one) { section_one.questions }
  let!(:questions_section_two) { section_two.questions }

  let(:all_questions) { questions_section_one + questions_section_two }
  let(:current_question) { nil }
  let(:current_section) { nil }

  describe '#create_by_survey_identifier' do
    subject { Survey::AttemptManager.new(user) }

    it 'creates new attempt' do
      expect{ subject.create_by_survey_identifier(survey.identifier) }.to change{Survey::Attempt.count}.by(1)
    end

    context 'when user has another attempt in progress' do
      let!(:attempt) do
        FactoryBot.create(
          :attempt,
          survey: survey,
          current_section: current_section,
          current_question: current_question,
          participant: user,
          status: Survey::Attempt::Status::IN_PROGRESS
        )
      end

      it 'cancells the attempt' do
        subject.create_by_survey_identifier(survey.identifier)
        expect(attempt.reload.status).to eq(Survey::Attempt::Status::CANCELLED)
      end
    end
  end

  describe '#edit' do
    let!(:current_question) { section_one.questions.last }
    let!(:attempt) do
      FactoryBot.create(
        :attempt,
        survey: survey,
        current_section: nil,
        current_question: current_question,
        participant: user
      )
    end

    subject { Survey::AttemptManager.new(user, attempt) }

    it "changes section to selected one" do
      subject.edit(section_two)
      expect(attempt.current_section.id).to eq(section_two.id)
    end

    it "sets current question to first section's questions" do
      subject.edit(section_two)
      expect(attempt.current_question.id).to eq(section_two.questions.first.id)
    end
  end

  describe '#process_answer' do
    let(:current_question) { section_one.questions.last }
    let(:current_section) { nil }
    let(:attempt) do
      FactoryBot.create(
        :attempt,
        survey: survey,
        current_section: current_section,
        current_question: current_question,
        participant: user
      )
    end
    let(:selected_option) { current_question.options.last }
    let(:answer_params) do
      {
        question_id: current_question.id,
        option_id: selected_option.id,
        option_text: nil,
        option_number: nil
      }
    end

    subject { Survey::AttemptManager.new(user, attempt) }

    it "stores the answer" do
      expect{subject.process_answer(answer_params)}.to change{Survey::Answer.count}.by(1)
    end

    it "changes current question to the one indicated by the given answer" do
      subject.process_answer(answer_params)
      expect(attempt.reload.current_question_id).to eq(section_two.questions.first.id)
    end

    context 'when user already answered same question' do
      let!(:previous_answer) do
        Survey::Answer.create!(
          attempt_id: attempt.id,
          question_id: current_question.id,
          option_id: current_question.options.first.id,
          option_text: nil,
          option_number: nil,
        )
      end

      it "removes the previous answer" do
        subject.process_answer(answer_params)
        expect(Survey::Answer.where(id: previous_answer.id).exists?).to be_falsey
      end
    end

    context 'when current question is last one' do
      let(:current_question) { section_two.questions.last }

      it "changes current question to nil" do
        subject.process_answer(answer_params)
        expect(attempt.reload.current_question_id).to be_nil
      end
    end

    context 'when current question is last one in the current section scope' do
      let(:current_question) { section_one.questions.last }
      let(:current_section) { section_one }

      it "changes current question to nil" do
        subject.process_answer(answer_params)
        expect(attempt.reload.current_question_id).to be_nil
      end
    end

    context 'when selected option requires a custom value' do
      let(:selected_option) do
        the_option = current_question.options.last
        the_option.update_attributes!(options_type_id: Survey::OptionsType.number)
        the_option
      end

      context 'and user provided correct value' do
        let(:answer_params) do
          {
            question_id: current_question.id,
            option_id: selected_option.id,
            custom_input: 10
          }
        end

        it 'stores the value' do
          expect{subject.process_answer(answer_params)}.to change{Survey::Answer.count}.by(1)
          expect(Survey::Answer.last.option_text).to eq("10")
          expect(Survey::Answer.last.option_number).to eq(10)
        end
      end

      context 'and user provided incorrect value' do
        let(:answer_params) do
          {
            question_id: current_question.id,
            option_id: selected_option.id,
            custom_input: "haha"
          }
        end

        it 'does not store the answer because of vaildation problem' do
          expect{subject.process_answer(answer_params)}.to raise_error(ActiveRecord::RecordInvalid)
        end
      end

      context "and user didn't provide a value" do
        let(:answer_params) do
          {
            question_id: current_question.id,
            option_id: selected_option.id,
            custom_input: nil
          }
        end

        it 'does not store the answer because of vaildation problem' do
          expect{subject.process_answer(answer_params)}.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    context 'when given answer is for a different question then the current one' do
      let!(:current_question) { section_one.questions.last }
      let(:answer_params) do
        {
          question_id: section_one.questions.first.id,
          option_id: section_one.questions.first.options.first.id,
          option_text: nil,
          option_number: nil
        }
      end

      it 'raises and exception' do
        expect{subject.process_answer(answer_params)}.to raise_error
      end
    end
  end

  describe '#skip_question' do
    let!(:current_question) { section_one.questions.first }
    let!(:attempt) do
      FactoryBot.create(
        :attempt,
        survey: survey,
        current_section: nil,
        current_question: current_question,
        participant: user
      )
    end

    subject { Survey::AttemptManager.new(user, attempt) }

    it 'updates current question to the one pointed by skip_to_question field' do
      subject.skip_question
      expect(attempt.reload.current_question_id).to eq(section_one.questions.last.id)
    end

    context 'when current question is already last one' do
      let!(:current_question) { section_two.questions.last }
      it 'changes the current question to nil' do
        subject.skip_question
        expect(attempt.reload.current_question_id).to be_nil
      end
    end
  end

  describe '#previous_question' do
    let!(:current_question) { section_two.questions.last }
    let!(:attempt) do
      FactoryBot.create(
        :attempt,
        survey: survey,
        current_section: current_section,
        current_question: current_question,
        participant: user
      )
    end

    subject { Survey::AttemptManager.new(user, attempt) }

    context 'without section scope' do
      context 'when attempt already has some answers' do
        let!(:current_question) { section_two.questions.last }
        let!(:answers) do
          s1_q1 = questions_section_one.first
          s1_q2 = questions_section_one.second
          s2_q1 = questions_section_two.first
          s2_q2 = questions_section_two.second
          [
            FactoryBot.create(
              :answer, question_id: s1_q1.id, attempt_id: attempt.id, option_id: s1_q1.options.last.try(&:id)
            ),
            FactoryBot.create(
              :answer, question_id: s1_q2.id, attempt_id: attempt.id, option_id: s1_q2.options.last.try(&:id)
            ),
            FactoryBot.create(
              :answer, question_id: s2_q1.id, attempt_id: attempt.id, option_id: s2_q1.options.last.try(&:id)
            )
          ]
        end

        it 'updates current question to previous answered question' do
          subject.previous_question
          expect(attempt.reload.current_question_id).to eq(questions_section_two.first.id)
        end

        context 'and all questions have some answer' do
          let!(:current_question) { section_two.questions.first }
          let!(:answers) do
            s1_q1 = questions_section_one.first
            s1_q2 = questions_section_one.second
            s2_q1 = questions_section_two.first
            s2_q2 = questions_section_two.second
            [
              FactoryBot.create(
                :answer, question_id: s1_q1.id, attempt_id: attempt.id, option_id: s1_q1.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s1_q2.id, attempt_id: attempt.id, option_id: s1_q2.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s2_q1.id, attempt_id: attempt.id, option_id: s2_q1.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s2_q2.id, attempt_id: attempt.id, option_id: s2_q2.options.last.try(&:id)
              )
            ]
          end

          it 'updates current question to previous answered question' do
            subject.previous_question
            expect(attempt.reload.current_question_id).to eq(questions_section_one.last.id)
          end

          it 'removes answers from next questions' do
            subject.previous_question
            expect(questions_section_two.second.answers.count).to eq 0
            expect(questions_section_two.first.answers.count).to eq 0
          end
        end
      end

      context 'when attempt has no answers yet' do
        let!(:current_question) { section_two.questions.last }

        it 'updates current question to first question' do
          subject.previous_question
          expect(attempt.reload.current_question_id).to eq(questions_section_one.first.id)
        end

        context 'and current question is already first question' do
          let!(:current_question) { section_one.questions.first }

          it 'keeps current question set to first question' do
            subject.previous_question
            expect(attempt.reload.current_question_id).to eq(questions_section_one.first.id)
          end
        end
      end
    end

    context 'with section scope set to second one' do
      let!(:current_section) { section_two }

      context 'when attempt already has some answers' do
        let!(:current_question) { section_two.questions.last }
        let!(:answers) do
          s1_q1 = questions_section_one.first
          s1_q2 = questions_section_one.second
          [
            FactoryBot.create(
              :answer, question_id: s1_q1.id, attempt_id: attempt.id, option_id: s1_q1.options.last.try(&:id)
            ),
            FactoryBot.create(
              :answer, question_id: s1_q2.id, attempt_id: attempt.id, option_id: s1_q2.options.last.try(&:id)
            )
          ]
        end

        it 'updates current question to previous answered question' do
          subject.previous_question
          expect(attempt.reload.current_question_id).to eq(questions_section_two.first.id)
        end

        context 'and all questions have some answer' do
          let!(:current_question) { section_two.questions.last }
          let!(:answers) do
            s1_q1 = questions_section_one.first
            s1_q2 = questions_section_one.second
            s2_q1 = questions_section_two.first
            s2_q2 = questions_section_two.second
            [
              FactoryBot.create(
                :answer, question_id: s1_q1.id, attempt_id: attempt.id, option_id: s1_q1.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s1_q2.id, attempt_id: attempt.id, option_id: s1_q2.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s2_q1.id, attempt_id: attempt.id, option_id: s2_q1.options.last.try(&:id)
              ),
              FactoryBot.create(
                :answer, question_id: s2_q2.id, attempt_id: attempt.id, option_id: s2_q2.options.last.try(&:id)
              )
            ]
          end

          it 'removes answers from next questions' do
            subject.previous_question
            expect(questions_section_two.second.answers.count).to eq 0
            expect(questions_section_two.first.answers.count).to eq 1
          end
        end
      end

      context 'when attempt has no answers yet' do
        it 'updates current question to first question in the current section' do
          subject.previous_question
          expect(attempt.reload.current_question_id).to eq(questions_section_two.first.id)
        end

        context 'and current question is already first question' do
          let!(:current_question) { section_two.questions.first }

          it 'keeps current question set to first question' do
            subject.previous_question
            expect(attempt.reload.current_question_id).to eq(questions_section_two.first.id)
          end
        end
      end
    end
  end

  describe '#confirm' do
    let!(:attempt) do
      FactoryBot.create(
        :attempt,
        survey: survey,
        current_section: nil,
        current_question: current_question,
        participant: user
      )
    end

    subject { Survey::AttemptManager.new(user, attempt) }

    it "changes attempt's status to confirmed" do
      subject.confirm

      expect(attempt.reload.status).to eq(Survey::Attempt::Status::CONFIRMED)
    end

    context 'when another confirmed attempt already exists' do
      let!(:already_confirmed_attempt) do
        FactoryBot.create(
          :attempt,
          survey: survey,
          current_section: nil,
          current_question: current_question,
          participant: user,
          status: Survey::Attempt::Status::CONFIRMED
        )
      end
      it "changes expires the confirmed attempt" do
        subject.confirm

        expect(already_confirmed_attempt.reload.status).to eq(Survey::Attempt::Status::EXPIRED)
      end
    end
  end
end
