#! /bin/bash

source config.sh

argparse() {
    export ARGS=()
    for _ARG in "$@"; do
        if [ "${_ARG##--*}" == "" ]; then
            _ARG="${_ARG#--}"
            if [ "${_ARG%%*=*}" == "" ]; then
                _ARGVAL="${_ARG#*=}"
                _ARG="$(echo ${_ARG%=*} | tr - _)"
            else
                _ARGVAL=True
            fi
            _ARG="$(echo ${_ARG} | tr - _)"
            eval "export ARG_${_ARG}"='"${_ARGVAL}"'
        else
            ARGS+=($_ARG)
        fi
    done
}

[ "${ARG_ssh_port}" ] || export ARG_ssh_port=2223
[ "${ARG_data}" ] || export ARG_data=/data
[ "${ARG_clusterhost}" ] || export ARG_clusterhost=localhost
[ "${DOCKER_HOST}" ] && export ARG_dockerhost="${DOCKER_HOST}"

argparse "$@"

[ "${ARG_mountpoint}" ] || export ARG_mountpoint="${ARG_data}"
[ "${ARG_cluster}" ] || export ARG_cluster=ubuntucluster_${ARG_ssh_port}
[ "${ARG_dockerhost}" ] || export ARG_dockerhost=tcp://${ARG_clusterhost}:2375

export DOCKER_HOST="${ARG_dockerhost}"

[ "$ARG_size" ] || {
  cat <<EOF
Usage: deploy.sh --size=SIZE [OPTIONS]

Available options:

    --ssh-port=${ARG_ssh_port}
    --cluster=${ARG_cluster}
    --ports=PORT,PORT,...

    --dryrun

    --docker-in-docker

    --data=${ARG_data}
    --mountpoint=${ARG_mountpoint}

    --cmd=SHELL_COMMAND
      Set up the clusters, run the specified shell command on the
      first node and then bring the cluster down again.

      Tip: You can run parallel jobs on all nodes using the program
      "parallel".

    --clusterhost=${ARG_clusterhost}
    --dockerhost=${DOCKER_HOST}

EOF
  exit 1
}

{
    rm ${ARG_cluster}.sshkey ${ARG_cluster}.sshkey.pub
    ssh-keygen -t rsa -N "" -f ${ARG_cluster}.sshkey
} >&2

CLUSTER_KEY="$(tr "\n" "%" < ${ARG_cluster}.sshkey)"
CLUSTER_PUBKEY="$(tr "\n" "%" < ${ARG_cluster}.sshkey.pub)"

NODES="n1$(for ((idx=2;idx<=ARG_size;idx++)); do echo -n ",n$idx"; done)"
NODESLST="n1$(for ((idx=2;idx<=ARG_size;idx++)); do echo -n " n$idx"; done)"

{
  cat <<EOF
version: "3"
services:
EOF
  
  for ((IDX=1; IDX<=ARG_size; IDX++)); do
    cat <<EOF
  n$IDX:
    hostname: n${IDX}
    image: ${ARG_registry}/ubuntucluster:latest
    environment:
      CLUSTER_SIZE: '${ARG_size}'
      CLUSTER_PORT: '${ARG_ssh_port}'
      CLUSTER_KEY: '${CLUSTER_KEY}'
      CLUSTER_PUBKEY: '${CLUSTER_PUBKEY}'
      CLUSTER_NODES: '${NODES}'
      CLUSTER_NODESLST: '${NODESLST}'
    networks:
      - ${ARG_cluster}
    volumes:
      - ${ARG_data}:${ARG_mountpoint}
EOF
    
    if [ "${ARG_docker_in_docker}" ]; then
        cat <<EOF
      - /var/run/docker.sock:/var/run/docker.sock
EOF
    fi

    if [ "$IDX" == "1" ]; then
        cat <<EOF
    ports:
      - "${ARG_ssh_port}:22"
EOF
        for port in $(echo "${ARG_ports}" | tr , " "); do
            cat <<EOF
      - "${port}"
EOF
        done
    fi
  done

  cat <<EOF
networks:
  ${ARG_cluster}:
EOF
} > docker-compose.yml

if [ "${ARG_dryrun}" ]; then
    export | grep ARG_
else
    {
        docker build --tag "$ARG_registry/ubuntucluster:latest" .
        docker push "$ARG_registry/ubuntucluster:latest" 
        docker stack deploy -c docker-compose.yml "${ARG_cluster}"
    } >&2
    
    if [ "${ARG_cmd}" ]; then
        echo "Waiting for sshd to start in first node..." >&2
        while ! ssh -o StrictHostKeyChecking=no -p "${ARG_ssh_port}" -i "${ARG_cluster}.sshkey" "root@${ARG_clusterhost}" "hostname" > /dev/null 2>&1; do : ; done
        ssh -o StrictHostKeyChecking=no -p "${ARG_ssh_port}" -i "${ARG_cluster}.sshkey" "root@${ARG_clusterhost}" "${ARG_cmd}"
        docker stack rm "${ARG_cluster}" >&2
    fi
fi
