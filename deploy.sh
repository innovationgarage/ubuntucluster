#! /bin/bash

source config.sh

argparse() {
    export ARGS=()
    for _ARG in "$@"; do
        if [ "${_ARG##--*}" == "" ]; then
            _ARG="${_ARG#--}"
            if [ "${_ARG%%*=*}" == "" ]; then
                _ARGNAME="$(echo ${_ARG%=*} | tr - _)"
                eval "export ARG_${_ARGNAME}"='"${_ARG#*=}"'
            else
                eval "export ARG_${_ARG}"='True'       
            fi
        else
            ARGS+=($_ARG)
        fi
    done
}

ARG_ssh_port=2223
argparse "$@"
[ "$ARG_size" ] || {
  cat <<EOF
Usage: deploy.sh --size=SIZE [OPTIONS]

Available options:

    --ssh-port=PORT
    --cluster=CLUSTER_NAME
    --ports=PORT,PORT,...
    --dryrun
EOF
  exit 1
}

[ "$ARG_cluster" ] || ARG_cluster=ubuntucluster_${ARG_ssh_port}

rm ${ARG_cluster}.sshkey ${ARG_cluster}.sshkey.pub
ssh-keygen -t rsa -N "" -f ${ARG_cluster}.sshkey
CLUSTER_KEY="$(tr "\n" "%" < ${ARG_cluster}.sshkey)"
CLUSTER_PUBKEY="$(tr "\n" "%" < ${ARG_cluster}.sshkey.pub)"

NODES="n1$(for ((idx=2;idx<=ARG_size;idx++)); do echo -n ",n$idx"; done)"
NODESLST="n1$(for ((idx=2;idx<=ARG_size;idx++)); do echo -n " n$idx"; done)"

PORTS=""
for port in $(echo "${ARG_ports}" | tr , " "); do
    PORTS="$PORTS
      - \"$port\""
done

{
  cat <<EOF
version: "3"
services:
  n1:
    hostname: n1
    image: $REGISTRY/ubuntucluster:latest
    ports:
      - "${ARG_ssh_port}:22"${PORTS}
    environment:
      CLUSTER_KEY: '${ARG_cluster}_KEY'
      CLUSTER_PUBKEY: '${ARG_cluster}_PUBKEY'
      CLUSTER_SIZE: '${ARG_size}'
      CLUSTER_PORT: '${ARG_ssh_port}'
      CLUSTER_NODES: '$NODES'
      CLUSTER_NODESLST: '$NODESLST'
    volumes:
      - $DATADIR:/data
    networks:
      - ${ARG_cluster}
EOF

  for ((IDX=2; IDX<=ARG_size; IDX++)); do
    cat <<EOF
  n$IDX:
    hostname: n$IDX
    image: $REGISTRY/ubuntucluster:latest
    environment:
      CLUSTER_KEY: '${ARG_cluster}_KEY'
      CLUSTER_PUBKEY: '${ARG_cluster}_PUBKEY'
      CLUSTER_SIZE: '${ARG_size}'
      CLUSTER_PORT: '${ARG_ssh_port}'
      CLUSTER_NODES: '$NODES'
      CLUSTER_NODESLST: '$NODESLST'
    volumes:
      - $DATADIR:/data
    networks:
      - ${ARG_cluster}
EOF
  done

  cat <<EOF
networks:
  ${ARG_cluster}:
EOF
} > docker-compose.yml

[ "${ARG_dryrun}" ] || {
    docker build --tag $REGISTRY/ubuntucluster:latest .
    docker push $REGISTRY/ubuntucluster:latest 
    docker stack deploy -c docker-compose.yml ${ARG_cluster}
}
