#!/bin/bash

set -e

echo "Pulling images..."
echo
docker pull kubernetes/etcd:2.0.5.1
echo
docker pull gcr.io/google_containers/hyperkube:v0.14.2
echo
docker pull quay.io/coreos/etcd:v2.0.3
echo
docker pull gcr.io/google_containers/kube2sky:1.2
echo
docker pull gcr.io/google_containers/skydns:2015-03-11-001
echo
docker pull nginx
echo
docker pull ubuntu

echo
echo -n "Starting etcd   "
docker run --net=host -d \
  kubernetes/etcd:2.0.5.1 \
  /usr/local/bin/etcd \
  --addr=127.0.0.1:4001 \
  --bind-addr=0.0.0.0:4001 \
  --data-dir=/var/etcd/data >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Starting k8s    "
docker run --net=host -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gcr.io/google_containers/hyperkube:v0.14.2 \
  /hyperkube kubelet \
  --api_servers=http://localhost:8080 \
  --v=2 \
  --address=0.0.0.0 \
  --enable_server \
  --hostname_override=127.0.0.1 \
  --config=/etc/kubernetes/manifests \
  --cluster_dns=10.0.0.10 \
  --cluster_domain=kubernetes.local >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Starting proxy  "
docker run --net=host -d \
  --privileged \
  gcr.io/google_containers/hyperkube:v0.14.2 \
  /hyperkube proxy \
  --master=http://127.0.0.1:8080 \
  --v=2 >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Waiting for API "
while [ 1 ]
do
  sleep 1
  NODES=`./kubectl get nodes 2>&1 | grep Ready || true`
  if [ -n "$NODES" ]
  then
    break
  fi
done
echo -e "\e[32mOK\e[39m"

echo -n "Starting skydns "
./kubectl create -f kube-dns.rc.yaml >/dev/null
./kubectl create -f kube-dns.service.yaml >/dev/null
echo -e "\e[32mOK\e[39m"
