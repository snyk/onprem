#!/bin/bash

if [ -z "$1" ]
then
    [ ! -s snapshots.zip ] && echo "ERROR: You must provide the snapshot archive in this folder or pass the download url along url as argument to the script" && exit 1;
else
    echo "Downloading the new snapshots"
    curl -f0 -o snapshots.zip $1
    [ ! -s snapshots.zip ] && echo "Download failed - check url" && exit 1;
fi

echo "Unzipping and removing downloaded zip file"

unzip snapshots.zip
rm -f snapshots.zip

echo "Locating www folder ..."

VULN_WWW_CONTAINER=($(sudo docker ps | grep -i vulndb-nginx | awk '{print $1}'))
echo "Copying new files to volume used by ${VULN_WWW_CONTAINER[0]}"

sudo docker cp VERSION "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp vulns.json "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp maven-licenses.json "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp npm-licenses.json "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp rubygems-licenses.json "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp os-vulns.json "${VULN_WWW_CONTAINER[0]}:/var/www/"
sudo docker cp pip-licenses.json "${VULN_WWW_CONTAINER[0]}:/var/www/"

echo "Cleaning up temporary files"
rm -f *.json
rm -f VERSION

echo "Done!"