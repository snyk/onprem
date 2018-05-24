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

SNYK_UI_URL=`minikube service --namespace=$APP_NAMESPACE web --url`
echo "(*) Replicated console at: $REPLICATED_UI_URL"

# start app
# echo "[+] Start Snyk app"
# replicatedctl app start
echo "[+] Waiting for app to start"
wait_until "replicatedctl app status inspect | jq -r '.[].State'" "started"

APP_NAMESPACE=`kubectl get namespace -o jsonpath='{.items[-1:].metadata.name}'`
echo "(*) App's namespace: $APP_NAMESPACE"

REPLICATED_UI_URL=`minikube service replicated-ui --url`
echo "(*) Snyk console at: $SNYK_UI_URL"
echo "(!) Don't forget to confiure app hostname at the settings page!"
