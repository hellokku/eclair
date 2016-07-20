module Eclair
  class Pod < Cell
    def initialize object, column = nil
      super
      @object = object
      @column = column
    end

    def id
      @name
    end

    def x
      column.x
    end

    def y
      column.index(self)
    end

    def color
      if running?
        super(*config.instance_color)
      else
        super(*config.disabled_color)
      end
    end

    def format
      " - #{name} [#{launched_at}] #{select_indicator}"
    end

    def name
      @object['metadata']['name']
    end

    def launch_time
      Time.parse @object['status']['startTime']
    end

    def state
      @object['status']['phase']
    end

    def namespace
      @object['metadata']['namespace']
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
      "#{Config::CACHE_DIR}/#{object.name}"
    end

    def exec_from_cache_cmd
      "$(cat #{cache_file} 2>/dev/null)"
    end

    def ssh_cmd
      "kubectl --kubeconfig=#{config.kubeconfig} --namespace=#{namespace} exec --tty -i #{name} /bin/bash"
    end

    def connectable?
      running?
    end

    def running?
      state == "Running"
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
      #{name} (#{name}) [#{state}]
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
      Aws.instance_map[@name]
    end
  end
end
