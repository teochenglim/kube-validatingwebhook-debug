0. compile and push

```shell
make image

```

## Deploy

1. Create namespace or use default namespace

```
$ export NAMESPACE=default
### if it is not default create the namespace and export it
$ kubectl create ns $NAMESPACE
### verify the namespace is correct
$ echo ${NAMESPACE}
$ kubectl get ns/${NAMESPACE}
```

2. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed by validatingwebhook debug deployment:

```
$ ./deploy/webhook-create-signed-cert.sh

### verify secret is created with data.'cert.pem' and data.'key.pem'
$ kubectl get secret/vwh-debug -o yaml
```

3. Deploy resources:

```
### create the deployment
$ kubectl apply -f deploy/
### delete the deployment
$ kubectl delete -f deploy/
```

4. create a test secrets

```shell
$ kubectl create secret generic prod-db-secret --from-literal=username=produser --from-literal=password=Y4nys7f11
secret/prod-db-secret created

```

5. Verify the secret is at debug

```shell
$ kubectl get pod
$ kubectl logs pod/vwh-debug-745bbcb847-n2mbf -f
I0709 05:20:21.893180       1 main.go:55] Server running listening in port: 443
I0709 05:20:35.005106       1 webhook.go:31] Received request
I0709 05:20:35.005857       1 webhook.go:46] Raw Object: {"kind":"Secret","apiVersion":"v1","metadata":{"name":"prod-db-secret","namespace":"default","uid":"d71f2320-c2c0-4f13-9b2c-ce7d08c8ef96","creationTimestamp":"2021-07-09T05:20:34Z","managedFields":[{"manager":"kubectl-create","operation":"Update","apiVersion":"v1","time":"2021-07-09T05:20:34Z","fieldsType":"FieldsV1","fieldsV1":{"f:data":{".":{},"f:password":{},"f:username":{}},"f:type":{}}}]},"data":{"password":"WTRueXM3ZjEx","username":"cHJvZHVzZXI="},"type":"Opaque"}
I0709 05:20:35.017047       1 webhook.go:70] Ready to write reponse ...
I0709 05:20:46.441326       1 webhook.go:31] Received request
I0709 05:20:46.441449       1 webhook.go:46] Raw Object: {"kind":"Secret","apiVersion":"v1","metadata":{"name":"prod-db-secret","namespace":"default","uid":"cf64117f-4eef-41cc-a71b-6d3ba7b568ff","creationTimestamp":"2021-07-09T05:20:46Z","managedFields":[{"manager":"kubectl-create","operation":"Update","apiVersion":"v1","time":"2021-07-09T05:20:46Z","fieldsType":"FieldsV1","fieldsV1":{"f:data":{".":{},"f:password":{},"f:username":{}},"f:type":{}}}]},"data":{"password":"WTRueXM3ZjEx","username":"cHJvZHVzZXI="},"type":"Opaque"}
I0709 05:20:46.441854       1 webhook.go:70] Ready to write reponse ...
^C

```
