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
rm snapshots.zip
 
echo "Locating www folder ..."
 
VULN_WWW_NAMESPACE=($(kubectl get po --all-namespaces | grep -i vulndb-nginx | awk '{print $1}'))
VULN_WWW_POD=($(kubectl get po --all-namespaces | grep -i vulndb-nginx | awk '{print $2}'))


for i in "${VULN_WWW_POD[@]}"
do
echo "Copying new files to $i in namespace ${VULN_WWW_NAMESPACE[0]}"

    kubectl cp VERSION "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp vulns.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp maven-licenses.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp npm-licenses.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp rubygems-licenses.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp os-vulns.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
    kubectl cp pip-licenses.json "${VULN_WWW_NAMESPACE[0]}/$i:/var/www/"
done



echo "Cleaning up temporary files"
rm *.json
rm VERSION
 
echo "Done!"