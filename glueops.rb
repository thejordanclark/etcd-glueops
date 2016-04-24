#!/usr/bin/env ruby

# Make sure PWD where the script lives
Dir.chdir(File.dirname(__FILE__)) unless Dir.pwd == File.dirname(__FILE__)

require 'rubygems'
require 'bundler/setup'

glueops_config = '/glueOps'
registrator_path = '/registrator'
haproxy_discover_path = '/haproxy-discover'
etcd_host = '127.0.0.1'
etcd_port = '4001'
path_regex = %r{(/)[a-zA-Z0-1]*}
run_app = nil

def check_etcd_path(client, etcd_path, path_name)
  if client.exists?(etcd_path)
    unless client.get(etcd_path).directory?
      print "#{path_name} Path #{etcd_path} exists but is not a directory\n"
      exit
    end
  else
    print "#{path_name} Path #{etcd_path} does not exist\n"
    exit
  end
end # check_etcd_path

def check_haproxy_skel(client, haproxy_service_path, haproxy_service_ext)
  unless client.exists?(haproxy_service_path)
    client.create(haproxy_service_path, dir: true)
  end
  unless client.exists?("#{haproxy_service_path}/upstreams")
    client.create("#{haproxy_service_path}/upstreams", dir: true)
  end
  if client.exists?("#{haproxy_service_path}/ports")
    unless client.get("#{haproxy_service_path}/ports").value == haproxy_service_ext
      client.update("#{haproxy_service_path}/ports", value: haproxy_service_ext)
    end
  else
    client.create("#{haproxy_service_path}/ports", value: haproxy_service_ext)
  end
end # check_haproxy_skel

def add_haproxy_upstream(client, haproxy_service_path, container_id, service_backend_url)
  if client.exists?("#{haproxy_service_path}/upstreams/#{container_id}")
    unless client.get("#{haproxy_service_path}/upstreams/#{container_id}").value == service_backend_url
      client.update("#{haproxy_service_path}/upstreams/#{container_id}", value: service_backend_url)
    end
  else
    client.create("#{haproxy_service_path}/upstreams/#{container_id}", value: service_backend_url)
  end
end # add_haproxy_upstream

def verify_existing_upstreams(client, service_path, registrator_path, service_string)
  service_port = service_string.split('-').last
  service_name = service_string.chomp("-#{service_port}")

  # read each upstream
  upstreams = client.get("#{service_path}/#{service_string}/upstreams").children
  upstreams.each do |upstream|
    upstream_container = upstream.key.split('/').last
    # DEBUG info:
    # puts "-- upstream to verify --"
    # puts service_path
    # puts registrator_path
    # puts service_string
    # puts service_port
    # puts service_name
    # puts upstream_container
    # puts ""
    # See if it exists
    upstream_found = nil

    # Find Registered services
    registered_services = client.get(registrator_path).children
    registered_services.each do |registered_service|
      backend_services = client.get(registered_service.key).children
      backend_services.each do |backend_service|
        backend_service_string = backend_service.key.split('/').last
        (container_id, container_name, container_port) = backend_service_string.split(':')
        if container_id == upstream_container && container_name == service_name && container_port == service_port
          # Mark as found
          upstream_found = true
        end
      end
    end # registered_services.each do |registerd_service|

    # remove if not exist
    if not upstream_found
      # DEBUG info:
      # puts "---REMOVEING---"
      # puts "#{service_path}/#{service_string}/upstreams/#{upstream_container}"

      client.delete("#{service_path}/#{service_string}/upstreams/#{upstream_container}")

    end # if upstream_found
  end # upstreams.each do |upstream|
end # verify_existing_upstreams

def find_existing_services(client, glueops_config, haproxy_discover_path, registrator_path, service_type)
  if client.exists?("#{haproxy_discover_path}/#{service_type}")
    if client.get("#{haproxy_discover_path}/#{service_type}").directory?
      services = client.get("#{haproxy_discover_path}/#{service_type}").children
      services.each do |service|
        next if client.exists?("#{haproxy_discover_path}/#{service_type}/upstreams")
        service_string = service.key.split('/').last
        service_port = service_string.split('-').last
        service_name = service_string.chomp("-#{service_port}")

        # Only verify managed services
        if client.exists?("#{glueops_config}/#{service_type}/#{service_name}")
          # Verify each service upstreams, remove old
          verify_existing_upstreams(client, "#{haproxy_discover_path}/#{service_type}", registrator_path, service_string)
        end # client.exists?("#{glueops_config}/#{service_type}/#{service_name}")
      end # services.each do |service|
    end # client.get(#{haproxy_discover_path}/#{service_type}).directory?
  end # client.exists?(#{haproxy_discover_path}/#{service_type})
end # find_existing_services

