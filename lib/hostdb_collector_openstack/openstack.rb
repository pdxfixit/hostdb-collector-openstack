require 'excon'
require 'json'

Excon.defaults[:ssl_verify_peer] = false
Excon.defaults[:read_timeout] = 180 # seconds
Excon.defaults[:idempotent] = true
Excon.defaults[:retry_limit] = 5
Excon.defaults[:retry_interval] = 15 # seconds

class Openstack

  def initialize(context)
    @username = ENV['OS_USERNAME'] || context[:openstack_username]
    @password = ENV['OS_PASSWORD'] || context[:openstack_password]

    abort "Missing required parameter: Openstack Username" if @username.nil? or @username.empty?
    abort "Missing required parameter: Openstack Password" if @password.nil? or @password.empty?
  end

  def get_tenant_hosts(base_url, tenant_name, tenant_id)
    access_token = authenticate(base_url + ':5000', tenant_name)
    server_detail(base_url + ':8774', tenant_id, access_token)

  end

  def get_image_details(base_url, tenant_name)
    access_token = authenticate(base_url + ':5000', tenant_name)
    image_detail(base_url + ':8774', access_token)

  end

  def get_flavor_details(base_url, tenant_name)
    access_token = authenticate(base_url + ':5000', tenant_name)
    flavor_detail(base_url + ':8774', access_token)

  end

  def authenticate(auth_url, tenant_name)
    connection = Excon.new(auth_url)

    response = connection.post(
      :path => '/v3/auth/tokens',
      :headers => { 'Content-Type' => 'application/json' },
      :body => {
        :auth => {
          :identity => {
            :methods => [
              'password',
            ],
            :password => {
              :user => {
                :name => @username,
                :domain => {
                  :id => 'default'
                },
                :password => @password
              }
            }
          },
          :scope => {
            :project => {
              :name => tenant_name,
              :domain => {
                :id => 'default'
              }
            }
          }
        }
      }.to_json,
      :expects => [201]
    )
    response.headers['X-Subject-Token']
  end

  def server_detail(compute_url, tenant_id, access_token)
    servers = []

    connection = Excon.new(compute_url)
    response = connection.get(
      :path => '/v2/' + tenant_id + '/servers/detail',
      :headers => { 'X-Auth-Token' => access_token },
      :expects => [200],
      :debug_response => true
    )

    response_body = JSON.parse(response.body)
    servers = servers + response_body['servers']

    until response_body['servers_links'].nil? || response_body['servers_links'].empty? do
      marker = response_body['servers_links'].first['href'][/\bmarker\b=(.*)\b/, 1]

      response = connection.get(
        :path => '/v2/' + tenant_id + '/servers/detail?marker=' + marker,
        :headers => { 'X-Auth-Token' => access_token },
        :expects => [200],
        :debug_response => true
      )

      response_body = JSON.parse(response.body)
      servers = servers + response_body['servers']
    end

    servers
  end

  def image_detail(compute_url, access_token)
    connection = Excon.new(compute_url)
    response = connection.get(
      :path => '/v2/images',
      :headers => { 'X-Auth-Token' => access_token },
      :expects => [200],
      :debug_response => true
    )

    response_body = JSON.parse(response.body)
    response_body['images']
  end

  def flavor_detail(compute_url, access_token)
    connection = Excon.new(compute_url)
    response = connection.get(
      :path => 'v2.1/flavors',
      :headers => { 'X-Auth-Token' => access_token },
      :expects => [200],
      :debug_response => true
    )

    response_body = JSON.parse(response.body)
    response_body['flavors']
  end

end