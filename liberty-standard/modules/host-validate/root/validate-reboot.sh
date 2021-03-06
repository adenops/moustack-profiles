#!/bin/sh

# Copyright (C) 2016 Adenops Consultants Informatique Inc.
#
# This file is part of the Moustack project, see http://www.moustack.org for
# more information.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# exit on failure
set -e

# exit on unassigned variable
set -u

# switch working directory
cd $(dirname $0)

# define colors
RESTORE='\033[0m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
BLUE='\033[01;34m'

# define log
log() {
	/bin/echo
	/bin/echo -e "${GREEN}$*${RESTORE}"
}

# define notify
notify() {
	/bin/echo
	/bin/echo -e "${BLUE}$*${RESTORE}"
}

# define warn
warn() {
	/bin/echo
	/bin/echo -e "${YELLOW}$*${RESTORE}"
}

# define fatal
fatal() {
	/bin/echo
	/bin/echo -e "${RED}$*${RESTORE}"
	/bin/echo
	exit 1
}

# define stack status getter
get_stack_status() {
	heat stack-show "$1" | awk '/\| stack_status / {print $4}'
}

# define timestamp getter
get_timestamp_ms() {
	sed -r 's/^([^\.]+)\.([^ ]+).*$/\1\20/' /proc/uptime
}


# source environment variables
. ./validate.env

# default variables
STACK_NAME="${STACK_NAME:-validate}"
IMAGE_LOCATION="${IMAGE_LOCATION:-http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img}"
TENANT_SUBNET="${TENANT_SUBNET:-10.10.33.0/24}"
PUBLIC_SUBNET="${PUBLIC_SUBNET:-27.96.24.0/21}"
PUBLIC_GATEWAY="${PUBLIC_GATEWAY:-27.96.31.254}"
PUBLIC_INSTANCE_FIP="${PUBLIC_INSTANCE_FIP:-27.96.25.3}"
PUBLIC_LB_FIP="${PUBLIC_LB_FIP:-27.96.25.42}"

# hardcoded variables
HEAT_DOMAIN="domain.validate"
ASG_INSTANCE_NAME="heat_autoscaled_instance"

# build heat command arguments
PARAMS=""
PARAMS="${PARAMS} --parameters ImageLocation=${IMAGE_LOCATION}"
PARAMS="${PARAMS} --parameters TenantSubnet=${TENANT_SUBNET}"
PARAMS="${PARAMS} --parameters PublicSubnet=${PUBLIC_SUBNET}"
PARAMS="${PARAMS} --parameters PublicGateway=${PUBLIC_GATEWAY}"
PARAMS="${PARAMS} --parameters PublicInstanceFip=${PUBLIC_INSTANCE_FIP}"
PARAMS="${PARAMS} --parameters PublicLbFip=${PUBLIC_LB_FIP}"


# count number of compute nodes
COMPUTE_NODES_COUNT=0
for node in `echo ${NODES} | sed 's/,/ /g'`; do
    case ${node} in
        compute*|allinone) COMPUTE_NODES_COUNT=$((${COMPUTE_NODES_COUNT}+1));;
    esac
done


log "check keystone authentication"
. ${HOME}/keystonerc

for CMD in \
	"nova list" \
	"neutron net-list" \
	"cinder list" \
	"glance image-list" \
	"heat stack-list" \
	"designate domain-list" \
	; do
		log "wait for `echo ${CMD} | awk '{ print \$1; }'` to be available"

		while ! ${CMD} >/dev/null 2>&1; do
			echo "failed, will attempt again ..."
			sleep 1
		done
done


log "wait for all hypervisors to be connected (need ${COMPUTE_NODES_COUNT})"
HYPERVISORS_UP=0
while [ "${HYPERVISORS_UP}" -ne "${COMPUTE_NODES_COUNT}" ]; do
	HYPERVISORS_UP=`openstack hypervisor list -f csv 2>/dev/null | awk -F '[,"\.]+' '/[0-9]+,/ { print $2; }' 2>/dev/null | wc -l`
	echo "currently running hypervisors: ${HYPERVISORS_UP}"
	sleep 1
done

log "wait for all VMs to be in running state"
while nova list | grep ${STACK_NAME}_ | grep --quiet -vw Running; do
	echo "failed, will attempt again ..."
	sleep 1
done


log "wait for floating IP to be pingable"

while ! ping -c1 ${PUBLIC_INSTANCE_FIP} >/dev/null 2>&1; do
	echo "failed, will attempt again ..."
	sleep 1
done


START=`get_timestamp_ms`

