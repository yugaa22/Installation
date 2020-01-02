#!/bin/bash
function Spinnaker(){
                                # 1. Installation of  Halyard on Local/Debian
function LocalDebian(){
         curl -O https://raw.githubusercontent.com/spinnaker/halyard/master/install/debian/InstallHalyard.sh
         ur=`whoami`
         sudo bash InstallHalyard.sh -y  --user $ur
         . ~/.bashrc
}
function Spin-Docker(){
        mkdir ~/.hal
        docker run -p 8084:8084 -p 9000:9000--name halyard --rm -v ~/.hal:/home/spinnaker/.hal -it gcr.io/spinnaker-marketplace/halyard:stable
        docker exec -it halyard bash
        source <(hal --print-bash-completion)
        docker pull gcr.io/spinnaker-marketplace/halyard:stable
        docker exec -it halyard bash
}
                                                # 2. Choose  CloudProvider
function k8s_v2(){
           hal config provider kubernetes enable
           echo "Enter Kubernetes Account Name"
           read ACCOUNT
	  Kubernetes
          CONTEXT=$(kubectl config current-context)
           hal config provider kubernetes account add $ACCOUNT  --provider-version v2  --context $CONTEXT
           hal config features edit --artifacts true
}
function Aws(){
        echo "Enter Your AWS-Account-name"
        read AWS_ACCOUNT_NAME
        echo "Enter Your AWS-Account-id"
        read ACCOUNT_ID 
        hal config provider aws account add $AWS_ACCOUNT_NAME --account-id $ACCOUNT_ID --assume-role role/spinnakerManaged --provider-version V1
        hal config provider aws account edit $AWS_ACCOUNT_NAME --add-region us-west-2
        echo "Enter Your AWS-Access-key"
        read ACCESS_KEY
        echo "Enter Your AWS-Secret-key"
        read SECRET_KEY 
        hal config provider aws edit --access-key-id  $ACCESS_KEY --secret-access-key $SECRET_KEY
}
											# 3. Choose  Environment Type
function localDebian(){
        hal config deploy edit --type localdebian
}
function LocalGit(){
        echo "localgit"
        Git
	
        sudo add-apt-repository ppa:openjdk-r/ppa -y
        sudo apt-get update && apt-get install openjdk-8-jdk -y
        curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
        sudo apt install npm -y
        sudo curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
        sudo echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
        sudo apt-get update && sudo apt-get install --no-install-recommends yarn -y
        sudo npm install -g yarn -y
        curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm" 
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        echo "Run The Above Three Lines Manually in the Command Prompt"
        sleep 10
        nvm install v10.15.3
        nvm use system
	echo "Enter Your GitHub email address"
        read Mail
	ssh-keygen -t rsa -b 4096 -C $Mail
	echo "Copy the Key from /home/you/.ssh/id_rsa.pub to Your GitHub/settings/ssh-gpg 'Starts With rsa-  Ends With =='  exclude emailId"
	echo "Enter GitHub User_name"
	read USERNAME
        git config --global user.email $Mail
	git config --global user.name $USERNAME
	hal config deploy edit --type localgit --git-origin-user=$USERNAME 		           
}
function Distributed(){
	
        echo "Enter NameSpace For Spinnaker Deployment"
	read NAMESPACE
        Kubernetes
	kubectl create ns $NAMESPACE
	hal config deploy edit --type distributed --account-name $ACCOUNT --location $NAMESPACE
}
										#4. Persistance Storage
function GCS(){
        ur=`whoami`
        echo "Enter Your Bucket name"
        read BUCKET_NAME
        hal config storage gcs edit --project $(gcloud info --format='value(config.project)') --bucket-location us --bucket $BUCKET_NAME --json-path /home/$ur/.gcp/gcp-account.json
        unset BUCKET_NAME
        hal config storage edit --type gcs
}
function Minio(){
        Minio-SetUp
         echo "Enter Minio User_name"
	    read User_name
         ENDPOINT=`hostname -I | awk '{print $1}'`
	ENDPOINT=http://$ENDPOINT:9000
        hal config storage s3 edit --endpoint $ENDPOINT  --access-key-id $User_name --secret-access-key
        sudo hal config storage edit --type s3
        unset ENDPOINT
        unset User_name
}
function S3(){
        echo "Have to check with aws"
        hal config storage s3 edit--access-key-id $ACCESS_KEY_ID  --secret-access-key --region us-west-2 --bucket  $BUCKET_NAME
        hal config storage edit --type s3
        unset BUCKET_NAME
        unset ACCESS_KEY_ID
}
                                                                #1. Install Halyard
echo "Choose your options for Install Halyard  "
echo "1. Local/Debian"
echo "2. spin-Docker"
read HAlYARD
case "$HAlYARD" in
   "1") LocalDebian
    ;;
   "2") Spin-Docker
    ;;
    *) echo "Inappropriate option. Exit !!"
     exit 0
   ;;
esac
                                                        # 2. Choose  CloudProvider
