Gem::Specification.new do |s|
  s.name = %q{user-password-reset-system}
  s.version = "0.1.11"
  s.date = %q{2021-07-17}
  s.summary = %q{system for resetting user password}
  s.files = [
    "lib/user-password-reset-system.rb"
  ]
  s.require_paths = ["lib"]
  [
    'general-form'
  ].each { |dep_name| s.add_runtime_dependency(dep_name) }
  s.authors = "elias"
end
