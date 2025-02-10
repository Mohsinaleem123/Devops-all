check_pod_readiness() {
  local pod
  local pod_status

  echo "Checking readiness state of pods..."

  # Get all pods in the cluster
  lpod_list=$(kubectl get pods -l app="" -n "" -o custom-columns=":metadata.name")
  local pods=($lpod_list)

  # Loop until all pods have readiness state 1/1
  while true; do
    local all_ready=true
   
    # Loop through each pod and check readiness state
    for pod in "${pods[@]}"; do
      pod_status=$(kubectl get pod -n "" "$pod" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
      if [[ "$pod_status" != "True" ]]; then
        echo "Pod $pod in namespace $pod_namespace is not ready"
        all_ready=false
        break
      fi
    done

    if $all_ready; then
      echo "All pods in namespace $pod_namespace have a readiness state of 1/1"
      break
    fi

    echo "Not all pods in namespace $pod_namespace are ready. Retrying in 5 seconds..."
    sleep 5
  done
}


# Execute the kubectl command and capture the output in a variable
pod_list=$(kubectl get pods -l app=" -n " -o custom-columns=":metadata.name")

# Store the pod names in an array
pod_array=($pod_list)

# Access and print pod names from the array
for pod in "${pod_array[@]}"
do
    echo "Destroying pod: $pod"
    kubectl delete pod "$pod" -n ""
    check_pod_readiness
   

done