require 'cliqr'
cli = Cliqr.interface do
  name 'glueOps'
  description 'An app that can act as an operator to provide the glue '\
              'to link gliderlabs/registrator and cstpdk/haproxy-confd'
  version '0.0.1'

  # main command handler
  handler do
    run_app = true
  end

  option :config do
    short 'c'
    description "glueOps Config path with etcd. default: #{glueops_config}"
    operator do
      begin
        fail StandardError,
             "Invalid Path: #{value}" unless path_regex.match(value)
        glueops_config = value
      rescue => msg
        print "Config Path Invalid\n"
        puts(msg)
        exit
      end
    end
  end

  option :host do
    short 'H'
    description "the etcd host to connect to. default: #{etcd_host}"
    operator do
      begin
        require 'resolv'
        fail StandardError,
             "Unknown host: #{value}" unless Resolv.getaddress value
        etcd_host = value
      rescue => msg
        print "Host value failed\n"
        puts(msg)
        exit
      end
    end
  end

  option :port do
    short 'p'
    description "the etcd port to connect to. default: #{etcd_port}"
    operator do
      begin
        fail StandardError,
             "Invalid Port: #{value}" unless (1..65_535).cover?(value.to_i)
        etcd_port = value
      rescue => msg
        print "Port value failed\n"
        puts(msg)
        exit
      end
    end
  end
end # end of options

# Get all the imputs
cli.execute(ARGV)

# Run the App
if run_app
  # Connect "client" to etcd
  require 'etcd'
  client = Etcd.client(host: etcd_host.to_s, port: etcd_port.to_s)

  # Check Config Path
  check_etcd_path(client, glueops_config, 'Config')

  # Read registrator_path
  if client.exists?("#{glueops_config}/config/registrator_path")
    registrator_path = client.get("#{glueops_config}/config/registrator_path").value
  else
    print "Registrator path not set in #{glueops_config}/config/registrator_path "
    print "using defaul value #{registrator_path}\n"
  end

  # Read haproxy_discover_path
  if client.exists?("#{glueops_config}/config/haproxy-discover_path")
    haproxy_discover_path = client.get("#{glueops_config}/config/haproxy-discover_path").value
  else
    print "HAProxy-Discover path not set in #{glueops_config}/config/haproxy-discover_path "
    print "using defaul value #{haproxy_discover_path}\n"
  end

  # DEBUG info:
  # print "Registrator Path: #{registrator_path}\nHAProxy-Discover Path: #{haproxy_discover_path}\n"

  # Check registrator_path
  check_etcd_path(client, registrator_path, 'Registrator')

  # Check haproxy_discover_path
  check_etcd_path(client, haproxy_discover_path, 'HAProxy-Discover')

  # services

  # tcp-services
  if client.exists?("#{glueops_config}/tcp-services")
    if client.get("#{glueops_config}/tcp-services").directory?
      tcp_services = client.get("#{glueops_config}/tcp-services").children
      tcp_services.each do |tcp_service|
        service_name = tcp_service.key.split('/').last

        # Read in configs
        tcp_service = client.get(tcp_service.key).children
        tcp_service.each do |tcp_service_port|
          service_port = tcp_service_port.key.split('/').last
          service_ext_ip = client.get("#{tcp_service_port.key}/ext_ip").value
          service_ext_port = client.get("#{tcp_service_port.key}/ext_port").value

          # Create Skel
          haproxy_service_path = "#{haproxy_discover_path}/tcp-services/#{service_name}-#{service_port}"
          haproxy_service_ext = "#{service_ext_ip}:#{service_ext_port}"
          check_haproxy_skel(client, haproxy_service_path, haproxy_service_ext)

          # Find Registered services
          registered_services = client.get(registrator_path).children
          registered_services.each do |registered_service|
            backend_services = client.get(registered_service.key).children
            backend_services.each do |backend_service|
              # backend_service_path = registered_service.key
              backend_service_string = backend_service.key.split('/').last
              (container_id, container_name, container_port) = backend_service_string.split(':')
              if container_name == service_name && container_port == service_port
                # Add upstreams
                add_haproxy_upstream(client, haproxy_service_path, container_id, client.get(backend_service.key).value)
              end
            end
          end # registered_services.each do |registerd_service|

          # TODO: Run additional scripts per port
        end # end tcp_service.each do |tcp_service_port|

        # TODO: Run additional scripts per service

      end # end tcp_services.each do |tcp_service|
    end # end tcp-services.directory?

    # verify upstreams, remove invalid upstreams
    find_existing_services(client, glueops_config, haproxy_discover_path, registrator_path, 'tcp-services')

  end # end tcp-services
end # End of run_app

# tcp_services = client.get("#{glueops_config}/tcp-services")
# if tcp_services.directory?
#   print "#{glueops_config}/tcp-services is a directory\n"

#
# require 'etcd'
#
# client = Etcd.client(host: '127.0.0.1', port: 4001)
#
# client = Etcd.client
#
# a_message = client.exists?('/some_random_message')
# if a_message
#   client.update('/some_random_message', value: 'The was a message')
# else
#   client.create('/some_random_message', value: 'There was not a message')
# end
#
# puts client.get('/some_random_message').value
# client.delete('/some_random_message')

# command = ARGV.shift
#
# case command
# when 'run'
#   puts('#TODO: Start a single run')
#
# when 'start'
#   puts('#TODO: Make it run continuosly')
#
# else
#   puts('#TODO: Print the help')
# end
