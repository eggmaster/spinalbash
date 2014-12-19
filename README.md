spinalbash
==========

Note: this script does destructive things, like `nova delete`, so read the source before you pull the trigger. You have been warned.

Hacky little script to spin up some instances in openstack, associate floating ips, and spit out config suitable for use as 'hosts' settings for ansible-spinalstack install.

If you call it as 'spinalbash.sh --update-images' it will attempt to download images defined in env vars (see following), glance upload them to your tenant, and use them for creating the required instances.

Environment Variables
---------------------

Please set

IMAGE_BASE_URL=http://hostname/path/to/images #dir where your images are located  
INSTALLSERVER_IMAGE_FILE_NAME=installserver-version-blabla.img #raw image for installserver  
OPENSTACKFULL_IMAGE_FILE_NAME=openstackfull-version-blabla.img #raw image for openstackfull image  
CREDENTIALS_FILE=/path/to/your/openstack/credentials

Note CREDENTIALS_FILE should define:  
OS_AUTH_URL  
OS_USERNAME  
OS_TENANT_NAME  
OS_PASSWORD  

Or just set CREDENTIALS_FILE to /dev/null and define the OS_ vars in your environment.
