#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

etcd_host = '127.0.0.1'
etcd_port = '4001'

require 'cliqr'
cli = Cliqr.interface do
  name 'glueOps'
  description 'An app that can act as an operator to provide the glue '\
              'to link gliderlabs/registrator and cstpdk/haproxy-confd'
  version '0.0.1'

  # main command handler
  handler {}

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
  # the end of options
end

cli.execute(ARGV)

print "etcd creds = #{etcd_host}:#{etcd_port}\n"

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
