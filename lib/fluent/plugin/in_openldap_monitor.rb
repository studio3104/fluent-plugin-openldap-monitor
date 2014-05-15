class Fluent::OpenLDAPMonitorInput < Fluent::Input
  Fluent::Plugin.register_input('openldap_monitor', self)

  config_param :tag, :string
  config_param :host, :string
  config_param :port, :integer, default: 389
  config_param :bind_dn, :string
  config_param :bind_password, :string
  config_param :check_interval, :integer, default: 60

  def initialize
    super
    require 'net/ldap'
  end

  def configure(conf)
    super
    @auth = {
      method: :simple,
      username: @bind_dn,
      password: @bind_password,
    }
  end

  def start
    super
    @watcher = TimerWatcher.new(@check_interval, true, &method(:ldapkarastatusmonitornoataiwotottekru))
    @loop = Coolio::Loop.new
    @watcher.attach(@loop)
    @thread = Thread.new(&method(:run))
  end

  def shutdown
    @watcher.detach
    @loop.stop
    @thread.join
  end

  def run
    @loop.run
  end

  SUPPRESS_ATTRIBUTES = %w{ dn structuralobjectclass creatorsname modifiersname createtimestamp modifytimestamp monitortimestamp entrydn subschemasubentry hassubordinates }
  def ldapkarastatusmonitornoataiwotottekru
    result = {}
    Net::LDAP.open(host: @host, port: @port, auth: @auth) do |ldap|
      ldap.search(attributes: ['+'], base: 'cn=Monitor') do |entry|
        dn = entry[:dn].first
        dn = dn.split(',').map { |d| d.sub(/cn\=/,'').gsub(/\s+/,'_').downcase.to_sym }.reverse

        values_of = {}
        entry.each do |attribute, values|
          next if SUPPRESS_ATTRIBUTES.include?(attribute.to_s)
          values_of[attribute] = values
        end

        case dn.size
        when 1
          result[dn[0]] ||= values_of
        when 2
          result[dn[0]][dn[1]] ||= values_of
        when 3
          result[dn[0]][dn[1]][dn[2]] ||= values_of
        when 4
          result[dn[0]][dn[1]][dn[2]][dn[3]] ||= values_of
        else raise dn.size.to_s
        end
      end
    end

    Fluent::Engine.emit(@tag, Fluent::Engine.now, result)
  end

  class TimerWatcher < Coolio::TimerWatcher
    def initialize(interval, repeat, &checker)
      @checker = checker
      super(interval, repeat)
    end

    def on_timer
      @checker.call
    end
  end
end
