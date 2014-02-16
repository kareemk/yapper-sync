unless defined?(Motion::Project::Config)
  raise "This file must be required within a RubyMotion project Rakefile."
end

require 'motion-require'
require 'motion-support/concern'
require 'motion-support/inflector'
require 'motion-support/core_ext'
require 'yapper'

files = Dir.glob(File.expand_path('../../lib/yapper-sync/**/*.rb', __FILE__))
puts "requiring #{files}"
Motion::Require.all(files)

Motion::Project::App.setup do |app|
  app.detect_dependencies = false

  app.pods do
    pod 'AFNetworking'     ,'~> 1.3.3'
    pod 'Reachability'     ,'~> 3.1.1'
    pod 'CocoaLumberjack'  ,'~> 1.6.5'
  end
end
