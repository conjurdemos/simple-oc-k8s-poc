# Simple OC/K8s POC

### Summary
Bash scripts that will setup a DAP cluster w/ k8s authentication:
 * 1_master: stands up DAP Master, Follower & CLI in Linux VM
 * 2_follower: initializes auth-k8s for DAP Follower and deploys Followers in k8s/ocp cluster
 * 3_apps: deploys apps in K8s/OCP cluster, retrieves secrets from k8s or ext follower

### Usage notes:
 - The scripts work with either OpenShift or Kubernetes.
 - Scripts tested with:
   - OCP 3.11 (minishift 1.3.4)
   - K8s 1.11.1 (minikube 1.5.2)
   - K8s 1.12 (Docker desktop)
 - Scripts are driven by environment variables set in ./config/*.config files.
 - Pay careful attention when editing the values in the ./config directory.
 - The DAP Master & Follower running on the Linux host are initialized for authn-k8s.
 - All policies are loaded via REST.
 - All variables are initialized via REST.
 - Scripts in 1_master directory:
   - must be run on the DAP Master host. 
   - do not use kubectl/oc CLI programs, do not need k8s/ocp cluster access.
 - Scripts in 2_follower & 3_apps directories:
   - require cluster access with kubectl/oc CLIs.
   - do not need "docker exec" access to the DAP Master or external Follower containers.
   - assume the external Follower already has authn-k8s enabled & configured.
 - By default, the Follower seedfile is pulled from a configmap by a NON-STANDARD seed-fetcher.
   If CONJUR_SEED_FILE_URL is set, e.g. to $CONJUR_MASTER_URL/configuration/$CONJUR_ACCOUNT/seed/follower,
   the seed-fetcher will pull the seedfile from the Master.
 - auth-k8s for apps is supported by Followers running in or outside of the cluster.

### Prerequisites
1. Docker
2. Kubernetes or OpenShift
3. Access to DAP appliance, CLI, authenticator, seed-fetcher and test-app images.

### Usage
Note:
  - User RBAC is only enforced for Openshift
  - All $XXX references refer to env vars set in dap.config

1. cd to cluster/ 
     - edit dap.config
     - edit either per environment:
       - kubernetes.config or openshift.config
2. cd to 1_master
   - load $CONJUR_APPLIANCE_IMAGE and $CLI_IMAGE
   - run start
3. cd to 2_follower
   - as $CLUSTER_ADMIN_USERNAME
     - run ./0-cluster-admin.sh, to initialize cyberark namespace
   - as $DAP_ADMIN_USERNAME
     - load $SEED_FETCHER_IMAGE
     - run ./1-tag-push-images.sh, to push images to registry
     - run ./start, to deploy follower.
4. cd to 3_apps
   - as $CLUSTER_ADMIN_USERNAME
     - run ./0-cluster-admin.sh, to initialize testapps namespace
   - as $DEVELOPER_USERNAME
     - load $AUTHENTICATOR_CLIENT_IMAGE and $TEST_APP_IMAGE
     - run ./1-tag-push-images.sh, to push images to registry
     - run ./start, to deploy apps.
