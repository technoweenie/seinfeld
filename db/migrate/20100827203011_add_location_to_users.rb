class AddLocationToUsers < ActiveRecord::Migration
  def self.up
    add_column :seinfeld_users, :location, :string
  end

  def self.down
    remove_column :seinfeld_users, :location
  end
end
