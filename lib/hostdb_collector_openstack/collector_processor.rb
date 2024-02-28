require_relative 'dctool'
require_relative 'openstack'
require_relative 'hostdb'
require 'yaml'

class CollectorProcessor

  def initialize(context)
    config = YAML.load_file('/openstack-collector/etc/collector_config.yaml')
    context = context.merge(config)

    @dctool = DCTool.new(context)
    @openstack = Openstack.new(context)
    @host_db = HostDB.new(context)

    @blocklist = context['tenant_blocklist']

    @logger = Logger.new(STDOUT)
    @logger.level = ENV['B_DEBUG'] ? Logger::DEBUG : Logger::INFO
    @logger.datetime_format = '%m-%d-%Y %H:%M:%S %Z'

    @datacenter = context['datacenter'] || ENV['DATACENTER']
    if !@datacenter
      @logger.error('No datacenter provided! Please be sure to set an environment variable or pass a flag on the command line.')
    end
  end

  def process
    exit_code = 0

    if !@host_db.health_check
      @logger.error('HostDB server health check failed  :-o')
      exit 5
    else
      @logger.info('HostDB server health check passed...starting data collection')

      tenants = @dctool.get_tenant_info(@datacenter)

      tenants.each do |tenant|
        if @blocklist.include?(tenant.tenant_name)
          @logger.info('Skipping blocklisted tenant: ' + tenant.tenant_name)
          next
        end

        timestamp = Time.now.strftime("%F %T")

        context = {}
        context['datacenter'] = @datacenter
        context['stack_name'] = tenant.stack_name
        context['os_auth_url'] = tenant.openstack_url
        context['tenant_name'] = tenant.tenant_name
        context['tenant_id'] = tenant.tenant_id

        @logger.info('Retrieving host information from tenant ' + tenant.tenant_name)
        openstack_host_list = @openstack.get_tenant_hosts(tenant.openstack_url, tenant.tenant_name, tenant.tenant_id)
        @logger.info("Located #{openstack_host_list.length} hosts in " + tenant.tenant_name)

        @logger.info('Retrieving image information from tenant ' + tenant.tenant_name)
        images = @openstack.get_image_details(tenant.openstack_url, tenant.tenant_name)
        @logger.info("Located data about #{images.length} images in " + tenant.tenant_name)

        @logger.info('Retrieving flavor information from tenant ' + tenant.tenant_name)
        flavors = @openstack.get_flavor_details(tenant.openstack_url, tenant.tenant_name)
        @logger.info("Located data about #{flavors.length} flavors in " + tenant.tenant_name)

        @logger.info('POSTing host information for tenant ' + tenant.tenant_name + ' to the HostDB API')
        is_successful = @host_db.update_host_info(openstack_host_list, context, images, flavors, timestamp)

        exit_code = 1 if is_successful == 1
      end

    end

    @logger.info('All done!  See you on the flip side, yo')
    exit_code

  end

end