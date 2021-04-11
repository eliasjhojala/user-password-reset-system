Gem::Specification.new do |s|
  s.name = %q{user-password-reset-system}
  s.version = "0.1.06"
  s.date = %q{2021-04-11}
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
