#!/usr/bin/env bash

print_usage() {
    read -r -d '' help <<-EOF_HELP || true
Usage:
    $( basename $0)
    $( basename $0)  -h|--help

Options:
    --update-images             Download images, glance image-create, and use the results

Useful Environment:
    IMAGE_BASE_URL
    INSTALLSERVER_IMAGE_FILE_NAME
    OPENSTACKFULL_IMAGE_FILE_NAME
    CREDENTIALS_FILE

EOF_HELP

    echo -e "$help"
    return 0
}

update_images() {
    echo $IMAGE_BASE_URL
    echo $INSTALLSERVER_IMAGE_FILE_NAME
    echo $OPENSTACKFULL_IMAGE_FILE_NAME

    curl -O ${IMAGE_BASE_URL}/$INSTALLSERVER_IMAGE_FILE_NAME
    curl -O ${IMAGE_BASE_URL}/$OPENSTACKFULL_IMAGE_FILE_NAME

    IS_IMAGE_NAME=${OS_USERNAME}-${INSTALLSERVER_IMAGE_FILE_NAME}
    OS_IMAGE_NAME=${OS_USERNAME}-${OPENSTACKFULL_IMAGE_FILE_NAME}
    
    #these will fail if there are multiple images with the name
    glance image-delete $IS_IMAGE_NAME
    glance image-delete $OS_IMAGE_NAME

    glance image-create --name ${IS_IMAGE_NAME} --container-format bare \
       --disk-format raw --file ${INSTALLSERVER_IMAGE_FILE_NAME}
    glance image-create --name ${OS_IMAGE_NAME} --container-format bare \
       --disk-format raw --file ${OPENSTACKFULL_IMAGE_FILE_NAME}

    INSTALLSERVER_IMG_ID=`glance image-list --name $IS_IMAGE_NAME | grep $IS_IMAGE_NAME | awk '{print $2}' | head -n 1`
    OPENSTACKFULL_IMG_ID=`glance image-list --name $OS_IMAGE_NAME | grep $OS_IMAGE_NAME | awk '{print $2}' | head -n 1`
    
}

parse_args() {
    ### while there are args parse them
    while [[ -n "${1+xxx}" ]]; do
        case $1 in
        -h|--help)      SHOW_USAGE=true;   break ;;    # exit the loop
        --update-images)    UPDATE_IMAGES=true; shift ;;
        esac
    done
    return 0
}


main() {

    #source openstack credentials (OS_* vars) if they exist in this file
    CREDENTIALS_FILE=${CREDENTIALS_FILE:-/dev/null}
    source $CREDENTIALS_FILE

    SHOW_USAGE=false
    UPDATE_IMAGES=false

    parse_args "$@"

    $SHOW_USAGE && print_usage

    IMAGE_BASE_URL=${IMAGE_BASE_URL:-file:///}
    INSTALLSERVER_IMAGE_FILE_NAME=${INSTALLSERVER_IMAGE_FILE_NAME:-foobar}
    OPENSTACKFULL_IMAGE_FILE_NAME=${OPENSTACKFULL_IMAGE_FILE_NAME:-foobaz}
    INSTALLSERVER_IMG_ID=0869dceb-3427-445c-90f9-c7b724b984f3
    OPENSTACKFULL_IMG_ID=b8a9eb16-d2d5-4012-a902-cec50fffde47

    $UPDATE_IMAGES && update_images

    INSTANCE_PREFIX=spinalbash-
    INSTALLSERVER_INSTANCE_NAME_BASE=installserver
    OPENSTACKFULL_INSTANCE_NAME_BASE=openstack

    IS_NAME=${INSTANCE_PREFIX}${INSTALLSERVER_INSTANCE_NAME_BASE}
    OS1_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-1
    OS2_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-2
    OS3_NAME=${INSTANCE_PREFIX}${OPENSTACKFULL_INSTANCE_NAME_BASE}-3

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


}

main "$@"


