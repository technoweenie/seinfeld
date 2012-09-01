require 'rubygems'
require 'rake'
require 'rake/testtask'

task :test => 'seinfeld:init' do
  Rake::Task['db:schema:dump'].invoke
  Seinfeld.configure('test')
  Rake::Task['db:schema:load'].invoke
end

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

desc 'Default: run tests.'
task :default => 'test'

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/seinfeld/console.rb"
end

namespace :seinfeld do
  task :init do
    require File.join(File.dirname(__FILE__), 'lib', 'seinfeld.rb')
    Seinfeld.configure
  end

  desc "Start CalendarAboutNothing for development"
  task :start do
    system "shotgun config.ru"
  end

  desc "Inspect USER."
  task :show => :init do
    raise "Need USER=" if ENV['USER'].blank?
    u = Seinfeld::User.find_by_login(ENV['USER'])
    puts "#{u.login}#{' (disabled)' if u.disabled?}#{" #{u.time_zone}" if u.time_zone}"
    puts "Current Streak: #{u.current_streak} #{u.streak_start} => #{u.streak_end}"
    puts "Longest Streak: #{u.longest_streak} #{u.longest_streak_start} => #{u.longest_streak_end}"
  end

  desc "Inspect USER progressions."
  task :progressions => :init do
    raise "Need USER=" if ENV['USER'].blank?
    u = Seinfeld::User.find_by_login(ENV['USER'])
    progs = u.progressions.to_a
    puts "#{progs.size} days for #{u.login}"
    progs.each do |prog|
      puts prog.inspect
    end
  end

  desc "Scan USER feeds."
  task :scan => :init do
    raise "Need USER=" if ENV['USER'].blank?
    ENV['FEED_PAGE'] ||= '1'
    user = Seinfeld::User.find_by_login(ENV['USER'])
    Time.zone = user.time_zone || 'UTC'
    feed = Seinfeld::Feed.fetch(user.login, ENV['FEED_PAGE'])
    feed.items.each do |item|
      begin
        puts "#{item['type']} - #{item['created_at']} - #{Seinfeld::Feed.committed?(item).inspect}"
      rescue
        puts $!
        puts item.inspect
        $!.backtrace.each { |b| puts " > #{b}" }
      end
    end
  end

  desc "Fix USER progress."
  task :fix_progress => :init do
    raise "Need USER=" if ENV['USER'].blank?
    user = Seinfeld::User.find_by_login(ENV['USER'])
    Time.zone = user.time_zone || 'UTC'
    user.fix_progress
    user.save!
    puts "#{user.login}#{' (disabled)' if user.disabled?}#{" #{user.time_zone}" if user.time_zone}"
    puts "Current Streak: #{user.current_streak} #{user.streak_start} => #{user.streak_end}"
    puts "Longest Streak: #{user.longest_streak} #{user.longest_streak_start} => #{user.longest_streak_end}"
  end

  desc "Sets USER's timezone to ZONE."
  task :tz => :init do
    raise "Need USER=" if ENV['USER'].to_s.size.zero?
    raise "Need ZONE=" if ENV['ZONE'].to_s.size.zero?
    if ActiveSupport::TimeZone::MAPPING.key?(ENV['ZONE'])
      u = Seinfeld::User.find_by_login(ENV['USER'])
      u.update_attribute :time_zone, ENV['ZONE']
    end
  end

  desc "Add a USER to the database."
  task :add => :init do
    raise "Need USER=" if ENV['USER'].to_s.size.zero?
    Seinfeld::User.create!(:login => ENV['USER'])
  end

  desc "Remove a USER from the database."
  task :drop => :init do
    raise "Need USER=" if ENV['USER'].to_s.size.zero?
    if user = Seinfeld::User.find_by_login(ENV['USER'])
      user.destroy
    end
  end

  desc "Counts active and disabled users"
  task :count => :init do
    active = Seinfeld::User.active.count
    disabled = Seinfeld::User.count - active
    puts "#{active} active users, #{disabled} disabled users"
  end

  desc "Re-enables a USER."
  task :activate => :init do
    login = ENV['user'].to_s
    if login.size.zero?
      Seinfeld::User.activate_all
    else
      Seinfeld::User.activate_user(login)
    end
  end

  desc "Update the calendar of USER"
  task :update => :init do
    ENV['FEED_PAGE'] ||= '1'
    update_user = lambda do |user|
      header = "#{user.login}#{' (disabled)' if user.disabled?} - "
      begin
        feed = Seinfeld::Updater.run(user, nil, ENV['FEED_PAGE'])
        puts header << feed.inspect
      rescue
        puts header << "#{$!.class}: #{$!.inspect}"
        $!.backtrace { |b| puts " >> #{b}" }
      end
    end

    if ENV['USER'].blank?
      Seinfeld::User.active.paginated_each do |user|
        update_user.call(user)
      end
    else
      if user = Seinfeld::User.find_by_login(ENV['USER'])
        update_user.call(user)
      else
        raise "No user found for #{ENV['USER'].inspect}"
      end
    end
  end

  desc "Clear progress of all users"
  task :clear_all => :init do
    Seinfeld::User.paginated_each { |u| u.clear_progress }
  end

  desc "Clear progress of USER."
  task :clear => :init do
    raise "Need USER=" if ENV['USER'].blank?
    Seinfeld::User.find_by_login(ENV['USER']).clear_progress
  end
