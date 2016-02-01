#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

glueops_config = '/glueOps'
etcd_host = '127.0.0.1'
etcd_port = '4001'
path_regex = %r{(/)[a-zA-Z0-1]*}
run_app = nil


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

if run_app
  # print "etcd creds = #{etcd_host}:#{etcd_port}\n"
  # print "glueOps config = #{glueops_config}\n"

  # Contect "client" to etcd
  require 'etcd'
  client = Etcd.client(host: etcd_host.to_s, port: etcd_port.to_s)

  # Check Config Path
  if client.exists?(glueops_config)
    if client.get(glueops_config).directory?
      print "Config Path #{glueops_config} is a directory\n"
    else
      print "Config Path #{glueops_config} exists but is not a directory\n"
      exit
    end
  else
    print "Config Path #{glueops_config} dose not exist\n"
    exit
  end

  # services

  # tcp-services
  if client.exists?("#{glueops_config}/tcp-services")
    print "#{glueops_config}/tcp-services exists\n"
    if client.get("#{glueops_config}/tcp-services").directory?
      print "#{glueops_config}/tcp-services is a directory\n"
      tcp_services = client.get("#{glueops_config}/tcp-services").children
      tcp_services.each do |tcp_service|
        puts tcp_service.key
      end

    end
  end
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
