
#!/bin/bash


#Installing kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl 
chmod +x ./kubectl 
sudo mv ./kubectl /usr/local/bin/kubectl

echo "Enter Namespace"
read ns
kubectl create namespace $ns
sudo kubectl config set-context $(kubectl config current-context) --namespace=$ns

echo "Enter  Minio userid"
read UserId
echo "Enter Minio Password"
read mpwd
sed -i "s/USERID/$UserId/" minio.yml
sed -i "s/PASSWORD/$mpwd/" minio.yml

kubectl  -n $ns apply -f minio.yml
kubectl -n $ns apply -f halyard.yml
#kubectl get pods -n $ns
sleep 30
pod=`(kubectl get pods -n $ns | grep spin-halyard | awk '{print $1}')`
kubectl -n $ns  cp ~/.kube/config $pod:/tmp/kubeconfig 
kubectl -n $ns exec -it $pod bash 

#hal config 
hal config provider kubernetes enable 
echo "Enter K8s-Account name"
read K8s-Account
hal config provider kubernetes account add $K8s-Account --provider-version v2  --kubeconfig-file /tmp/kubeconfig

hal config deploy edit --type Distributed --account-name $K8s-Account --location $ns

#mkdir –p ~/.hal/default/profiles
echo "spinnaker.s3.versioning: false" > ~/.hal/default/profiles/front50-local.yml

echo "Enter Minio Access-key"
read ACCESS-KEY
hal config storage s3 edit --endpoint http://minio-service:9001 --access-key-id $ACCESS-KEY --secret-access-key

hal config storage s3 edit --path-style-access=true
hal config storage edit --type s3 
hal config version edit --version $(hal version latest -q) 
hal deploy apply

#deck=`(kubectl get pods -n $ns | grep spin-deck | awk '{print $1}')`
#kubectl port-forward $deck 9000:9000
# OPEN  new Terminal 
#gate=`(kubectl get pods -n $ns | grep spin-gate | awk '{print $1}')`
#kubectl port-forward $gate 8084:8084

#http://localhost:9000 </p>