echo "Choose your options for Choose  CloudProvider "
echo "1. k8s_v2"
echo "2. Aws"
read CP
case "$CP" in
   "1") k8s_v2

    ;;
   "2") Aws
   ;;
    *) echo "Inappropriate option. Exit !!"
       exit 0
   ;;
esac
                                                                # 3. Choose  Environment
echo "Choose your options for Choose  Environment "
echo "1. LocalDebian"
echo "2. LocalGit"
echo "3. Distributed"
read ENV
case "$ENV" in
   "1") localDebian

    ;;
   "2") LocalGit

   ;;
   "3") Distributed
   ;;
    *) echo "Inapropriate Option. Exit !!"
       exit 0
   ;;
esac      


	  					# 4. Choose  Storage
echo "Choose your options for Choose  Storage "
echo "1. GCS"
echo "2. Minio"
echo "3. S3"   
read store

 	
case "$store" in
   "1") GCS
    ;;
   "2") Minio
   ;;
   "3") S3
   ;;
    *) echo "Inappropriate option. Exit !!"
       exit 0
   ;;
esac

if [ $ENV -eq 2 ] 
then 
    URLOVERRIDE
    hal config version edit --version branch:upstream/master
    hal deploy apply  
elif [ $ENV -eq 3 ] 
  then 
      deck=`kubectl get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -n $NAMESPACE | grep deck`
      gate=`kubectl get deployment --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -n $NAMESPACE | grep gate`

      kubectl patch svc $deck --type='json' -p='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}]' -n $NAMESPACE
      kubectl patch svc $gate --type='json' -p='[{"op": "replace", "path": "/spec/type", "value": "NodePort"}]' -n $NAMESPACE
      deckPort=`kubectl get svc/$deck -o yaml -n $NAMESPACE | grep nodePort | sed 's/[^0-9]*//g' `
      gatePort=`kubectl get svc/$gate -o yaml -n $NAMESPACE | grep nodePort | sed 's/[^0-9]*//g'`

     echo "Enter URL of YOur VM &&  ip  like format::  xx.xx.xx.xx "
     read URL
           hal config security ui edit  --override-base-url http://$URL:$deckPort
	   hal config security api edit --override-base-url http://$URL:$gatePort
           hal config version edit --version $(hal version latest -q) 
           sudo hal deploy apply          
           echo "Now Your Spinnaker Accessible with  http://$URL:$deckPort"          
else
     URLOVERRIDE
     hal config version edit --version $(hal version latest -q) 
     sudo hal deploy apply 
fi   
echo "done Spinnaker"
}

function URLOVERRIDE(){
	   echo "Enter URL of YOur VM &&  ip  like format::  xx.xx.xx.xx "
           read URL
           hal config security ui edit  --override-base-url http://$URL:9000
	   hal config security api edit --override-base-url http://$URL:8084
	   mkdir ~/.hal/default/service-settings/
	   touch ~/.hal/default/service-settings/deck.yml
	   touch  ~/.hal/default/service-settings/gate.yml
           echo "host: 0.0.0.0 " >>~/.hal/default/service-settings/deck.yml
           echo "host: 0.0.0.0 " >>~/.hal/default/service-settings/gate.yml
         echo "Now Your Spinnaker Accessible with $URL:9000"
           
}
                                              #Installing Kubernetes(Kubectl)
function Kubernetes(){
	sudo apt-get update
      	sudo apt-get install -y apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	sudo touch /etc/apt/sources.list.d/kubernetes.list 
	echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update
	sudo apt-get install -y kubectl
}
                                                          #Installing  Docker & Kubernetes With Single Node
