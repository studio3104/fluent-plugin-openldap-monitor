class OpenLDAPMonitorInput < Fluent::Input
  Fluent::Plugin.register_input('openldap_monitor', self)

  def configure(conf)
    super
  end

  def start
    super
  end

  def shutdown
  end
end

