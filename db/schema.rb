# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20160329163619) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "tab_usages", force: true do |t|
    t.integer  "vault"
    t.integer  "resources"
    t.integer  "onboarding_tasks"
    t.integer  "medical_credentialing"
    t.integer  "loan_origination"
    t.integer  "upload_sign"
    t.integer  "tax_return"
    t.integer  "submit_claim"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "userconfigs", force: true do |t|
    t.text     "username"
    t.datetime "date"
    t.text     "company"
    t.text     "logo_url"
    t.text     "home_url"
    t.boolean  "vault"
    t.boolean  "resources"
    t.boolean  "onboarding_tasks"
    t.boolean  "medical_credentialing"
    t.boolean  "loan_origination"
    t.boolean  "upload_sign"
    t.boolean  "tax_return"
    t.boolean  "submit_claim"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "okta"
    t.boolean  "eventstream"
    t.boolean  "media_content"
  end

end
