# HostDB Collector (Openstack)

First of the collector libraries for gathering data to insert into HostDB.

Given a datacenter, queries the Openstack API to get data about all of the hosts in each tenant, and sends the data to HostDB.

The library can either be executed in a container (recommended) or on the command line after installing the gem.

## Continuous Integration

The ruby gem is built and installed in a container as part of a build.

The build used to be here: https://builds.pdxfixit.com/gh/hostdb-collector-openstack

The final artifact (the container image) was uploaded to the registry at this location:
https://registry.pdxfixit.com/hostdb-collector-openstack

## Installation (Docker Container)

Build the container image from the root directory of the cloned Git repository:

    $ make build

## Installation (Standalone gem)

Build the gem from the root directory of the cloned Git repository:

    $ gem build hostdb_collector_openstack.gemspec
    
And install the freshly built gem:

    $ gem install hostdb_collector_openstack-<VERSION>.gem

## Usage

Requires a `DATACENTER` variable to be set, and credential pairs for both the Openstack and HostDB APIs to execute.

See the execution instructions on how to supply the required account information

### Configuration
    
A YAML configuration file is also required to run the application. The default configuration can be viewed [here](https://github.com/pdxfixit/hostdb-collector-openstack/blob/master/etc/collector_config.yaml).

## Execution (Docker Container)

Run the docker container previously built, providing the credentials in an environment file:

    $ cat ~/.creds
    OS_USERNAME=<Openstack Username>
    OS_PASSWORD=<Openstack Password>
    HOSTDB_USERNAME=<HostDB Username>
    HOSTDB_PASSWORD=<HostDB Password>
    $ docker run --rm --env-file ~/.creds -e DATACENTER=va2 openstack-collector
    
OR run the latest docker container built via the build pipeline (recommended):

    $ docker run --rm --env-file ~/.creds -e DATACENTER=va2 registry.pdxfixit.com/hostdb-collector-openstack
    
## Execution (Standalone executable)

The username/password combination can either be set in the following four environment variables prior to execution:

    $ export OS_USERNAME=<Openstack Username>
    $ export OS_PASSWORD=<Openstack Password>
    $ export HOSTDB_USERNAME=<HostDB Username>
    $ export HOSTDB_PASSWORD=<HostDB Password>
    $ export DATACENTER=va2
    
OR supplied on the command line using the following flags:

    --openstack_username <Openstack Username> --openstack_password <Openstack Password> --hostdb_username <HostDB Username> --hostdb_password <HostDB Password> --datacenter <datacenter>
    
Invoke the collector via the lone script in the bin directory of the repository clone:

    $ ruby bin/hostdb_collector_openstack <optional_parameters>

For either method of execution, setting the environment variable B_DEBUG=1 will enable debug logging.

## Development

To test the openstack collector locally, a test instance of HostDB is likely required.
Please [see that project README](https://github.com/pdxfixit/hostdb-server/blob/master/README.md#development) for information on how to start an instance.

### Sample Data

The collector can output data to a file, instead of posting to HostDB. This can useful for debugging, and is used periodically to refresh the [sample data available in the hostdb-server project](https://github.com/pdxfixit/hostdb-server/tree/master/sample-data/openstack).

Simply run:

    $ make sample_data
    
Which will create a sample-data folder, and run the container with the environment variable `SAMPLE_DATA=true` and the newly created folder mapped to the container's filesystem root.
The container will generate JSON files for teach tenant it polls, and will then exit.

## Notes

When opening firewall rules to the Openstack endpoints, the following ports should be included:

- 5000 (identity auth)
- 8774 (nova, for metadata)
