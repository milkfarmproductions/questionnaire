require 'rails_helper'

RSpec.describe Survey::Attempt, type: :model do
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

    result
  end

  let!(:section_one) { survey.sections.where(position: 1).first }
  let!(:section_two) { survey.sections.where(position: 2).first }

  let!(:questions_section_one) { section_one.questions }
  let!(:questions_section_two) { section_two.questions }

  let(:all_questions) { questions_section_one + questions_section_two }
  let(:current_question) { nil }
  let(:current_section) { nil }

  subject do
    FactoryBot.create(
      :attempt,
      survey: survey,
      current_section: current_section,
      current_question: current_question,
      participant: user
    )
  end

  describe 'Created attempt' do
    it 'has first question set as current question and current section is nil' do
      expect(subject.current_question.id).to eq(section_one.questions.first.id)
      expect(subject.current_section).to be_nil
    end
  end

  describe '#score_by_section' do
    context "when user didn't anwser any question" do
      it 'returns zeroes grouped by sections' do
        expect(subject.score_by_section).to eq([])
      end
    end

    context "when user anwsered all question using awswers with weight 2" do
      let!(:answers) do
        result = []
        all_questions.each do |question|
          result << FactoryBot.create(
            :answer,
            question_id: question.id,
            attempt_id: subject.id,
            option_id: question.options.last.try(&:id)
          )
        end
        result
      end

      it 'returns sum of answers score grouped by sections' do
        expect(subject.score_by_section).to eq([
          {
            identifier: 'S1',
            score: 4
          },
          {
            identifier: 'S2',
            score: 4
          },
        ])
      end
    end
  end

  describe '#cancel!' do
    it 'sets attempt status to cancelled' do
      subject.cancel!
      expect(subject.status).to eq(Survey::Attempt::Status::CANCELLED)
    end
  end

  describe '#confirm!' do
    it 'sets attempt status to confirmed' do
      subject.confirm!
      expect(subject.status).to eq(Survey::Attempt::Status::CONFIRMED)
    end
  end

  describe '#expire!' do
    it 'sets attempt status to expired' do
      subject.expire!
      expect(subject.status).to eq(Survey::Attempt::Status::EXPIRED)
    end
  end

  describe '#questions_scoped_by_section' do
    context "when attempt's context has no current section" do
      let(:current_section) { nil }

      it 'returns all questions' do
        expect(subject.questions_scoped_by_section.count).to eq(4)
        expect(subject.questions_scoped_by_section.pluck(:id).sort).to eq(all_questions.pluck(:id).sort)
      end
    end

    context "when attempt's context has current section set to first one" do
      let(:current_section) { section_one }

      it 'returns questions scoped by first section' do
        expect(subject.questions_scoped_by_section.count).to eq(2)
        expect(subject.questions_scoped_by_section.pluck(:id).sort).to eq(questions_section_one.pluck(:id).sort)
      end
    end

    context "when attempt's context has current section set to second one" do
      let(:current_section) { section_two }

      it 'returns questions scoped by second section' do
        expect(subject.questions_scoped_by_section.count).to eq(2)
        expect(subject.questions_scoped_by_section.pluck(:id).sort).to eq(questions_section_two.pluck(:id).sort)
      end
    end
  end

  describe '#remaining_questions' do
    context "when attempt's context has no current section" do
      let(:current_section) { nil }

      it 'returns all remaining questions' do
        subject.current_question = questions_section_one.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_one.last.id,
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_one.last
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.last
        expect(subject.remaining_questions.pluck(:id)).to eq([])
      end
    end

    context "when attempt's context has current section set to first one" do
      let(:current_section) { section_one }

      it 'the section context is ignored and still return all remaining questions' do
        subject.current_question = questions_section_one.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_one.last.id,
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_one.last
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.last
        expect(subject.remaining_questions.pluck(:id)).to eq([])
      end
    end
  end

  describe '#current_progress' do
    context "when attempt's context has no current section" do
      let(:current_section) { nil }

      context "when current question is 1st from 1st section" do
        let(:current_question) { questions_section_one.first }

        it 'returns 0 / 4' do
          expect(subject.current_progress).to eq(0.0/4)
        end
      end

      context "when current question is 2nd from 1st section" do
        let(:current_question) { questions_section_one.second }

        context "and user answered prev question" do
          let!(:answers) do
            [
              FactoryBot.create(
                :answer,
                question_id: questions_section_one.first.id,
                attempt_id: subject.id,
                option_id: questions_section_one.first.options.last.try(&:id)
              )
            ]
          end

          it 'returns 1 / 4' do
            expect(subject.current_progress).to eq(1.0/4)
          end
        end

        context "and user skipped prev question" do
          it 'returns 0 / 3' do
            expect(subject.current_progress).to eq(0.0/3)
          end
        end
      end

      context "when current question is 1nd from 2nd section" do
        let(:current_question) { questions_section_two.first }

        context "and user answered all prev questions" do
          let!(:answers) do
            result = []
            questions_section_one.each do |question|
              result << FactoryBot.create(
                :answer,
                question_id: question.id,
                attempt_id: subject.id,
                option_id: question.options.last.try(&:id)
              )
            end
            result
          end

          it 'returns 2 / 4' do
            expect(subject.current_progress).to eq(2.0/4)
          end
        end

        context "and user skipped all prev questions" do
          it 'returns 0 / 2' do
            expect(subject.current_progress).to eq(0.0/2)
          end
        end

        context "and user answered one prev question and skipped one" do
          let!(:answers) do
            [
              FactoryBot.create(
                :answer,
                question_id: questions_section_one.second.id,
                attempt_id: subject.id,
                option_id: questions_section_one.second.options.last.try(&:id)
              )
            ]
          end

          it 'returns 1 / 3' do
            expect(subject.current_progress).to eq(1.0/3)
          end
        end
      end

      context "when current question is 2nd from 2st section" do
        let(:current_question) { questions_section_two.second }

        context "and user answered all prev questions" do
          let!(:answers) do
            result = []
            (questions_section_one + [questions_section_two.first]).each do |question|
              result << FactoryBot.create(
                :answer,
                question_id: question.id,
                attempt_id: subject.id,
                option_id: question.options.last.try(&:id)
              )
            end
            result
          end

          it 'returns 3 / 4' do
            expect(subject.current_progress).to eq(3.0/4)
          end
        end

        context "and user skipped all prev questions" do
          it 'returns 1 / 1' do
            expect(subject.current_progress).to eq(0.0/1)
          end
        end

        context "and user answered one prev questions and skipped two" do
          let!(:answers) do
            [
              FactoryBot.create(
                :answer,
                question_id: questions_section_one.second.id,
                attempt_id: subject.id,
                option_id: questions_section_one.second.options.last.try(&:id)
              )
            ]
          end

          it 'returns 1 / 2' do
            expect(subject.current_progress).to eq(1.0/2)
          end
        end
      end
    end

    context "when attempt's context has current section set to first one" do
      let(:current_section) { section_one }

      it 'the section context is ignored and still return all remaining questions' do
        subject.current_question = questions_section_one.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_one.last.id,
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_one.last
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.first.id,
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.first
        expect(subject.remaining_questions.pluck(:id)).to eq([
          questions_section_two.last.id,
        ])

        subject.current_question = questions_section_two.last
        expect(subject.remaining_questions.pluck(:id)).to eq([])
      end
    end
  end

  describe '#is_first_question' do
    context "when attempt's context has no current section" do
      let(:current_section) { nil }

      context "and current question is first from first section" do
        let(:current_question) { questions_section_one.first }

        it 'returns true' do
          expect(subject.is_first_question).to eq(true)
        end
      end

      context "and current question is first from second section" do
        let(:current_question) { questions_section_two.first }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end

      context "and current question is second from first section" do
        let(:current_question) { questions_section_one.second }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end
    end

    context "when attempt's context has current section set to first one" do
      let(:current_section) { section_one }

      context "and current question is first from first section" do
        let(:current_question) { questions_section_one.first }

        it 'returns true' do
          expect(subject.is_first_question).to eq(true)
        end
      end

      context "and current question is first from second section" do
        let(:current_question) { questions_section_two.first }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end

      context "and current question is second from first section" do
        let(:current_question) { questions_section_one.second }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end
    end

    context "when attempt's context has current section set to second one" do
      let(:current_section) { section_two }

      context "and current question is first from first section" do
        let(:current_question) { questions_section_one.first }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end

      context "and current question is first from second section" do
        let(:current_question) { questions_section_two.first }

        it 'returns true' do
          expect(subject.is_first_question).to eq(true)
        end
      end

      context "and current question is second from first section" do
        let(:current_question) { questions_section_one.second }

        it 'returns false' do
          expect(subject.is_first_question).to eq(false)
        end
      end
    end
  end

  describe '#is_last_question' do
    context "when attempt's context has no current section" do
      let(:current_section) { nil }

      context "and current question is last from first section" do
        let(:current_question) { questions_section_one.last }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end

      context "and current question is last from second section" do
        let(:current_question) { questions_section_two.last }

        it 'returns true' do
          expect(subject.is_last_question).to eq(true)
        end
      end

      context "and current question is first from last section" do
        let(:current_question) { questions_section_two.first }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end
    end

    context "when attempt's context has current section set to first one" do
      let(:current_section) { section_one }

      context "and current question is last from first section" do
        let(:current_question) { questions_section_one.last }

        it 'returns true' do
          expect(subject.is_last_question).to eq(true)
        end
      end

      context "and current question is last from last section" do
        let(:current_question) { questions_section_two.last }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end

      context "and current question is first from last section" do
        let(:current_question) { questions_section_two.first }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end
    end

    context "when attempt's context has current section set to second one" do
      let(:current_section) { section_two }

      context "and current question is last from first section" do
        let(:current_question) { questions_section_one.last }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end

      context "and current question is last from second section" do
        let(:current_question) { questions_section_two.last }

        it 'returns true' do
          expect(subject.is_last_question).to eq(true)
        end
      end

      context "and current question is first from last section" do
        let(:current_question) { questions_section_two.first }

        it 'returns false' do
          expect(subject.is_last_question).to eq(false)
        end
      end
    end
  end

  describe '#first_question' do
    context "when section's one position is 1" do
      it 'returns first question from section one' do
        expect(subject.first_question.id).to eq(section_one.questions.order(:position).first.id)
      end
    end

    context "when section's two position is 1" do
      before do
        section_one.update_attributes(position: 2)
        section_two.update_attributes(position: 1)
      end
      it 'returns first question from section one' do
        expect(subject.first_question.id).to eq(section_two.questions.order(:position).first.id)
      end
    end
  end
end
