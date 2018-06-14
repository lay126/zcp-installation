#!/bin/bash

echo -e "Please select number you want to install."
echo "1. All"
echo "2. Registry"
echo "3. Catalog"

echo -e "Insert a number: \c "
read number

if [ $number == 2  -o  $number == 1 ]
then
  echo "Start ZCP Registry installation..."

  kubectl create -f zcp-registry/adminserver-pvc.yaml \
  --namespace "$namespace"
  kubectl create -f zcp-registry/mysql-pvc.yaml \
  --namespace "$namespace"
  kubectl create -f zcp-registry/psql-pvc.yaml \
  --namespace "$namespace"

  registry_crt=$(kubectl get secret "$tls_secret" \
  --namespace "$namespace" \
  -o jsonpath="{.data.tls\.crt}" | base64 --decode)

  registry_key=$(kubectl get secret "$tls_secret" \
  --namespace "$namespace" \
  -o jsonpath="{.data.tls\.key}" | base64 --decode)

  zcp_admin_service_account_secret=$(kubectl get sa "$zcp_admin_service_account" \
  --namespace "$namespace" \
  -o jsonpath="{.secrets[0].name}")

  helm install --name zcp-registry zcp/zcp-registry \
    --namespace "$namespace" \
    -f zcp-registry/values.yaml \
    --set externalDomain="${registry_sub_domain}.${domain}" \
    --set tlsCrt="$registry_crt" \
    --set tlsKey="$registry_key" \
    --set adminserver.adminPassword="${registry_admin_pwd}" \
    --set adminserver.emailPwd="${smtp_pwd}" \
    --set registry.objectStorage.s3.region="${s3_region}" \
    --set registry.objectStorage.s3.regionendpoint="${s3_public_endpoint}" \
    --set registry.objectStorage.s3.accesskey="${s3_accesskey}" \
    --set registry.objectStorage.s3.secretkey="${s3_secretkey}" \
    --set registry.objectStorage.s3.bucket="${registry_s3_bucket}" \
    --set backup.serviceAccount="${zcp_admin_service_account}" \
    --set backup.serviceAccountSecretName="${zcp_admin_service_account_secret}" \
    --set backup.objectStorage.s3.regionendpoint="${s3_private_endpoint}" \
    --set backup.objectStorage.s3.accesskey="${s3_accesskey}" \
    --set backup.objectStorage.s3.secretkey="${s3_secretkey}" \
    --set backup.objectStorage.s3.bucket="${backup_s3_bucket}"

  echo "End ZCP Registry installation."
fi

if [ $number == 3  -o  $number == 1 ]
then
  echo "Start ZCP Catalog installation..."

  kubectl create -f zcp-catalog/zcp-catalog-mongodb-pvc.yaml \
  --namespace "$namespace"

  helm install --name zcp-catalog zcp/zcp-catalog \
    --namespace "$namespace" \
    -f zcp-catalog/values-zcp-catalog.yaml

  helm install --name zcp-sso-for-catalog zcp/zcp-sso \
    --namespace "$namespace" \
    -f zcp-catalog/values-zcp-sso.yaml \
    --set ingress.hosts[0]="${catalog_sub_domain}.${domain}" \
    --set ingress.tls[0].secretName="${tls_secret}" \
    --set ingress.tls[0].hosts[0]="${catalog_sub_domain}.${domain}" \
    --set configmap.realmPublicKey="${realm_publicKey}" \
    --set configmap.authServerUrl="${auth_url}" \
    --set configmap.secret="${catalog_client_secret}"


  echo "End ZCP Catalog installation."
fi
