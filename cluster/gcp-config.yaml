export NAME="$(whoami)-$RANDOM"

gcloud container clusters create "${NAME}" \
 --node-taints node.cilium.io/agent-not-ready=true:NoExecute \
 --zone us-west2-a
gcloud container clusters get-credentials "${NAME}" --zone us-west2-a
