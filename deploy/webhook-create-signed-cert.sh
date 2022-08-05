#!/bin/bash

set -e

usage() {
    cat <<EOF
Generate certificate suitable for use with an sidecar-injector webhook service.

This script uses k8s' CertificateSigningRequest API to a generate a
certificate signed by k8s CA suitable for use with sidecar-injector webhook
services. This requires permissions to create and approve CSR. See
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster for
detailed explanation and additional instructions.

The server key/cert k8s CA cert are stored in a k8s SECRET.

usage: ${0} [OPTIONS]

The following flags are required.

       --service          service name of webhook.
       --namespace        namespace where webhook service and SECRET reside.
       --secret           secret name for CA certificate and server certificate/key pair.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            SERVICE="$2"
            shift
            ;;
        --secret)
            SECRET="$2"
            shift
            ;;
        --namespace)
            NAMESPACE="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

[ -z "${SERVICE}" ] && SERVICE=vwh-debug
[ -z "${SECRET}" ] && SECRET=vwh-debug
[ -z "${NAMESPACE}" ] && NAMESPACE=default

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

export csrName=${SERVICE}.${NAMESPACE}
# tmpdir=$(mktemp -d)
tmpdir=./temp
echo "creating certs in tmpdir ${tmpdir} "

cat <<EOF > "${tmpdir}"/csr.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
EOF

cat <<EOF > "${tmpdir}"/csr.conf
[ req ]
distinguished_name = dn
req_extensions = req_ext

[ dn ]
commonName = ${ENDPOINT}

[ req_ext ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVICE}
DNS.2 = ${SERVICE}.${NAMESPACE}
DNS.3 = ${SERVICE}.${NAMESPACE}.svc
DNS.4 = ${SERVICE}.${NAMESPACE}.svc.cluster.local
EOF


openssl genrsa -out "${tmpdir}"/server-key.pem 2048
openssl req -new -key "${tmpdir}"/server-key.pem -subj "/CN=${SERVICE}.${NAMESPACE}.svc" -out "${tmpdir}"/server.csr -config "${tmpdir}"/csr.conf

# clean-up any previously created CSR for our service. Ignore errors if not present.
kubectl delete csr ${csrName} 2>/dev/null || true

# create  server cert/key CSR and  send to k8s API
cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${csrName}
spec:
  groups:
  - system:authenticated
  request: $(< "${tmpdir}"/server.csr base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

# verify CSR has been created
while true; do
    if kubectl get csr ${csrName}; then
        break
    else
        sleep 1
    fi
done

# approve and fetch the signed certificate
kubectl certificate approve ${csrName}
# verify certificate has been signed
for _ in $(seq 10); do
    serverCert=$(kubectl get csr ${csrName} -o jsonpath='{.status.certificate}')
    if [[ ${serverCert} != '' ]]; then
        break
    fi
    sleep 1
done
if [[ ${serverCert} == '' ]]; then
    echo "ERROR: After approving csr ${csrName}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
    exit 1
fi
echo "${serverCert}" | base64 -d > "${tmpdir}"/server-cert.pem


# create the secret with CA cert and server cert/key
kubectl create secret generic ${SECRET} \
        --from-file=key.pem="${tmpdir}"/server-key.pem \
        --from-file=cert.pem="${tmpdir}"/server-cert.pem \
        --dry-run=client -o yaml |
    kubectl -n ${NAMESPACE} apply -f -

cat deploy/validatingwebhook.yaml.in | \
    deploy/webhook-patch-ca-bundle.sh > \
    deploy/validatingwebhook.yaml
cat deploy/deployment.yaml.in | \
    deploy/webhook-patch-ca-bundle.sh > \
    deploy/deployment.yaml
cat deploy/service.yaml.in | \
    deploy/webhook-patch-ca-bundle.sh > \
    deploy/service.yaml