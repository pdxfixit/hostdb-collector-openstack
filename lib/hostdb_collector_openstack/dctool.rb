require 'excon'
require 'json'

class DCTool

  def initialize(context)
    @dctool_url = context['dctool_url'] || 'https://dctool.pdxfixit.com'
  end

  def get_tenant_info(datacenter)
    connection = Excon.new(@dctool_url)

    response = connection.get(
      :path => '/dctool/dump/dc/' + datacenter
    )

    response_json = JSON.parse(response.body)

    tenants = []

    response_json['stacks'].each do |stack|
      stack['segments'].each do |tenant|
        auth_url = tenant['os_auth_url']
        next if auth_url.nil?

        last_index = auth_url.rindex(':')
        openstack_url = auth_url[0,last_index]

        tenant_name = tenant['os_tenant_name']
        tenant_id = tenant['os_tenant_id']

        unless openstack_url.nil? || tenant_name.nil? || tenant_id.nil?
          tenant_info = Tenant.new(stack['name'], openstack_url, tenant_name, tenant_id)
          tenants.push(tenant_info)
        end
      end
    end

    tenants

  end

end

class Tenant

  attr_accessor :stack_name, :openstack_url, :tenant_name, :tenant_id

  def initialize(stack_name, openstack_url, tenant_name, tenant_id)
    self.stack_name = stack_name
    self.openstack_url = openstack_url
    self.tenant_name = tenant_name
    self.tenant_id = tenant_id
  end

end