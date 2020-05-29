# frozen_string_literal: true

ActiveAdmin.register Survey::Survey do
  menu label: I18n.t('surveys')

  filter  :name,
          as: :select,
          collection: proc {
            Survey::Survey.select('distinct(name)').collect do |c|
              [c.name, c.name]
            end
          }
  filter :active,
         as: :select,
         collection: %w[true false]

  filter :created_at

  index do
    column :name
    column :description
    column :active
    column :attempts_number
    column :finished
    column :created_at
    actions
  end

  form do |f|
    f.inputs I18n.t('survey_details') do
      f.input  :name
      f.input  :identifier
      f.input  :locale_name
      f.input  :description
      f.input  :locale_description
      f.input  :active, as: :select, collection: %w[true false]
      f.input  :attempts_number
    end

    f.inputs I18n.t('sections') do
      f.has_many :sections do |s|
        s.input :head_number
        s.input :locale_head_number
        s.input :name
        s.input :locale_name
        s.input :description
        s.input :locale_description
        s.input :identifier
        s.input :position

        s.has_many :questions do |q|
          q.input :head_number
          q.input :locale_head_number
          q.input :text
          q.input :locale_text
          q.input :icon, as: :file
          q.input :description
          q.input :locale_description
          q.input :questions_type_id, as: :select, collection: Survey::QuestionsType.questions_types_title
          q.input :mandatory
          q.input :skip_to_question_id, as: :select, collection: f.object.questions_as_collection unless f.object.new_record?
          q.input :position

          q.inputs I18n.t('predefined_values') do
            q.has_many :predefined_values do |p|
              p.input :head_number
              p.input :name
              p.input :locale_name
            end
          end

          q.has_many :options do |a|
            a.input :head_number
            a.input :text
            a.input :locale_text
            a.input :options_type_id, as: :select, collection: Survey::OptionsType.options_types_title
            a.input :next_question_id, as: :select, collection: f.object.questions_as_collection unless f.object.new_record?
            a.input :position
            a.input :correct
          end
        end
      end
    end

    f.actions
  end

  if Rails::VERSION::MAJOR >= 4
    controller do
      def permitted_params
        params.permit!
      end
    end
  end
end
