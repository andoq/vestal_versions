require 'test_helper'

class AssociationsTest < Test::Unit::TestCase
  context "A model with a has_many association" do
    setup do
      @user = User.create(:name => 'Steve Richert')
    end

    should 'add a version when an associations is added' do
      project = Project.create(:name => 'Versioned Associations')

      old_version_count = @user.versions.size
      @user.user_projects.create!(:project => project)
      @user.reload #needed for now, not sure how to get this object to reload it's versions after the after_save callback on the associated object
      assert_equal(old_version_count + 1, @user.versions.size)
    end

    should 'add a version when an associations is removed' do
      project = Project.create(:name => 'Versioned Associations')

      user_project = @user.user_projects.create!(:project => project)
      @user.reload
      old_version_count = @user.versions.size
      @user.user_projects.delete(user_project)
      @user.reload
      assert_equal(old_version_count + 1, @user.versions.size)
    end

    should 'add a version when an has_many_through association is added and the :through relationship is versioned' do
      old_version_count = @user.versions.size
      @user.projects.create!(:name => 'Versioned Associations')
      @user.reload
      assert_equal(old_version_count + 1, @user.versions.size)
    end
  end

  context "A model with a has_many :through association" do
    setup do
      @project = Project.create(:name => 'Vestal Versions')
      @user = User.create(:name => 'Steve Richert')
    end

    should 'add a version when an associations is added' do
      old_version_count = @project.versions.size
      @project.users << @user
      @project.reload
      assert_equal(old_version_count + 1, @user.versions.size)
    end

    should 'record the id of the object added' do
      old_version_count = @project.versions.size
      @project.users << @user
      @project.reload
      assert_equal(old_version_count + 1, @project.versions.size)
      assert_contains @project.versions.last.changes.keys, :association
      assert_equal(:add, @project.versions.last.changes[:association][:action])
      assert_equal(@user.id, @project.versions.last.changes[:association][:id])
    end

    should 'record the id of the object removed' do
      old_version_count = @project.versions.size
      @project.users.delete(@user)
      @project.reload
      assert_equal(old_version_count + 1, @project.versions.size)
      assert_contains @project.versions.last.changes.keys, :association
      assert_equal(:remove, @project.versions.last.changes[:association][:action])
      assert_equal(@user.id, @project.versions.last.changes[:association][:id])
    end

    should 'record the id of the object when added again' do
      old_version_count = @project.versions.size
      @project.users << (@user)
      @project.reload
      assert_equal(old_version_count + 1, @project.versions.size)
      assert_contains @project.versions.last.changes.keys, :association
      assert_equal(:add, @project.versions.last.changes[:association][:action])
      assert_equal(@user.id, @project.versions.last.changes[:association][:id])
    end
  end
end
