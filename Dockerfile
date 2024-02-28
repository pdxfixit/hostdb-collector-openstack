FROM ruby:2.6-slim

COPY . /openstack-collector

WORKDIR /openstack-collector

RUN gem build hostdb_collector_openstack.gemspec && \
    gem install hostdb_collector_openstack-*.gem && \
    apt-get update && apt-get install -y curl

ENTRYPOINT ["/openstack-collector/bin/hostdb_collector_openstack"]
