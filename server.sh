#! /bin/bash

mkdir -p /root/.ssh
echo "$CLUSTER_KEY" | tr "%" "\n" > /root/.ssh/id_rsa
echo "$CLUSTER_PUBKEY" | tr "%" "\n" > /root/.ssh/id_rsa.pub
echo "$CLUSTER_PUBKEY" | tr "%" "\n" > /root/.ssh/authorized_keys
echo "* $(cat /etc/ssh/ssh_host_ecdsa_key.pub)" > /root/.ssh/known_hosts

export | grep CLUSTER_ > /root/.clusterenv

chmod go-rwx /root/.ssh/id_rsa

exec /usr/sbin/sshd -D
