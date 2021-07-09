FROM alpine:latest

# set labels for metadata
LABEL maintainer="Teo Cheng Lim<teochenglim@gmail.com>" \
  name="k8s-vwh-debug" \
  description="A Kubernetes validating webhook server debugger" \
  summary="A Kubernetes validating webhook server debugger"

# set environment variables
ENV VWH=/usr/local/bin/k8s-vwh-debug \
  USER_UID=1001 \
  USER_NAME=k8s-vwh-debug

# install sidecar-injector binary
COPY build/_output/linux/bin/k8s-vwh-debug ${VWH}
RUN apk add --no-cache curl

# set entrypoint
ENTRYPOINT ["/usr/local/bin/k8s-vwh-debug"]

# switch to non-root user
USER ${USER_UID}
