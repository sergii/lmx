# frozen_string_literal: true

# Adapts Enforceable to LMX's two-principal Action Policy setup. Policies can
# require both the authenticated user and the selected workspace membership.
module Enforceable
  class LmxActionPolicyBinding < Binding
    Actor = Data.define(:user, :membership)

    RECORD_TYPES = {
      "Client::ApplicationPolicy" => "Application",
      "InterviewPolicy" => "Interview"
    }.freeze

    def rules_for(policy_class)
      policy_class.enforceable_declarations.map(&:rule)
    end

    def check(actor, rule, record, policy_class:)
      return false unless supports_record?(policy_class, record)

      policy_class.new(record, user: actor.user, membership: actor.membership).apply(rule)
    end

    def scope(actor, _rule, relation, policy_class:, scope_name:, **scope_options)
      return relation.none unless supports_relation?(policy_class, relation)

      policy_class.new(nil, user: actor.user, membership: actor.membership).apply_scope(
        relation,
        type: :active_record_relation,
        name: scope_name,
        scope_options: scope_options.presence
      )
    end

    private

    def supports_record?(policy_class, record)
      expected_record_class(policy_class) == record.class
    end

    def supports_relation?(policy_class, relation)
      expected_record_class(policy_class) == relation.klass
    end

    def expected_record_class(policy_class)
      RECORD_TYPES.fetch(policy_class.name).constantize
    end
  end
end
