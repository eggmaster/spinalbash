#!/bin/bash

CREDENTIALS=/home/slinaber/openstack/slinaber-creds
INSTALLSERVER_IMG_ID=0869dceb-3427-445c-90f9-c7b724b984f3
OPENSTACKFULL_IMG_ID=b8a9eb16-d2d5-4012-a902-cec50fffde47
INSTANCE_PREFIX=eggs-
INSTALLSERVER_INSTANCE_NAME_BASE=installserver
OPENSTACKFULL_INSTANCE_NAME_BASE=openstack

IS_NAME=${INSTANCE_PREFIX}${INSTALLSERVER_INSTANCE_NAME_BASE}
OS1_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-1
OS2_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-2
OS3_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-3

source $CREDENTIALS

nova delete $IS_NAME $OS1_NAME $OS2_NAME $OS3_NAME

sleep 30

nova boot --image $INSTALLSERVER_IMG_ID --flavor m1.large --key-name eggs_qeos $IS_NAME
nova boot --image $OPENSTACKFULL_IMG_ID --flavor m1.large --key-name eggs_qeos $OS1_NAME
nova boot --image $OPENSTACKFULL_IMG_ID --flavor m1.large --key-name eggs_qeos $OS2_NAME
nova boot --image $OPENSTACKFULL_IMG_ID --flavor m1.large --key-name eggs_qeos $OS3_NAME

SLEEP_COUNT="0"
TARGET_STATE=ACTIVE
MAX_TRIES=40
for instance in $IS_NAME $OS1_NAME $OS2_NAME $OS3_NAME ; do
    while [ $SLEEP_COUNT -lt $MAX_TRIES ]; do
	(( SLEEP_COUNT+=1 ))
	if [ $SLEEP_COUNT -eq $MAX_TRIES ]; then
	    echo "max sleep exceeded waiting for ACTIVE instances"
	    nova list
	    exit 1
	fi
	if [ `nova list | grep ${instance} | grep ${TARGET_STATE} | wc -l` -gt 0 ]; then
	    echo "${instance} is ACTIVE"
	    break
	else
	    echo "${instance} is not ACTIVE"
	fi
	sleep 10
    done
done

names=( $IS_NAME $OS1_NAME $OS2_NAME $OS3_NAME )
hosts=( installserver openstack1 openstack2 openstack3 )
for index in 0 1 2 3 ; do
    FIP=`nova floating-ip-create | grep public | awk '{print $2}'`
    echo "${FIP} ${hosts[$index]}.example.com ${hosts[$index]}"
    nova floating-ip-associate ${names[$index]} $FIP
done

echo "127.0.0.1 localhost.example.com localhost"
