require 'version'

module LaserLemon
  module VestalVersions
    def self.included(base)
      base.extend ClassMethods

      class << base
        attr_accessor :versioned_columns
      end
    end

    module ClassMethods

      def has_many_versioned(association_id, options = {}, &extension)

        
        options[:after_remove] ||= []
        options[:after_remove] << :remove_association
        has_many association_id, options, &extension

        #We can't use the after_add callback of the association, because the object may not be saved, and then we don't have an ID to record.
        #So we need to put the recording of the change on the associated model's after_save callback.
        #TODO: figure out how to get the change into the calling objects's changes

        versioned_class = self

        #find the klass object to add the after_save callback (this is the join model for a has_many :through relationship
        if options[:through]
          callback_klass = self.reflections[association_id].through_reflection.klass
          primary_key_name = self.reflections[association_id].source_reflection.primary_key_name
          object_type = self.reflections[association_id].source_reflection.class_name
        else
          callback_klass = self.reflections[association_id].klass
          primary_key_name = self.reflections[association_id].klass.primary_key
          object_type = self.reflections[association_id].klass.class_name
        end


        callback_klass.send(:define_method, "vestal_version_#{self.reflections[association_id].name}_after_save_callback", Proc.new {
            self.send((versioned_class.name.downcase).to_sym).send(:add_association, object_type, self.send(primary_key_name.to_sym))
            self.send((versioned_class.name.downcase).to_sym).send(:save)
          })
        callback_klass.send(:after_save, "vestal_version_#{self.reflections[association_id].name}_after_save_callback".to_sym)

      end

      def versioned options = {}
        set_revisable_columns(options)

        has_many :versions, :as => :versioned, :order => 'versions.number ASC', :dependent => :delete_all do
          def between(from_value, to_value)
            from, to = number_at(from_value), number_at(to_value)
            return [] if from.nil? || to.nil?
            condition = (from == to) ? to : Range.new(*[from, to].sort)
            all(
              :conditions => {:number => condition},
              :order => "versions.number #{(from > to) ? 'DESC' : 'ASC'}"
            )
          end

          def at(value)
            case value
              when Version then value
              when Numeric then find_by_number(value.floor)
              when Symbol then respond_to?(value) ? send(value) : nil
              when Date, Time then last(:conditions => ['versions.created_at <= ?', value.to_time])
            end
          end

          def number_at(value)
            case value
              when Version then value.number
              when Numeric then value.floor
              when Symbol, Date, Time then at(value).try(:number)
            end
          end
        end

        after_create :create_initial_version
        after_update :create_initial_version, :if => :needs_initial_version?
        after_update :create_version, :if => :needs_version?

        include InstanceMethods
        alias_method_chain :reload, :versions
      end
      
      private

      # Returns an Array of the columns that are watched for changes.
      def set_revisable_columns(options)
        return unless self.versioned_columns.blank?
        return self.versioned_columns = [] if options[:except] == :all
        return self.versioned_columns = [options[:only]].flatten.map(&:to_s).map(&:downcase) unless options[:only].blank?

        except = [options[:except]].flatten || []
        #don't version some columns by default
        except += %w(created_at created_on updated_at updated_on) unless options[:timestamps]
        self.versioned_columns ||= (column_names - except.map(&:to_s)).flatten.map(&:downcase)
      end
    end

    module InstanceMethods
      private
        def needs_initial_version?
          versions.empty?
        end

        def needs_version?
          !versioned_changes.empty?
        end

        def reset_version(new_version = nil)
          @last_version = nil if new_version.nil?
          @version = new_version
        end

        def create_initial_version
          versions.create(:changes => nil, :number => 1)
        end

        def create_version
          versions.create(:changes => versioned_changes, :number => (last_version + 1))
          reset_version
        end

        def add_association(object_type, id)
          association_changes.merge!(:association => {:action => :add, :name => object_type, :id => id})
        end

        def remove_association(association_object)
          association_changes.merge!(:association => {:action => :remove, :name => association_object.class.name, :id => association_object.id})
          save #save here so that the version is recorded.  This keeps it consistent w/ adding a association.  If this is ever fixed on add, remove this save call
        end

      public
        def version
          @version ||= last_version
        end

        def last_version
          @last_version ||= versions.maximum(:number)
        end

        def association_changes
          @association_changes ||= {}
        end

        def versioned_changes
          versioned_changes = changes
          versioned_changes.delete_if {|column_name, values| !self.class.versioned_columns.member?(column_name)}
          versioned_changes.merge!(association_changes)
        end

        def reverted?
          version != last_version
        end

        def reload_with_versions(*args)
          reset_version
          reload_without_versions(*args)
        end

        def revert_to(value)
          to_value = versions.number_at(value)
          return version if to_value == version
          chain = versions.between(version, to_value)
          return version if chain.empty?

          new_version = chain.last.number
          backward = chain.first > chain.last
          backward ? chain.pop : chain.shift

          unrevertable_changes = %w(created_at created_on updated_at updated_on association)

          chain.each do |version|
            version.changes.except(*unrevertable_changes).each do |attribute, change|
              new_value = backward ? change.first : change.last
              write_attribute(attribute, new_value)
            end
          end

          reset_version(new_version)
        end

        def revert_to!(value)
          revert_to(value)
          reset_version if saved = save
          saved
        end

        def latest_changes
          return {} if version.nil? || version == 1
          versions.at(version).changes
        end
    end
  end
end

ActiveRecord::Base.send(:include, LaserLemon::VestalVersions)
