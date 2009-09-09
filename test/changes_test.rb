require 'test_helper'

class ChangesTest < Test::Unit::TestCase
  context "A version's changes" do
    setup do
      @user = User.create(:name => 'Steve Richert')
      @project = Project.create(:name => 'Makin things cool')
    end

    should "initially be blank" do
      assert @user.versions.first.changes.blank?
    end

    should 'contain all changed attributes' do
      @user.name = 'Steve Jobs'
      changes = @user.changes
      @user.save
      assert_equal changes, @user.versions.last.changes.slice(*changes.keys)
    end

    should 'contain timestamp changes when applicable' do
      timestamp = 'updated_at'
      @user.update_attribute(:name, 'Steve Jobs')
      assert @user.class.content_columns.map(&:name).include?(timestamp)
      assert_contains @user.versions.last.changes.keys, timestamp
    end

    should 'contain not conatin timestamp changes when applicable' do
      timestamp = 'updated_at'
      @project.update_attribute(:name, 'not cool')
      assert @project.class.content_columns.map(&:name).include?(timestamp)
      assert_does_not_contain @project.versions.last.changes.keys, timestamp
    end

    should 'contain no more than the changed attributes and not timestamps' do
      timestamps = %w(created_at created_on updated_at updated_on)
      @user.name = 'Steve Jobs'
      changes = @user.changes
      @user.save
      assert_equal changes, @user.versions.last.changes.except(*timestamps)
    end

    should 'not contain excluded columns' do
      @user.name = 'Steve Jobs'
      @user.unversioned = 'test'
      @user.save
      assert_equal false, @user.versions.last.changes.include?("unversioned")
    end
  end
end
