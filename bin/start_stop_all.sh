#!/bin/bash
				# set DAP_HOME to parent directory of this script
DAP_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"

if [[ "$1" != stop && "$1" != start ]]; then
  echo "Usage: $0 [ stop | start ]"
  exit -1
fi

cd $DAP_HOME
if [[ $1 == start ]]; then
  DIRS="K8S_followers CICD_demos JENKINS_demo SPLUNK_demo K8S_apps_demo"
else
  DIRS="K8S_apps_demo SPLUNK_demo JENKINS_demo K8S_followers CICD_demos"
fi
for i in $DIRS; do
  pushd $i && ./$1
  popd
done
