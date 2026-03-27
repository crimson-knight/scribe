# Patch: Amber custom registry codegen bug workaround
# When Grant models exist (which include YAML::Serializable via Grant::Base),
# the compiler generates mismatched LLVM union types for Hash(String, YAML::Serializable).
# Since Scribe is a native app and never loads custom YAML configs, we replace
# the problematic method with a no-op.

module Amber::Configuration
  # Override to avoid LLVM codegen bug with Grant::Base + YAML::Serializable union types
  def self.load_custom_from_yaml(key : String, yaml_content : String) : Nil
    nil
  end
end
