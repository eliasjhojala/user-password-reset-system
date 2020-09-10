module UserPasswordResetSystem
  class Engine < Rails::Engine
  end
  
  class << self
    mattr_accessor :settings
  end
  
  def self.setup(&block)
    yield self
  end
end
