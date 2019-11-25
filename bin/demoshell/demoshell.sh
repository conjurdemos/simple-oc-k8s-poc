#/bin/bash
CNAME=demo
HOSTDIR=$PWD
WORKDIR=/dap-demo-env
if [[ "$(docker images | grep $CNAME)" == "" ]]; then
  pushd build
   docker build -t $CNAME .
  popd
fi
docker run -d \
    --name $CNAME \
    --restart always \
    --entrypoint sh \
    $CNAME \
    -c "while true; do sleep 10000; done"
docker cp ./oc-kube $CNAME:/dap-demo-env
docker exec $CNAME mkdir -p /dap-demo-env/.minishift/cache
docker cp ./.minishift/certs/ $CNAME:/dap-demo-env/.minishift
docker cp ./.minishift/config/ $CNAME:/dap-demo-env/.minishift
docker cp ./.minishift/ca.pem $CNAME:/dap-demo-env/.minishift
docker cp ./.minishift/cert.pem $CNAME:/dap-demo-env/.minishift
docker cp ./.minishift/key.pem $CNAME:/dap-demo-env/.minishift
docker exec -it $CNAME bash
docker stop $CNAME >& /dev/null && docker rm $CNAME >& /dev/null &