log "resolve instance's DNS address"

if ! host instance.${HEAT_DOMAIN} 127.0.0.1; then
	fatal "failed to resolve instance domain name"
fi


log "retrieve scale up/down URLs"

scaleup_url=`heat output-show ${STACK_NAME} scaleup_url 2>/dev/null | sed 's/"//g'`
scaledown_url=`heat output-show ${STACK_NAME} scaledown_url 2>/dev/null | sed 's/"//g'`

if [ -z "$scaleup_url" -o -z "$scaledown_url" ]; then
	fatal "failed to get scaling URLs"
fi


log "wait for 1 autoscaled instance to ready accessible through SSH"
COUNT=1
while [ ${COUNT} -ne 0 ]; do
	COUNT=1

	for instance_ip in `openstack server list 2>/dev/null | sed -r 's/.*validate_autoscaled_instance.*validate_tenant_net=([0-9\.]+).*$/\1/;tx;d;:x'`; do
		if ssh -o ProxyCommand="ssh -W %h:%p cirros@${PUBLIC_INSTANCE_FIP}" cirros@${instance_ip} true >/dev/null 2>&1; then
			COUNT=$((COUNT-1))
		fi
	done

	echo "${COUNT} instance(s) left"
	sleep 1
done

log "trigger ASG scale up"

running_asg_instances=`openstack server list --name validate_autoscaled_instance | grep -w ACTIVE | wc -l`

if [ "$running_asg_instances" -ne 1 ]; then
	fatal "we should only have 1 'validate_autoscaled_instance' instance running (current count is $running_asg_instances)"
fi

curl --fail --silent -X POST ${scaleup_url}

timeout=30
running_asg_instances=1

while [ "${running_asg_instances}" -ne 2 ]; do
	echo "waiting for instance to appear ..."
	running_asg_instances=`openstack server list --name validate_autoscaled_instance | grep -w ACTIVE | wc -l`
	sleep 1
	timeout=$((timeout-1))

	if [ "${timeout}" = 0 ]; then
		fatal "timeout while waiting for ASG to scale up"
	fi
done


log "wait for 2 autoscaled instance to ready accessible through SSH"
COUNT=2
while [ ${COUNT} -ne 0 ]; do
	COUNT=2

	for instance_ip in `openstack server list 2>/dev/null | sed -r 's/.*validate_autoscaled_instance.*validate_tenant_net=([0-9\.]+).*$/\1/;tx;d;:x'`; do
		if ssh -o ProxyCommand="ssh -W %h:%p cirros@${PUBLIC_INSTANCE_FIP}" cirros@${instance_ip} true >/dev/null 2>&1; then
			COUNT=$((COUNT-1))
		fi
	done

	echo "${COUNT} instance(s) left"
	sleep 1
done


log "trigger ASG scale down"

curl --fail --silent -X POST ${scaledown_url}

timeout=30
running_asg_instances=2

while [ "${running_asg_instances}" -ne 1 ]; do
	echo "waiting for instance to disappear ..."
	running_asg_instances=`openstack server list --name validate_autoscaled_instance | grep -w ACTIVE | wc -l`
	sleep 1
	timeout=$((timeout-1))

	if [ "${timeout}" = 0 ]; then
		fatal "timeout while waiting for ASG to scale down"
	fi
done


log "testing live migration"

VMNAME=validate_single_instance

if [ ${COMPUTE_NODES_COUNT} -gt 1 ]; then
	HOST_OLD=`nova show ${VMNAME} | awk '/OS-EXT-SRV-ATTR:host/ { print $4; }'`

	echo "virtual machine ${VMNAME} is currently on host ${HOST_OLD}"

	echo "starting live migration ..."
	nova live-migration validate_single_instance

	STATUS=NONE
	while [ "${STATUS}" != "ACTIVE" ]; do
		STATUS=`nova show ${VMNAME} | awk '/\| status/ { print $4; }'`
		echo "migration status is ${STATUS}"
		sleep .5
	done

	HOST_NEW=`nova show ${VMNAME} | awk '/OS-EXT-SRV-ATTR:host/ { print $4; }'`

	if [ "${HOST_OLD}" = "${HOST_NEW}" ]; then
		fatal "New host and old host are the same"
	fi

	echo "virtual machine ${VMNAME} has been migrated to host ${HOST_NEW}"

else
	warn "skipping live migration check as we only have ${COMPUTE_NODES_COUNT} compute node"
fi


END=`get_timestamp_ms`

notify "Stack validation done in $((END-START))ms"
