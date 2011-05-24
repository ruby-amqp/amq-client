#!/bin/sh

# guest:guest has full access to /

rabbitmqctl add_vhost /
rabbitmqctl add_user guest guest
rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"


# guest:guest has full access to amq_client_testbed
# amq_client_gem:amq_client_gem has full access to /amq_client_testbed

rabbitmqctl delete_vhost "amq_client_testbed"
rabbitmqctl add_vhost "amq_client_testbed"
rabbitmqctl delete_user amq_client_gem
rabbitmqctl add_user amq_client_gem amq_client_gem_password
rabbitmqctl set_permissions -p amq_client_testbed guest ".*" ".*" ".*"
rabbitmqctl set_permissions -p amq_client_testbed amq_client_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to amq_client_testbed

rabbitmqctl add_user amq_client_gem_reader reader_password
rabbitmqctl set_permissions -p amq_client_testbed amq_client_gem_reader "^---$" "^---$" ".*"