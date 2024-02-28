require 'excon'
require 'json'
require 'base64'
require 'logger'

Excon.defaults[:ssl_verify_peer] = false
Excon.defaults[:read_timeout] = 120

class HostDB

  def initialize(context)
    hostdb_username = ENV['HOSTDB_USERNAME'] || context[:hostdb_username]
    hostdb_password = ENV['HOSTDB_PASSWORD'] || context[:hostdb_password]

    abort "Missing required parameter: HostDB Username" if hostdb_username.nil? or hostdb_username.empty?
    abort "Missing required parameter: HostDB Password" if hostdb_password.nil? or hostdb_password.empty?

    encoded = Base64.encode64(hostdb_username + ":" + hostdb_password).strip
    @authorization = 'Basic ' + encoded

    @hostdb_url = ENV['HOSTDB_URL'] || context['hostdb_url']

    @logger = Logger.new(STDOUT)
    @logger.level = ENV['B_DEBUG'] ? Logger::DEBUG : Logger::INFO
    @logger.datetime_format = '%m-%d-%Y %H:%M:%S %Z'

    @logger.info('Using creds ' + hostdb_username + ':*****' + hostdb_password.chars.last(3).join + ' @ ' + @hostdb_url)
  end

  def health_check
    @logger.info('Connecting to HostDB server @ ' + @hostdb_url)
    connection = Excon.new(@hostdb_url)
    response = connection.get(
      :path => '/health',
      :expects => [200],
    )

    health = JSON.parse(response.body)
    app_status = health['app']
    db_status = health['db']

    (app_status.eql? 'up') && (db_status.eql? 'present')
  end

  def update_host_info(host_info_array, context, images, flavors, timestamp)
    is_successful = 0

    tenant_hosts = []

    if host_info_array.length > 0
      host_info_array.each do |host_info|
        host_context = {}

        hostname = host_info['name']

        if hostname.nil?
          @logger.warn('No hostname provided for ' + host_info['id'])
          next
        end

        if host_info['addresses'].nil?
          @logger.warn('No network information provided for ' + hostname)
          next
        end

        tenant_name = host_info['addresses'].keys[0]

        if tenant_name.nil?
          @logger.warn('No attached networks listed for ' + hostname)
          next
        end

        ip = host_info['addresses'][tenant_name][0]['addr']

        if ip.nil?
          @logger.warn('Unable to determine IP address for ' + hostname)
          next
        end

        if host_info['image']['id'].nil?
          @logger.warn('Unable to determine base image used to build ' + hostname)
        else
          image_id = host_info['image']['id']
          image = images.select {|image| image['id'] == image_id}.first || {}
          host_context['image'] = image['name'] unless image.empty?
        end

        if host_info['flavor']['id'].nil?
          @logger.warn('Unable to determine VM flavor for ' + hostname)
        else
          flavor_id = host_info['flavor']['id']
          flavor = flavors.select {|flavor| flavor['id'] == flavor_id}.first || {}
          host_context['flavor'] = flavor['name'] unless flavor.empty?
        end

        host = {}
        host['data'] = host_info
        host['hostname'] = hostname
        host['ip'] = ip
        host['context'] = host_context
        tenant_hosts.push(host)
      end
    end

    post_data = {}
    post_data['type'] = 'openstack'
    post_data['committer'] = 'hostdb-collector-openstack'
    post_data['records'] = tenant_hosts
    post_data['context'] = context
    post_data['timestamp'] = timestamp

    if ENV['SAMPLE_DATA'] == "true" && Dir.exist?('/sample-data')
      File.write('/sample-data/' + context['tenant_name'] + '.json', post_data.to_json)
      @logger.info('Wrote sample data to file: ' + context['tenant_name'] + '.json')
      return 0
    end

    @logger.debug('Request for ' + context['tenant_name'] + ': ' + post_data.to_json)

    connection = Excon.new(@hostdb_url)
    response = connection.post(
      :path => '/v0/records/?tenant=' + context['tenant_name'], # tenant isn't used, but it's nice for logging
      :headers => {'Content-Type' => 'application/json', 'Authorization' => @authorization},
      :expects => [200],
      :debug_response => true,
      :debug_request => true,
      :body => post_data.to_json
    )

    @logger.debug('Response: ' + response.body)
    response_json = JSON.parse(response.body)

    if response_json.has_key?('ok')
      if response_json['ok'] == false # if not ok, report the error.
        if response_json.has_key?('error')
          @logger.error("HostDB server failed to insert records, and told me: #{response_json['error']}")
        else
          @logger.error("HostDB server failed to insert records, and didn't tell me anything useful.")
        end
        is_successful = 1
      else # if ok, report the "error" message anyway
        if response_json.has_key?('error') && response_json['error'] != ""
          @logger.info("HostDB responded: #{response_json['error']}")
        end
      end
    else
      @logger.error("The HostDB response didn't meet expectations.")
      is_successful = 1 # this means fail
    end

    is_successful

  end

end
