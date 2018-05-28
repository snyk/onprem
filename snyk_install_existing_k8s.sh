#!/usr/bin/env sh
set -e

replicatedctl () {
    kubectl exec -it "$(kubectl get pods -l=app=replicated -l=tier=master -o=jsonpath='{.items..metadata.name}')" -c replicated -it -- replicatedctl $*
}

wait_until () {
    local res=$(eval "$1")
    until [ "$res" = "$2" ]; do
        echo "waiting for \"$1\" to return \"$2\" (now \"$res\")..."
        sleep 1
        res=$(eval "$1")
    done
}

usage() {
cat <<EOF
Usage: ${0##*/} <replicated-console-password> <license-file.rli>
EOF
exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

REPLICATED_CONSOLE_PASSWORD="$1"
REPLICATED_LICENSE_FILE="$2"

echo "[+] Getting Replicated yaml"
curl -sSL "https://get.replicated.com/kubernetes-yml-generate?service_type=LoadBalancer&storage_class=standard&storage_provisioner=0" | bash > replicated.yml

echo "[+] Installing Replicated"
kubectl apply -f replicated.yml

echo "[+] Waiting for replicated pod"
wait_until "kubectl get pods -l=app=replicated -l=tier=master -o=jsonpath='{.items..status.phase}'" "Running"

# cert file for console-ui? maybe in replicated-ui container?

# create a password for the console-ui
echo "[+] Setting password for replicated console ui"
cat <<EOF | replicatedctl console-auth import
{
    "Anonymous": null,
    "Password": {
        "Password": "$REPLICATED_CONSOLE_PASSWORD"
    },
    "LDAP": null,
    "LDAPAdvanced": null
}
EOF

# apply app's license
echo "[+] Installing Snyk's license into replicated"
replicatedctl license-load < $REPLICATED_LICENSE_FILE

REPLICATED_UI_IP=`kubectl get svc replicated-ui | awk '{print $4}' | tail -n 1;`
REPLICATE_UI_PORT=8800
REPLICATED_UI_URL=${REPLICATED_UI_IP}:${REPLICATE_UI_PORT}

echo "(*) Replicated console at: $REPLICATED_UI_URL"

# start app
# echo "[+] Start Snyk app"
# replicatedctl app start
echo "[+] Waiting for app to start"
wait_until "replicatedctl app status inspect | jq -r '.[].State'" "started"

APP_NAMESPACE=`kubectl get namespace -o jsonpath='{.items[-1:].metadata.name}'`
echo "(*) App's namespace: $APP_NAMESPACE"

SNYK_APP_HOST=`kubectl get no -o wide | awk '{print $6}' | tail -n 1`
SNYK_DEFAULT_APP_PORT=30443
SNYK_APP_URL=${SNYK_APP_HOST}:${SNYK_DEFAULT_APP_PORT}

echo "[+] Stopping app"
replicatedctl app stop
echo "[+] Starting app"
replicatedctl app start
echo "[+] Waiting for app to start"
wait_until "replicatedctl app status inspect | jq -r '.[].State'" "started"

echo "(*) Snyk url: $SNYK_APP_URL"
echo "(!) Don't forget to confiure app hostname at the settings page!"
