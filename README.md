# etcd-glueops

An application that can act as an operator to provide the "glue" to link https://hub.docker.com/r/gliderlabs/registrator and https://hub.docker.com/r/cstpdk/haproxy-confd whit the ability to trigger actions based on registrator updates.

-------

## Quick Initializing of config when --config glueOps (Default)
~~~
etcdctl mkdir /glueOps/config
etcdctl set /glueOps/config/haproxy-discover_path "/haproxy-discover"
etcdctl set /glueOps/config/registrator_path "/registrator"
~~~
