require 'helper'

class OpenLDAPMonitorInputTest < Test::Unit::TestCase
  CONFIG = %[
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::OpenLDAPMonitorInput).configure(conf)
  end
end
