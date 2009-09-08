require 'version'

module LaserLemon
  module VestalVersions
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def has_many_versioned(association_id, options = {}, &extension)

        if options[:through]
          raise 'Versioning through relation ships is not supported.  Version the original relationship instead.'
        end
        has_many association_id, options, &extension

        versioned_class = self

        self.reflections[association_id].klass.send(:define_method, "vestal_version_#{self.reflections[association_id].name}_after_save_callback", Proc.new {
            self.send((versioned_class.name.downcase).to_sym).send(:add_association, self)
            self.send((versioned_class.name.downcase).to_sym).send(:save)
          })
        self.reflections[association_id].klass.send(:after_save, "vestal_version_#{self.reflections[association_id].name}_after_save_callback".to_sym)

      end

      def versioned
        has_many :versions, :as => :versioned, :order => 'versions.number ASC', :dependent => :destroy do
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

        after_save :create_version, :if => :needs_version?

        include InstanceMethods
        alias_method_chain :reload, :versions
      end
    end

    module InstanceMethods
      private
        def needs_version?
          !revisable_changes.empty?
        end

        def reset_version(new_version = nil)
          @last_version = nil if new_version.nil?
          @version = new_version
        end

        def create_version
          if versions.empty?
            versions.create(:changes => attributes, :number => 1)
          else
            reset_version
            versions.create(:changes => revisable_changes, :number => (version.to_i + 1))
          end
          reset_version
        end

        def add_association(association_object)
          association_changes.merge!('association' => {:action => 'add', :name => association_object.class.name, :id => association_object.id})
        end

        def remove_association(association_object)
          association_changes.merge!('association' => ['remove', association_object.id])
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

        def revisable_changes
          changes.merge!(association_changes)
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

        def last_changes
          return {} if version.nil? || version == 1
          versions.at(version).changes
        end

        def last_changed
          last_changes.keys
        end
    end
  end
end

ActiveRecord::Base.send(:include, LaserLemon::VestalVersions)
