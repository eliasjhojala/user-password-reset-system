module UserPasswordResetSystem
  class Engine < Rails::Engine
  end

  mattr_accessor :settings
  self.settings = {}

  def self.setup(&block)
    yield self
  end
end
