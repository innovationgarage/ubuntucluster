# Ubuntucluster

Ubuntucluster is a set of shellscripts that deploys a cluster of N
nodes running ubuntu and sshd on top of docker swarm. This is mainly
intended for running one-off semi simple pipelines e.g. using GNU
Parallel or GNU make. It supports bind mounting a data volume from the
hosts, assuming that you have set up a shared drive using e.g. NFS,
Ceph etc.

# To deploy a cluster

To deploy a cluster of 10 nodes, reachable by ssh over port 1234 on
your docker swarm nodes

    ./deploy.sh 10 1234

# To connect to your new shiny cluster

    ssh -p 1234 -i ubuntucluster_1234.sshkey root@ymslanda.innovationgarage.tech

# To execute a command on all nodes

    parallel --no-notice -S $CLUSTER_NODES --nonall hostname

# To scp something to all nodes

    for node in $CLUSTER_NODESLST; do scp file $node:file; done
