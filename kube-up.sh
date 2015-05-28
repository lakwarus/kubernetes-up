#!/bin/bash

set -e

IMG_K8SETCD=gcr.io/google_containers/etcd:2.0.9
IMG_HYPERKUBE=gcr.io/google_containers/hyperkube:v0.17.0
IMG_SKYETCD=quay.io/coreos/etcd:v2.0.9
IMG_KUBE2SKY=gcr.io/google_containers/kube2sky:1.7
IMG_SKYDNS=gcr.io/google_containers/skydns:2015-03-11-001

echo "Pulling images..."
echo
docker pull $IMG_K8SETCD
echo
docker pull $IMG_HYPERKUBE
echo
docker pull $IMG_SKYETCD
echo
docker pull $IMG_KUBE2SKY
echo
docker pull $IMG_SKYDNS

echo
echo -n "Starting etcd    "
docker run --net=host -d \
  $IMG_K8SETCD \
  /usr/local/bin/etcd \
  --addr=127.0.0.1:4001 \
  --bind-addr=0.0.0.0:4001 \
  --data-dir=/var/etcd/data >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Starting k8s     "
docker run --net=host -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v `pwd`/hyperkube-manifests:/etc/kubernetes/manifests:ro \
  $IMG_HYPERKUBE \
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

echo -n "Starting proxy   "
docker run --net=host -d \
  --privileged \
  $IMG_HYPERKUBE \
  /hyperkube proxy \
  --master=http://127.0.0.1:8080 \
  --v=2 >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Waiting for API  "
while [ 1 ]
do
  sleep 1
  if curl -m1 http://10.0.0.1/api/v1beta3/namespaces/default/pods >/dev/null 2>&1
  then
    break
  fi
done
echo -e "\e[32mOK\e[39m"

echo -n "Starting skydns  "
./kubectl create -f kube-dns.rc.yaml >/dev/null
./kubectl create -f kube-dns.service.yaml >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Verifying skydns "
while [ 1 ]
do
  sleep 1
  if nslookup google.com 10.0.0.10 >/dev/null 2>&1
  then
    break
  fi
done
echo -e "\e[32mOK\e[39m"
