require 'auth/migration_helper'

module Auth
  module Model
    extend ActiveSupport::Concern

    def self.included(base)
      base.send :include, InstanceMethods
      base.extend ClassMethods
    end

    module InstanceMethods
      def can?(action, subject)
        !get_permission(action, subject).nil?
      end

      def grant(action, subject)
        action_cls = self.class.get_action_class(action, subject)

        params = { self.class.name.underscore + '_id' => id }
        params.update(subject.class.name.underscore + '_id' => subject.id) if action_cls.has_subject

        action_cls.create!(params)
      end

      def revoke(action, subject)
        permission = get_permission(action, subject)

        permission.destroy! unless permission.nil?
      end

      private

      def get_permission(action, subject)
        action_cls = self.class.get_action_class(action, subject)

        actor = self.class.name.underscore
        subj = subject.class.name.underscore

        params = { actor => self }
        params.update(subj => subject) if action_cls.has_subject

        action_cls.find_by(params)
      end
    end

    module ClassMethods
      def get_revokeable(action, subject)
        action_cls = get_action_class(action, subject)

        subject_name = subject.class.name.underscore

        params = {}
        params.update(subject_name => subject) if action_cls.has_subject

        # Workaround due to wierd ActiveRecord edge case for dynamically created models
        actor_id = (name.underscore + '_id').to_sym
        ids = action_cls.where(params).select(actor_id).to_a.map(&actor_id)
        find(ids)
      end

      def validates_permission_to(action, subject)
        actor = name.underscore.to_sym

        table_name = Auth.auth_name(actor, action, subject)

        klass = Class.new(ActiveRecord::Base) do
          self.table_name = table_name
          belongs_to actor

          # Only permissions relating to singular objects have a subject
          class << self
            attr_accessor :has_subject
          end
          self.has_subject = subject.to_s.singularize == subject.to_s
          belongs_to subject if has_subject
        end

        @permissions ||= {}
        @permissions[action] ||= {}
        @permissions[action][subject] = klass
      end

      attr_reader :permissions

      def get_action_class(action, subject)
        subject = subject.class.name.underscore.to_sym unless subject.class == Symbol

        action_cls = permissions[action][subject]
        throw 'Unknown action or subject' if action_cls.nil?

        action_cls
      end
    end
  end
end
