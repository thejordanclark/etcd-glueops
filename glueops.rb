#!/usr/bin/env ruby
require 'rubygems'
require 'bundler/setup'

require 'etcd'
# client = Etcd.client(host: '127.0.0.1', port: 4001)
client = Etcd.client

a_message = client.exists?('/some_random_message')
if a_message
  client.update('/some_random_message', value: 'The was a message')
else
  client.create('/some_random_message', value: 'There was not a message')
end

puts client.get('/some_random_message').value
client.delete('/some_random_message')
