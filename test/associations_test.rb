require 'test_helper'

class AssociationsTest < Test::Unit::TestCase
  context "A model's change" do
    setup do
      @user = User.create(:name => 'Steve Richert')
    end

    should 'add a version when an has_many associations is added' do
      project = Project.create(:name => 'Versioned Associations')

      old_version_count = @user.versions.size
      @user.user_projects.create!(:project => project)
      @user.reload #needed for now, not sure how to get this object to reload it's versions after the after_save callback on the associated object
      assert_equal(old_version_count + 1, @user.versions.size)
    end

    should 'add a version when an has_many_through association is added and the :through relationsship is versioned' do
      old_version_count = @user.versions.size
      @user.projects.create!(:name => 'Versioned Associations')
      @user.reload #needed for now, not sure how to get this object to reload it's versions after the after_save callback on the associated object
      assert_equal(old_version_count + 1, @user.versions.size)
    end

    should 'record the id of the object added in an association' do
      old_version_count = @user.versions.size
      @user.projects.create!(:name => 'Versioned Associations')
      @user.reload #needed for now, not sure how to get this object to reload it's versions after the after_save callback on the associated object
      assert_equal(old_version_count + 1, @user.versions.size)
    end

  end
end
