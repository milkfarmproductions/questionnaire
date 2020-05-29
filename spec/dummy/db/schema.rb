# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20200519215415) do

  create_table "lessons", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "survey_answers", force: :cascade do |t|
    t.integer "attempt_id"
    t.integer "question_id"
    t.integer "option_id"
    t.boolean "correct"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "option_text"
    t.integer "option_number"
    t.integer "predefined_value_id"
  end

  create_table "survey_attempts", force: :cascade do |t|
    t.string "participant_type"
    t.integer "participant_id"
    t.integer "survey_id"
    t.integer "score"
    t.integer "current_section_id"
    t.integer "current_question_id"
    t.string "status"
    t.index ["participant_type", "participant_id"], name: "index_survey_attempts_on_participant_type_and_participant_id"
  end

  create_table "survey_options", force: :cascade do |t|
    t.integer "question_id"
    t.integer "weight", default: 0
    t.string "text"
    t.boolean "correct"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale_text"
    t.integer "options_type_id"
    t.string "head_number"
    t.integer "next_question_id"
    t.integer "position"
  end

  create_table "survey_predefined_values", force: :cascade do |t|
    t.string "head_number"
    t.string "name"
    t.string "locale_name"
    t.integer "question_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "survey_questions", force: :cascade do |t|
    t.string "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "section_id"
    t.string "head_number"
    t.text "description"
    t.string "locale_text"
    t.string "locale_head_number"
    t.text "locale_description"
    t.integer "questions_type_id"
    t.boolean "mandatory", default: false
    t.string "icon_file_name"
    t.string "icon_content_type"
    t.integer "icon_file_size", default: 0
    t.datetime "icon_updated_at"
    t.integer "position"
    t.integer "skip_to_question_id"
  end

  create_table "survey_sections", force: :cascade do |t|
    t.string "head_number"
    t.string "name"
    t.text "description"
    t.integer "survey_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale_head_number"
    t.string "locale_name"
    t.text "locale_description"
    t.integer "position"
    t.string "identifier"
  end

  create_table "survey_surveys", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "attempts_number", default: 0
    t.boolean "finished", default: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "locale_name"
    t.text "locale_description"
    t.integer "lesson_id"
    t.string "identifier"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
