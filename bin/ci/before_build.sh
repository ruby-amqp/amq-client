#!/bin/sh

# guest:guest has full access to /

sudo rabbitmqctl add_vhost /
sudo rabbitmqctl add_user guest guest
sudo rabbitmqctl set_permissions -p / guest ".*" ".*" ".*"


# guest:guest has full access to amq_client_testbed
# amq_client_gem:amq_client_gem has full access to /amq_client_testbed

sudo rabbitmqctl delete_vhost "amq_client_testbed"
sudo rabbitmqctl add_vhost "amq_client_testbed"
sudo rabbitmqctl delete_user amq_client_gem
sudo rabbitmqctl add_user amq_client_gem amq_client_gem_password
sudo rabbitmqctl set_permissions -p amq_client_testbed guest ".*" ".*" ".*"
sudo rabbitmqctl set_permissions -p amq_client_testbed amq_client_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to amq_client_testbed

sudo rabbitmqctl add_user amq_client_gem_reader reader_password
sudo rabbitmqctl set_permissions -p amq_client_testbed amq_client_gem_reader "^---$" "^---$" ".*"