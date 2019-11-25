if [[ $# > 0 ]]; then
 docker exec conjur-cli conjur list -k $1
else
 docker exec conjur-cli conjur list 
fi