function Dev-SingleNode-K8s-Cluster(){
             echo "Do You Have Docker Installed on Your System which is Pre-Requirement for K8s"
              Docker
             #Checking O.S Compatability to Install K8s
	os=` cat /etc/lsb-release |grep = | awk '{print $2}' | sed 's/[^0-9,.]*//g'`
	min=16.04
	if (( ${os%%.*} < ${min%%.*}  || ( ${os%%.*} == ${min%%.*} && ${os##*.} < ${min##*.} ) )); then
  		  echo "For Installation of K8s Minimum Requirement of O.S  is 16.04"
   		 exit 1
	fi
             echo "installing K8s-cluster"
        Kubernetes
        sudo apt-get install -y kubelet kubeadm kubernetes-cni --allow-unauthenticated
        FIND_IP="http://checkip.amazonaws.com/"
        PUBLIC_IP=`curl "$FIND_IP"`
        #sudo apt install kubeadm
   if [[ -n "$PUBLIC_IP" ]]; then
                echo "[+] Your Public IP: $PUBLIC_IP"
                sudo iptables -P FORWARD ACCEPT
                sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans=$PUBLIC_IP
        else
                echo "[-] Not able to find your public IP."
                sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --ignore-preflight-errors=all
   fi
        echo "[*] Placing kubeconfig file in ~/.kube/"
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        echo "[*] Making master node schedulable"
        kubectl taint nodes --all node-role.kubernetes.io/master-
        echo "[*] Applying 'Flannel' network to Kubernetes"
        kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.0/Documentation/kube-flannel.yml
        echo "For Core-dns service"
        kubectl apply -n kube-system -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
        echo "To remove, run below commands"
        echo "kubectl drain <node name> --delete-local-data --force --ignore-daemonsets"
        echo "kubectl delete node <node name>"
        echo "kubeadm reset"
}
                                                     #Installing Docker
function Docker(){
     docker -v > /dev/null 2>&1
     value=`echo $?`
     if [ $value -eq 127 ]
        then
        echo "installing Docker"
        sudo apt-get update
        sudo apt-get install  apt-transport-https  ca-certificates  curl gnupg-agent  software-properties-common -y
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
        sudo apt-get update
        apt-cache policy docker.io
        sudo apt-get install -y docker.io
        sudo systemctl status docker 
     else
         echo "Docker Already Installed In Your Machine"
     fi
}
                                                        #Installing Git
function Git(){
     git --version >/dev/null 2>&1
     gitvalue=`echo $?`
     if [ $gitvalue -eq 127 ]
      then 
        echo "installing Git"
        sudo apt update
        sudo apt install git
        git --version
        echo "Please Your user name"
        read usr_name
        git config --global user.name $usr_name
        echo "Please Your user email"
        read email_id
        git config --global user.email $email_id
      else
         echo "Git Already Installed In Your Machine"
     fi
} 
                                                          #Installing Jenkins
function Jenkins(){
         
     (systemctl status jenkins | grep ' Active: active (running) ' )> /dev/null 2>&1
       jenvalue=`echo $?`
       echo $jenvalue 
        if [ $jenvalue -eq 1 ]
       then
        echo "installing Jenkins"
        wget -q -O - https://pkg.jenkins.io/debian/jenkins-ci.org.key | sudo apt-key add -
        echo deb https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list
        sudo apt-get update
        sudo apt-get install jenkins -y
        sudo systemctl start jenkins
        sudo systemctl status jenkins
        sudo ufw allow 8080
        sudo ufw status
        sudo ufw allow OpenSSH -y
        sudo ufw enable
     else
        echo "Jenkins Already Installed In Your Machine"        
        fi
}
                                                         #Installing Java(jdk-8)
function Java(){       
   	if type -p java; then
   	 echo found java executable in PATH
 	   _java=java
	 elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
   	 echo found java executable in JAVA_HOME     
  	  _java="$JAVA_HOME/bin/java"		
	else
    	echo "installing openJdk"
        apt-get update
        sudo add-apt-repository ppa:openjdk-r/ppa
        sudo apt-get update
        sudo apt-get install openjdk-8-jdk -y
        java -version
     fi       
}
                                                   #Installing Minio
function Minio-SetUp(){
       (sudo service minio status | grep ' Active: active') > /dev/null 2>&1
       mval=`echo $?`
       if [ $mval -eq 1 ]
       then
        echo "installing Minio"
        sudo apt-get update
        curl -O https://dl.minio.io/server/minio/release/linux-amd64/minio
        sudo chmod +x minio
        sudo mv minio /usr/local/bin
        sudo useradd -r minio-user -s /sbin/nologin
        sudo chown minio-user:minio-user /usr/local/bin/minio
        sudo mkdir /usr/local/share/minio
        sudo chown minio-user:minio-user /usr/local/share/minio
        sudo mkdir /etc/minio
        sudo chown minio-user:minio-user /etc/minio
        sudo touch minio
        echo "Enter Minio_User_Name"
        read User_name
        echo "Enter Minio_Secret_Key"
        read Secret_key
        echo   "MINIO_VOLUMES=\"/usr/local/share/minio/\"
                MINIO_OPTS=\"-C /etc/minio --address 0.0.0.0:9001\"
                MINIO_ACCESS_KEY=$User_name
                MINIO_SECRET_KEY=$Secret_key " >> minio.txt

        sudo mv minio.txt /etc/default/minio
        curl -O https://raw.githubusercontent.com/minio/minio-service/master/linux-systemd/minio.service
        sudo mv minio.service /etc/systemd/system
        sudo systemctl daemon-reload
        sudo systemctl enable minio
        sudo systemctl start minio
        sudo systemctl status minio
        echo "Please save Minio_access-key =$User_name  && Minio_secret-key =$Secret_key and End Point is http://localhost:9001  to access Minio Storage"	
       else
         echo "Minio Already Installed in Your Machine"
     fi
}

while(true)
do
echo "What Do You to Install"
echo "1.Spinnaker"
echo "2.Kubernetes(kubectl)"
echo "3.Dev-SingleNode-K8s-Cluster(Docker & K8s)"
echo "4.Docker"
echo "5.Git"
echo "6.Jenkins"
echo "7.Java"
echo "8.Minio-SetUp"
echo "Press Any Other Key to EXIT!!"
read INSTALL
case "$INSTALL" in
   "1") Spinnaker
    ;;
   "2") Kubernetes
    ;;
   "3") Dev-SingleNode-K8s-Cluster
    ;;
   "4") Docker
    ;;   
   "5") Git
    ;;
   "6") Jenkins
    ;;
   "7") Java
    ;;
   "8") Minio-SetUp
    ;;
    *) echo "Exit !! ThankYou "
     exit 0
    ;;
esac
done

