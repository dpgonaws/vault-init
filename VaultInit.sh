#!/bin/sh

# Read options and corresponding values
while getopts "n:v:" option; do
   case "$option" in
       n) NAMESPACE=${OPTARG};;
       v) VAULT_NAME=${OPTARG};;
   esac
done


#echo -e "\nKubectl namespace creation\n"
#kubectl create namespace $NAMESPACE


#echo -e "\nVault helm installation\n"

#helm install $VAULT_NAME hashicorp/vault --version 0.24.0 --values helm-vault-raft-values.yml -n $NAMESPACE --wait --timeout 120s


echo -e "\nChecking vault pod status\n"
helm status $VAULT_NAME -n $NAMESPACE


# Wait until the deployment is complete
until helm status "$VAULT_NAME" -n $NAMESPACE  | grep "STATUS: deployed"; do
  echo "Waiting for deployment to complete..."
  sleep 1
done
# The deployment is complete
echo "Deployment complete!"



#until false
#do
 # If there are other pods running in the namespace wll thsi help?
 #   if [[ $(kubectl get pods -n $NAMESPACE | grep "Running" | wc -l) -eq 2 ]]
 #   then

 #       echo -e "Container running succesfully"
 #       break
 #   else

#        echo "Waiting for container to be running"
#        sleep 2
#        continue
#    fi
#done

# ####################### VAULT CONFIGURATION AFTER INSTALL ################################
echo -e "\nChecking vault status\n"
kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault status

echo -e "Vault is getting Initialized\n\n"
kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-keys.json
#echo -e "VI. Show unsealkeys"

#cat vault-keys.json | jq -r ".unseal_keys_b64[]"
echo -e "\nVault unseal key is getting set\n"

VAULT_UNSEAL_KEY=$(cat vault-keys.json | jq -r ".unseal_keys_b64[]")
echo -e "\nVault unseal key is set. This can be checked using \n echo '$'VAULT_UNSEAL_KEY\n"

echo -e "\nExecuting Vault Unseal operation\n"
kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY
#echo "***** vault unseal status"

#kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault status
echo -e "\nExtract vault root token\n\n"

CLUSTER_ROOT_TOKEN=$(cat vault-keys.json | jq -r ".root_token")

echo -e "\nVault Root token is set. This can be checked using \n echo '$'CLUSTER_ROOT_TOKEN"
echo -e "\nAuthenticate vaultt\n"

kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault login $CLUSTER_ROOT_TOKEN
#echo "V. Vault Init"

kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault operator raft list-peers

kubectl exec $VAULT_NAME-1 -n $NAMESPACE -- vault operator raft join http://$VAULT_NAME-0.$VAULT_NAME-internal:8200

kubectl exec $VAULT_NAME-1 -n $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec $VAULT_NAME-1 -n $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec $VAULT_NAME-2 -n $NAMESPACE -- vault operator raft join http://$VAULT_NAME-0.$VAULT_NAME-internal:8200

kubectl exec $VAULT_NAME-2 -n $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec $VAULT_NAME-2 -n $NAMESPACE -- vault operator unseal $VAULT_UNSEAL_KEY

kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault operator raft list-peers


#kubectl exec --stdin=true --tty=true $VAULT_NAME-0 -n $NAMESPACE -- /bin/sh
echo -e "\nSet vault enable kubernetes\n"

kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault auth enable kubernetes
echo -e "\nvault set secret path\n"

kubectl exec $VAULT_NAME-0 -n $NAMESPACE -- vault secrets enable -path=kv kv-v2

echo -e "\nVault setup completed successfully!!!"

