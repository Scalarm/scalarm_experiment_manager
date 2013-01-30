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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120928104511) do

  create_table "experiment_instance_dbs", :force => true do |t|
    t.string   "ip"
    t.integer  "port"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "experiment_partitions", :force => true do |t|
    t.integer  "experiment_id"
    t.integer  "experiment_instance_db_id"
    t.integer  "start_id"
    t.integer  "end_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  create_table "experiment_progress_bars", :force => true do |t|
    t.integer  "experiment_id"
    t.integer  "experiment_instance_db_id"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "experiment_progress_bars", ["experiment_id"], :name => "index_experiment_progress_bars_on_experiment_id"
  add_index "experiment_progress_bars", ["experiment_instance_db_id"], :name => "index_experiment_progress_bars_on_experiment_instance_db_id"

  create_table "experiment_queues", :force => true do |t|
    t.integer  "experiment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "experiments", :force => true do |t|
    t.boolean  "is_running"
    t.datetime "start_at"
    t.datetime "end_at"
    t.text     "arguments"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "simulation_id"
    t.integer  "instance_index"
    t.integer  "run_counter"
    t.integer  "experiment_size"
    t.integer  "vm_counter",              :default => 0
    t.integer  "time_constraint_in_sec"
    t.integer  "time_constraint_in_iter"
    t.string   "scheduling_policy",       :default => "monte_carlo"
    t.string   "experiment_name"
    t.string   "experiment_file"
    t.integer  "user_id"
    t.text     "parametrization"
    t.text     "parameters"
    t.text     "doe_groups"
  end

  create_table "grid_credentials", :force => true do |t|
    t.string   "login"
    t.string   "password"
    t.string   "host"
    t.integer  "user_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "grid_credentials", ["user_id"], :name => "index_grid_credentials_on_user_id"

  create_table "grid_jobs", :force => true do |t|
    t.integer  "time_limit"
    t.integer  "simulation_limit"
    t.integer  "user_id"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.string   "grid_id"
  end

  add_index "grid_jobs", ["user_id"], :name => "index_grid_jobs_on_user_id"

  create_table "manager_failure_infos", :force => true do |t|
    t.text     "info"
    t.date     "when"
    t.integer  "manager_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "manager_infos", :force => true do |t|
    t.string   "address"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "physical_machines", :force => true do |t|
    t.string   "ip"
    t.string   "username"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cpus",       :default => 0
    t.string   "cpu_model",  :default => ""
    t.string   "cpu_freq",   :default => ""
    t.float    "memory",     :default => 0.0
  end

  create_table "simulation_manager_hosts", :force => true do |t|
    t.string   "ip"
    t.string   "port",       :default => "11200"
    t.string   "state",      :default => "not_running"
    t.datetime "created_at",                            :null => false
    t.datetime "updated_at",                            :null => false
  end

  create_table "simulations", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "scenario_file"
    t.string   "other_file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "storage_managers", :force => true do |t|
    t.string   "address"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "users", :force => true do |t|
    t.string   "username"
    t.string   "password_salt"
    t.string   "password_hash"
    t.datetime "created_at",    :null => false
    t.datetime "updated_at",    :null => false
    t.integer  "experiment_id"
  end

  create_table "virtual_machines", :force => true do |t|
    t.string   "ip"
    t.string   "username"
    t.string   "state"
    t.integer  "physical_machine_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "cpus",                :default => 0
    t.float    "memory",              :default => 0.0
  end

end
