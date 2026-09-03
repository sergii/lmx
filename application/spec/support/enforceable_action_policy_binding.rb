# frozen_string_literal: true

require Rails.root.join("lib/enforceable/lmx_action_policy_binding")
require "enforceable/runner"

EnforceableActionPolicyBinding = Enforceable::LmxActionPolicyBinding
EnforceableActor = Enforceable::LmxActionPolicyBinding::Actor
