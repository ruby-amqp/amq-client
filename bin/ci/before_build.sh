#!/bin/sh

${RABBITMQCTL:="sudo rabbitmqctl"}

# guest:guest has full access to /

$RABBITMQCTL add_vhost /
$RABBITMQCTL add_user guest guest
$RABBITMQCTL set_permissions -p / guest ".*" ".*" ".*"


# guest:guest has full access to amq_client_testbed
# amq_client_gem:amq_client_gem has full access to /amq_client_testbed

$RABBITMQCTL delete_vhost "amq_client_testbed"
$RABBITMQCTL add_vhost "amq_client_testbed"
$RABBITMQCTL delete_user amq_client_gem
$RABBITMQCTL add_user amq_client_gem amq_client_gem_password
$RABBITMQCTL set_permissions -p amq_client_testbed guest ".*" ".*" ".*"
$RABBITMQCTL set_permissions -p amq_client_testbed amq_client_gem ".*" ".*" ".*"


# amqp_gem_reader:reader_password has read access to amq_client_testbed

$RABBITMQCTL add_user amq_client_gem_reader reader_password
$RABBITMQCTL set_permissions -p amq_client_testbed amq_client_gem_reader "^---$" "^---$" ".*"
