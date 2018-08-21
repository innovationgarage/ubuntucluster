#! /bin/bash

source config.sh

SIZE=$1
PORT=$2
[ "$PORT" != "" ] || PORT=2223

CLUSTER=ubuntucluster_$PORT

rm $CLUSTER.sshkey $CLUSTER.sshkey.pub
ssh-keygen -t rsa -N "" -f $CLUSTER.sshkey
CLUSTER_KEY="$(tr "\n" "%" < $CLUSTER.sshkey)"
CLUSTER_PUBKEY="$(tr "\n" "%" < $CLUSTER.sshkey.pub)"

docker build --tag $REGISTRY/ubuntucluster:latest .
docker push $REGISTRY/ubuntucluster:latest 

NODES="n1$(for ((idx=2;idx<=SIZE;idx++)); do echo -n ",n$idx"; done)"
NODESLST="n1$(for ((idx=2;idx<=SIZE;idx++)); do echo -n " n$idx"; done)"

{
  cat <<EOF
version: "3"
services:
  n1:
    hostname: n1
    image: $REGISTRY/ubuntucluster:latest
    ports:
      - "$PORT:22"
    environment:
      CLUSTER_KEY: '$CLUSTER_KEY'
      CLUSTER_PUBKEY: '$CLUSTER_PUBKEY'
      CLUSTER_SIZE: '$SIZE'
      CLUSTER_PORT: '$PORT'
      CLUSTER_NODES: '$NODES'
      CLUSTER_NODESLST: '$NODESLST'
    volumes:
      - $DATADIR:/data
    networks:
      - $CLUSTER
EOF

  for ((IDX=2; IDX<=SIZE; IDX++)); do
    cat <<EOF
  n$IDX:
    hostname: n$IDX
    image: $REGISTRY/ubuntucluster:latest
    environment:
      CLUSTER_KEY: '$CLUSTER_KEY'
      CLUSTER_PUBKEY: '$CLUSTER_PUBKEY'
      CLUSTER_SIZE: '$SIZE'
      CLUSTER_PORT: '$PORT'
      CLUSTER_NODES: '$NODES'
      CLUSTER_NODESLST: '$NODESLST'
    volumes:
      - $DATADIR:/data
    networks:
      - $CLUSTER
EOF
  done

  cat <<EOF
networks:
  $CLUSTER:
EOF
} > docker-compose.yml

docker stack deploy -c docker-compose.yml $CLUSTER
