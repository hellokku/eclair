module Eclair
  class Instance < Cell
    def initialize instance_id, column = nil
      super
      @instance_id = instance_id
      @column = column
    end

    def id
      @instance_id
    end

    def x
      column.x
    end

    def y
      column.index(self)
    end

    def name
      begin
        nametag = object.tags.find{|t| t.key == "Name"}
        nametag ? nametag.value : "noname"
      rescue
        "terminated"
      end
    end

    def color
      if [48, 80].include?(state[:code])
        super(*config.disabled_color)
      else
        super(*config.instance_color)
      end
    end

    def format
      " - #{name} [#{launched_at}] #{select_indicator}"
    end

    def hosts
      [object.public_ip_address, object.private_ip_address].compact
    end

    def image **options
      Aws.images(**options).find{|i| i.image_id == object.image_id}
    end

    def security_groups **options
      if Aws.security_groups?
        object.security_groups.map{|instance_sg| 
          Aws.security_groups(**options).find{|sg| sg.group_id == instance_sg.group_id }
        }.compact
      else
        nil
      end
    end

    def routes
      if Aws.dns_records?
        Aws.dns_records.select do |record| 
          values = record.resource_records.map(&:value)
          !values.grep(private_dns_name).empty? ||
          !values.grep(public_dns_name).empty? ||
          !values.grep(private_ip_address).empty? ||
          !values.grep(public_ip_address).empty?
        end
      else
        nil
      end
    end

    def username
      config.ssh_username.call(image(force: true))
    end

    def key_cmd
      if config.ssh_keys[key_name]
        "-i #{config.ssh_keys[key_name]}"
      else
        ""
      end
    end

    def cache_file
      "#{Config::CACHE_DIR}/#{object.instance_id}"
    end

    def exec_from_cache_cmd
      "$(cat #{cache_file} 2>/dev/null)"
    end

    def ssh_cmd
      cmd = hosts.map do |host|
        config.ssh_ports.map do |port|
          cmd = "ssh #{config.ssh_options} -p#{port} #{key_cmd} #{username}@#{host}"
          "(echo #{cmd} > #{cache_file} && #{cmd})"
        end
      end.join(" || ")
      "echo Attaching to #{name} \\[#{object.instance_id}\\] && (#{exec_from_cache_cmd} || (#{cmd}) || rm #{cache_file})"
    end

    def connectable?
      ![48, 80].include?(state[:code])
    end

    def running?
      state[:code] == 16
    end

    def launched_at
      diff = Time.now - launch_time
      {
        "year" => 31557600,
        "month" => 2592000,
        "day" => 86400,
        "hour" => 3600,
        "minute" => 60,
        "second" => 1
      }.each do |unit,v|
        if diff >= v
          value = (diff/v).to_i
          return "#{value} #{unit}#{value > 1 ? "s" : ""}"
        end
      end
      "now"
    end

    def digest_tags
      tags.map{|t| "#{t[:key]}: #{t[:value]}"}.join("/")
    end

    def digest_routes
      if Aws.dns_records?
        routes.map(&:name).join(" ")
      else
        "Fetching DNS records from Route53..."
      end
    end

    def header
      <<-EOS
      #{name} (#{instance_id}) [#{state[:name]}]
      launched at #{launch_time.to_time}
      EOS
    end

    def info
      to_merge = {}
      
      if routes
        to_merge[:routes] = routes.map(&:to_h)
      else
        to_merge[:routes] = "Fetching DNS records from Route53..."
      end

      if image
        to_merge[:image] = image.to_h
      else
        to_merge[:image] = "Fetching Image data from EC2..."
      end

      object.to_h.merge(to_merge)
    end

    def object
      Aws.instance_map[@instance_id]
    end
  end
end 
