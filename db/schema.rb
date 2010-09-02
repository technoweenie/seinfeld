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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20100827203011) do

  create_table "seinfeld_progressions", :force => true do |t|
    t.date    "created_at"
    t.integer "user_id"
  end

  add_index "seinfeld_progressions", ["user_id"], :name => "index_seinfeld_progressions_on_user_id"

  create_table "seinfeld_users", :force => true do |t|
    t.string  "login",                :limit => 50
    t.string  "email",                :limit => 50
    t.integer "current_streak",                     :default => 0
    t.integer "longest_streak",                     :default => 0
    t.date    "streak_start"
    t.date    "streak_end"
    t.date    "longest_streak_start"
    t.date    "longest_streak_end"
    t.string  "time_zone",            :limit => 50
    t.boolean "disabled",                           :default => false
    t.string  "etag"
    t.string  "location"
  end

  add_index "seinfeld_users", ["current_streak"], :name => "index_seinfeld_users_current_streak"
  add_index "seinfeld_users", ["disabled"], :name => "index_seinfeld_users_on_disabled"
  add_index "seinfeld_users", ["login"], :name => "index_seinfeld_users_on_login", :unique => true
  add_index "seinfeld_users", ["longest_streak"], :name => "index_seinfeld_users_longest_streak"

end