end

desc "cron task for keeping the CAN updated.  Run once every hour."
task :cron => 'seinfeld:init' do
  count, errored, items, committed = 0, 0, 0, 0
  Seinfeld::User.active.paginated_each do |user|
    begin
      if feed = Seinfeld::Updater.run(user)
        if feed.items.size.zero?
          errored += 1
        else
          count     += 1
          items     += feed.items.size
          committed += feed.committed_days.size
        end
      end
    rescue
      errored += 1
      puts "#{user.login}: [#{$!.class}] #{$!.inspect}"
    end
  end
  puts "#{count} user(s), #{errored} bad/empty feed(s), #{items} event(s), #{committed} committed day(s)!"
end

namespace :db do
  desc "Creates a migration file in db/migrate.  Specify migration name with M=x"
  task :create_migration => 'seinfeld:init' do
    tmpl = <<-END
class <%= class_name %> < ActiveRecord::Migration
  def self.up
  end

  def self.down
  end
end
END
    migration_name = ENV['M'].to_s.underscore
    File.open "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_#{migration_name}.rb", 'w' do |f|
      class_name = migration_name.classify
      f << ERB.new(tmpl).result(binding)
    end
  end

  desc "Migrate the database through scripts in db/migrate and update db/schema.rb by invoking db:schema:dump. Target specific version with VERSION=x. Turn off output with VERBOSE=false."
  task :migrate => 'seinfeld:init' do
    ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
    ActiveRecord::Migrator.migrate("db/migrate/", ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    Rake::Task["db:schema:dump"].invoke
  end

  namespace :migrate do
    desc  'Rollbacks the database one migration and re migrate up. If you want to rollback more than one step, define STEP=x. Target specific version with VERSION=x.'
    task :redo => 'seinfeld:init' do
      if ENV["VERSION"]
        Rake::Task["db:migrate:down"].invoke
        Rake::Task["db:migrate:up"].invoke
      else
        Rake::Task["db:rollback"].invoke
        Rake::Task["db:migrate"].invoke
      end
    end

    desc 'Runs the "up" for a given migration VERSION.'
    task :up => 'seinfeld:init' do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      ActiveRecord::Migrator.run(:up, "db/migrate/", version)
      Rake::Task["db:schema:dump"].invoke
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task :down => 'seinfeld:init' do
      version = ENV["VERSION"] ? ENV["VERSION"].to_i : nil
      raise "VERSION is required" unless version
      ActiveRecord::Migrator.run(:down, "db/migrate/", version)
      Rake::Task["db:schema:dump"].invoke
    end
  end

  namespace :schema do
    desc "Create a db/schema.rb file that can be portably used against any DB supported by AR"
    task :dump => 'seinfeld:init' do
      require 'active_record/schema_dumper'
      File.open(ENV['SCHEMA'] || "#{Seinfeld.root}/db/schema.rb", "w") do |file|
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
      end
      Rake::Task["db:schema:dump"].reenable
    end

    desc "Load a schema.rb file into the database"
    task :load => 'seinfeld:init' do
      file = ENV['SCHEMA'] || "#{Seinfeld.root}/db/schema.rb"
      if File.exists?(file)
        load(file)
      else
        abort %{#{file} doesn't exist yet. Run "rake db:migrate" to create it then try again. If you do not intend to use a database, you should instead alter #{Rails.root}/config/boot.rb to limit the frameworks that will be loaded}
      end
    end
  end
end
