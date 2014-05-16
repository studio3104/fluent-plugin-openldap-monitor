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

    auth = {
      method: :simple,
      username: @bind_dn,
      password: @bind_password,
    }
    @ldap = Net::LDAP.new(host: @host, port: @port, auth: auth)
  end

  def start
    super
    @watcher = TimerWatcher.new(@check_interval, true, &method(:ldapsearch))
    @loop = Coolio::Loop.new
    @watcher.attach(@loop)
    @thread = Thread.new(@loop.run)
  end

  def shutdown
    @watcher.detach
    @loop.stop
    @thread.join
  end

  def ldapsearch
    entries = @ldap.search(attributes: ['+'], base: 'cn=Monitor')
    result = convert_entries(entries.flatten)
    Fluent::Engine.emit(@tag, Fluent::Engine.now, result)
  rescue => e
    log.warn("#{e.message} (#{e.class.to_s}) #{e.backtrace.to_s}")
  end

  SUPPRESS_ATTRIBUTES = %w{ dn structuralobjectclass creatorsname modifiersname createtimestamp modifytimestamp monitortimestamp entrydn subschemasubentry hassubordinates }
  def convert_entries(entries)
    result = {}
    entries.each do |entry|
      values_of = {}
      entry.each do |attribute, values|
        next if SUPPRESS_ATTRIBUTES.include?(attribute.to_s)
        values_of[attribute] = convert_values_type(values)
      end

      dn = entry[:dn].first # e.g.) cn=Current,cn=Connections,cn=Monitor
      dn = dn.split(',').map { |d| d.sub(/cn\=/,'').gsub(/\s+/,'_').downcase.to_sym }.reverse # e.g.) [:monitor, :connections, :current]

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
    result
  end

  def convert_values_type(values)
    values = [values].flatten.map { |v|
      if v == 'TRUE'
        true
      elsif v == 'FALSE'
        false
      elsif v.match(/^\d+$/)
        v.to_i
      else
        v
      end
    }

    values.size == 1 ? values.first : values
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
