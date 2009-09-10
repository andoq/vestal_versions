ActiveRecord::Base.establish_connection(
  :adapter => defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby' ? 'jdbcsqlite3' : 'mysql',
  :database => 'vestal_test',
  :username => 'root',
  :password => 'root'
)

class CreateSchema < ActiveRecord::Migration
  def self.up
    create_table :users, :force => true do |t|
      t.string :first_name
      t.string :last_name
      t.string :unversioned
      t.timestamps
    end

    create_table :projects, :force => true do |t|
      t.string :name
      t.string :unversioned
      t.datetime :due_date, :default => 1.day.ago
      t.timestamps
    end

    create_table :user_projects, :force => true do |t|
      t.references :user
      t.references :project
      t.timestamps
    end

    create_table :versions, :force => true do |t|
      t.belongs_to :versioned, :polymorphic => true
      t.text :changes
      t.integer :number
      t.datetime :created_at
    end
  end
end

CreateSchema.suppress_messages do
  CreateSchema.migrate(:up)
end

class UserProject < ActiveRecord::Base
  belongs_to :user
  belongs_to :project

  def alert
    raise 'UserProject'
  end
end


class User < ActiveRecord::Base
  versioned :except => :unversioned, :timestamps => true

  has_many_versioned :user_projects
  has_many :projects, :through => :user_projects

  def name
    [first_name, last_name].compact.join(' ')
  end

  def name=(names)
    self[:first_name], self[:last_name] = names.split(' ', 2)
  end
end

class Project < ActiveRecord::Base
  has_many :user_projects
  has_many_versioned :users, :through => :user_projects

  versioned :only => :name
end


