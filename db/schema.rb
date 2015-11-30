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

ActiveRecord::Schema.define(version: 20151130203921) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"
  enable_extension "pg_stat_statements"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string   "namespace",     limit: 255
    t.text     "body"
    t.string   "resource_id",   limit: 255, null: false
    t.string   "resource_type", limit: 255, null: false
    t.integer  "author_id"
    t.string   "author_type",   limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id", using: :btree

  create_table "audio_files", force: :cascade do |t|
    t.integer  "item_id",                                   null: false
    t.string   "file",              limit: 255
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.string   "original_file_url", limit: 255
    t.string   "identifier",        limit: 255
    t.integer  "instance_id"
    t.text     "transcript"
    t.string   "format",            limit: 255
    t.integer  "size",              limit: 8
    t.integer  "storage_id"
    t.string   "path",              limit: 255
    t.integer  "duration"
    t.datetime "transcoded_at"
    t.boolean  "metered"
    t.integer  "user_id"
    t.integer  "listens",                       default: 0, null: false
    t.datetime "deleted_at"
    t.string   "status_code",       limit: 1
  end

  add_index "audio_files", ["item_id", "deleted_at"], name: "index_audio_files_on_item_id_and_deleted_at", using: :btree
  add_index "audio_files", ["item_id"], name: "index_audio_files_on_item_id", using: :btree

  create_table "charges", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "ref_id"
    t.string   "ref_type"
    t.decimal  "amount"
    t.datetime "transaction_at"
    t.hstore   "extras"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "charges", ["ref_id"], name: "index_charges_on_ref_id", using: :btree

  create_table "collection_grants", force: :cascade do |t|
    t.integer  "collection_id"
    t.integer  "collector_id"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.boolean  "uploads_collection",             default: false
    t.string   "collector_type",     limit: 255
    t.datetime "deleted_at"
  end

  add_index "collection_grants", ["collection_id", "collector_id", "collector_type"], name: "index_collection_grant_collector_type_collection", unique: true, using: :btree
  add_index "collection_grants", ["collection_id"], name: "index_collection_grants_on_collection_id", using: :btree
  add_index "collection_grants", ["collector_id"], name: "index_collection_grants_on_user_id", using: :btree

  create_table "collections", force: :cascade do |t|
    t.string   "title",                    limit: 255
    t.text     "description"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.boolean  "items_visible_by_default",             default: false
    t.boolean  "copy_media"
    t.integer  "default_storage_id"
    t.integer  "upload_storage_id"
    t.datetime "deleted_at"
    t.integer  "creator_id"
    t.string   "token",                    limit: 255
    t.hstore   "extra",                                default: {}
  end

  create_table "contributions", force: :cascade do |t|
    t.integer  "person_id"
    t.integer  "item_id"
    t.string   "role",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "contributions", ["item_id"], name: "index_contributions_on_item_id", using: :btree
  add_index "contributions", ["person_id"], name: "index_contributions_on_person_id", using: :btree
  add_index "contributions", ["role", "item_id"], name: "index_contributions_on_role_and_item_id", using: :btree

  create_table "csv_imports", force: :cascade do |t|
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.string   "file",          limit: 255
    t.integer  "state_index",               default: 0
    t.string   "headers",                                            array: true
    t.string   "file_name",     limit: 255
    t.integer  "collection_id",             default: 0
    t.string   "error_message", limit: 255
    t.text     "backtrace"
    t.integer  "user_id"
  end

  add_index "csv_imports", ["user_id"], name: "index_csv_imports_on_user_id", using: :btree

  create_table "csv_rows", force: :cascade do |t|
    t.text     "values",                     array: true
    t.integer  "csv_import_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "csv_rows", ["csv_import_id"], name: "index_csv_rows_on_csv_import_id", using: :btree

  create_table "entities", force: :cascade do |t|
    t.boolean  "is_confirmed"
    t.string   "identifier",   limit: 255
    t.string   "name",         limit: 255
    t.float    "score"
    t.string   "category",     limit: 255
    t.string   "entity_type",  limit: 255
    t.integer  "item_id"
    t.text     "extra"
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "entities", ["is_confirmed", "item_id", "score"], name: "index_entities_on_is_confirmed_and_item_id_and_score", using: :btree
  add_index "entities", ["item_id"], name: "index_entities_on_item_id", using: :btree

  create_table "geolocations", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "slug",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.decimal  "latitude"
    t.decimal  "longitude"
  end

  create_table "image_files", force: :cascade do |t|
    t.integer  "item_id"
    t.string   "file",              limit: 255
    t.boolean  "is_uploaded"
    t.string   "upload_id",         limit: 255
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "original_file_url", limit: 255
    t.string   "storage_id",        limit: 255
    t.integer  "imageable_id"
    t.string   "imageable_type",    limit: 255
  end

  add_index "image_files", ["imageable_id"], name: "index_image_files_on_imageable_id", using: :btree
  add_index "image_files", ["imageable_type"], name: "index_image_files_on_imageable_type", using: :btree

  create_table "import_mappings", force: :cascade do |t|
    t.string   "data_type",     limit: 255
    t.string   "column",        limit: 255
    t.integer  "csv_import_id"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "position"
  end

  add_index "import_mappings", ["csv_import_id"], name: "index_import_mappings_on_csv_import_id", using: :btree

  create_table "instances", force: :cascade do |t|
    t.string   "identifier", limit: 255
    t.boolean  "digital"
    t.string   "location",   limit: 255
    t.string   "format",     limit: 255
    t.integer  "item_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "items", force: :cascade do |t|
    t.text     "title"
    t.text     "episode_title"
    t.text     "series_title"
    t.text     "description"
    t.text     "identifier"
    t.date     "date_broadcast"
    t.date     "date_created"
    t.text     "rights"
    t.text     "physical_format"
    t.text     "digital_format"
    t.text     "physical_location"
    t.text     "digital_location"
    t.integer  "duration"
    t.text     "music_sound_used"
    t.text     "date_peg"
    t.text     "notes"
    t.text     "transcription"
    t.string   "tags",                                                         array: true
    t.integer  "geolocation_id"
    t.hstore   "extra",                         default: {}
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "csv_import_id"
    t.integer  "collection_id",                                   null: false
    t.string   "token",             limit: 255
    t.integer  "storage_id"
    t.boolean  "is_public"
    t.string   "language",          limit: 255
    t.datetime "deleted_at"
    t.string   "image",             limit: 255
    t.string   "transcript_type",   limit: 255, default: "basic", null: false
  end

  add_index "items", ["collection_id"], name: "index_items_on_collection_id", using: :btree
  add_index "items", ["csv_import_id"], name: "index_items_on_csv_import_id", using: :btree
  add_index "items", ["deleted_at"], name: "index_items_on_deleted_at", using: :btree
  add_index "items", ["geolocation_id"], name: "index_items_on_geolocation_id", using: :btree

  create_table "monthly_usages", force: :cascade do |t|
    t.integer  "entity_id"
    t.string   "entity_type", limit: 255
    t.string   "use",         limit: 255
    t.integer  "month"
    t.integer  "year"
    t.decimal  "value"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "yearmonth",   limit: 255
    t.decimal  "cost"
    t.decimal  "retail_cost"
  end

  add_index "monthly_usages", ["entity_id", "entity_type", "use", "month", "year"], name: "index_entity_use_date", unique: true, using: :btree
  add_index "monthly_usages", ["entity_id", "entity_type", "use"], name: "index_monthly_usages_on_entity_id_and_entity_type_and_use", using: :btree
  add_index "monthly_usages", ["entity_id", "entity_type"], name: "index_monthly_usages_on_entity_id_and_entity_type", using: :btree
  add_index "monthly_usages", ["yearmonth"], name: "index_monthly_usages_on_yearmonth", using: :btree

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer  "resource_owner_id",             null: false
    t.integer  "application_id",                null: false
    t.string   "token",             limit: 255, null: false
    t.integer  "expires_in",                    null: false
    t.string   "redirect_uri",      limit: 255, null: false
    t.datetime "created_at",                    null: false
    t.datetime "revoked_at"
    t.string   "scopes",            limit: 255
  end

  add_index "oauth_access_grants", ["token"], name: "index_oauth_access_grants_on_token", unique: true, using: :btree

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer  "resource_owner_id"
    t.integer  "application_id",                null: false
    t.string   "token",             limit: 255, null: false
    t.string   "refresh_token",     limit: 255
    t.integer  "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at",                    null: false
    t.string   "scopes",            limit: 255
  end

  add_index "oauth_access_tokens", ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true, using: :btree
  add_index "oauth_access_tokens", ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id", using: :btree
  add_index "oauth_access_tokens", ["token"], name: "index_oauth_access_tokens_on_token", unique: true, using: :btree

  create_table "oauth_applications", force: :cascade do |t|
    t.string   "name",         limit: 255, null: false
    t.string   "uid",          limit: 255, null: false
    t.string   "secret",       limit: 255, null: false
    t.string   "redirect_uri", limit: 255, null: false
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
    t.integer  "owner_id"
    t.string   "owner_type",   limit: 255
  end

  add_index "oauth_applications", ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type", using: :btree
  add_index "oauth_applications", ["uid"], name: "index_oauth_applications_on_uid", unique: true, using: :btree

  create_table "organizations", force: :cascade do |t|
    t.string   "name",                         limit: 255
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.string   "amara_key",                    limit: 255
    t.string   "amara_username",               limit: 255
    t.string   "amara_team",                   limit: 255
    t.integer  "owner_id"
    t.integer  "used_unmetered_storage_cache"
    t.integer  "used_metered_storage_cache"
    t.hstore   "transcript_usage_cache",                   default: {}
  end

  create_table "organizations_roles", id: false, force: :cascade do |t|
    t.integer  "organization_id"
    t.integer  "role_id"
    t.datetime "deleted_at"
  end

  add_index "organizations_roles", ["organization_id", "role_id"], name: "index_organizations_roles_on_organization_id_and_role_id", using: :btree

  create_table "people", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "slug",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "roles", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.integer  "resource_id"
    t.string   "resource_type", limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.datetime "deleted_at"
  end

  add_index "roles", ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id", using: :btree
  add_index "roles", ["name"], name: "index_roles_on_name", using: :btree

  create_table "speakers", force: :cascade do |t|
    t.integer  "transcript_id"
    t.string   "name",          limit: 255
    t.text     "times"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "speakers", ["transcript_id"], name: "index_speakers_on_transcript_id", using: :btree

  create_table "storage_configurations", force: :cascade do |t|
    t.string   "provider",   limit: 255
    t.string   "key",        limit: 255
    t.string   "secret",     limit: 255
    t.string   "bucket",     limit: 255
    t.string   "region",     limit: 255
    t.boolean  "is_public"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "subscription_plans", force: :cascade do |t|
    t.integer  "pop_up_hours"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "stripe_plan_id", limit: 255
    t.string   "name",           limit: 255
    t.string   "amount",         limit: 255
    t.string   "hours",          limit: 255
    t.string   "interval",       limit: 255
  end

  create_table "tasks", force: :cascade do |t|
    t.integer  "owner_id",                            null: false
    t.string   "owner_type", limit: 255
    t.text     "identifier"
    t.string   "name",       limit: 255
    t.string   "status",     limit: 255
    t.hstore   "extras",                 default: {}
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "type",       limit: 255
    t.integer  "storage_id"
  end

  add_index "tasks", ["created_at"], name: "index_tasks_on_created_at", using: :btree
  add_index "tasks", ["identifier"], name: "index_tasks_on_identifier", using: :btree
  add_index "tasks", ["owner_id", "owner_type"], name: "index_tasks_on_owner_id_and_owner_type", using: :btree
  add_index "tasks", ["status"], name: "index_tasks_on_status", using: :btree
  add_index "tasks", ["type"], name: "index_tasks_on_type", using: :btree

  create_table "timed_texts", force: :cascade do |t|
    t.integer  "transcript_id"
    t.decimal  "start_time"
    t.decimal  "end_time"
    t.text     "text"
    t.decimal  "confidence"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "speaker_id"
  end

  add_index "timed_texts", ["speaker_id"], name: "index_timed_texts_on_speaker_id", using: :btree
  add_index "timed_texts", ["start_time", "transcript_id"], name: "index_timed_texts_on_start_time_and_transcript_id", using: :btree
  add_index "timed_texts", ["transcript_id"], name: "index_timed_texts_on_transcript_id", using: :btree

  create_table "transcribers", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.string   "url",                 limit: 255
    t.integer  "cost_per_min"
    t.text     "description"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.integer  "retail_cost_per_min",             default: 0, null: false
  end

  create_table "transcripts", force: :cascade do |t|
    t.integer  "audio_file_id",                                   null: false
    t.string   "identifier",           limit: 255
    t.string   "language",             limit: 255
    t.integer  "start_time"
    t.integer  "end_time"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.decimal  "confidence"
    t.integer  "transcriber_id"
    t.integer  "cost_per_min"
    t.integer  "cost_type",                        default: 1,    null: false
    t.integer  "retail_cost_per_min",              default: 0,    null: false
    t.boolean  "is_billable",                      default: true, null: false
    t.integer  "subscription_plan_id"
  end

  add_index "transcripts", ["audio_file_id", "identifier"], name: "index_transcripts_on_audio_file_id_and_identifier", using: :btree
  add_index "transcripts", ["transcriber_id"], name: "index_transcripts_on_transcriber_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                         limit: 255, default: "", null: false
    t.string   "encrypted_password",            limit: 255, default: ""
    t.string   "reset_password_token",          limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                             default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",            limit: 255
    t.string   "last_sign_in_ip",               limit: 255
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.string   "provider",                      limit: 255
    t.string   "uid",                           limit: 255
    t.string   "name",                          limit: 255
    t.integer  "default_public_collection_id"
    t.integer  "default_private_collection_id"
    t.string   "invitation_token",              limit: 60
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer  "invitation_limit"
    t.integer  "invited_by_id"
    t.string   "invited_by_type",               limit: 255
    t.integer  "organization_id"
    t.string   "customer_id",                   limit: 255
    t.integer  "pop_up_hours_cache"
    t.integer  "used_metered_storage_cache"
    t.integer  "subscription_plan_id"
    t.hstore   "transcript_usage_cache",                    default: {}
    t.integer  "used_unmetered_storage_cache"
    t.integer  "subscription_start_day"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["invitation_token"], name: "index_users_on_invitation_token", unique: true, using: :btree
  add_index "users", ["invited_by_id"], name: "index_users_on_invited_by_id", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

  create_table "users_roles", id: false, force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "role_id"
    t.datetime "deleted_at"
  end

  add_index "users_roles", ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", using: :btree

end
