<img width="1415" height="654" alt="diagram-export-9-23-2025-7_59_46-PM" src="https://github.com/user-attachments/assets/154f0e66-8923-41f8-9c04-3d73d24c4341" />

<img width="1428" height="656" alt="diagram-export-9-23-2025-8_05_49-PM" src="https://github.com/user-attachments/assets/d52d2dc6-914b-4d18-b903-77f6714362af" />


---

# DevOps CI/CD Pipeline on AWS with Terraform and Kubernetes


This project implements a CI/CD pipeline for a Node.js application, deployed on AWS infrastructure using Terraform-provisioned EC2 instances and a manually created Kubernetes cluster. The pipeline automates code scanning, building, containerization, and deployment, with monitoring via Prometheus and Grafana. ArgoCD enables GitOps-based deployments to Kubernetes. This `README.md` provides a comprehensive guide to the architecture, workflow, tools, and setup instructions.

## Infrastructure

The infrastructure is hosted on AWS, with EC2 instances provisioned via Terraform and a Kubernetes cluster created manually. Below is a detailed breakdown of components:

### EC2 Instance 1 (t2.large)
- **Purpose**: Hosts CI/CD and build tools.
- **Tools Installed**:
  - **Jenkins**: CI/CD server for pipeline orchestration (port 8080).
  - **Docker**: Builds and manages container images.
  - **SonarQube**: Performs static code analysis for quality and security (port 9000).
  - **Trivy**: Scans Docker images for vulnerabilities.
  - **NPM**: Builds Node.js applications.
- **Terraform Configuration**:
  - Instance type: `t2.large` (2 vCPUs, 8 GB RAM).
  - AMI: Latest Amazon Linux 2 or Ubuntu 20.04.
  - Security groups: Allow inbound traffic on ports 8080 (Jenkins), 9000 (SonarQube), and 22 (SSH).
  - IAM role: Grants access to AWS ECR for pushing/pulling images.
  - User data script: Installs Jenkins, Docker, SonarQube, Trivy, and Node.js/NPM during instance bootstrap.

# Manual setup Instructions

## Setup Instructions

### 1. EC2 Instance Setup
1. Launch an EC2 instance with the above specifications.
2. SSH into the instance:
   ```
   ssh -i <your-key.pem> ec2-user@<EC2-Public-IP>
   ```
3. Update the system:
   ```
   sudo yum update -y
   ```
   ### Install git
   ```
   sudo yum install git -y
   git --version
   ```
   ### Install maven
   ```
   sudo yum install maven -y
   mvn --version
   ```

### 2. Install Jenkins
Install and configure Jenkins on the EC2 instance:

```
sudo yum install wget -y
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
sudo dnf install java-21-amazon-corretto -y
sudo yum install jenkins -y
sudo systemctl enable jenkins
sudo systemctl start jenkins
```

- Access Jenkins at `http://<EC2-Public-IP>:8080`.
- Unlock Jenkins using the initial admin password from `/var/lib/jenkins/secrets/initialAdminPassword`.
- Install suggested plugins and create an admin user.

### 3. Install Docker
Install and configure Docker to work with Jenkins:

```
sudo yum install docker -y
sudo systemctl start docker
sudo usermod -aG docker jenkins
sudo usermod -aG docker ec2-user
sudo systemctl restart docker
sudo chmod 666 /var/run/docker.sock
sudo systemctl restart jenkins
```

- Log out and back in as `ec2-user` to apply group changes.
- Verify: `docker --version`.

### 4. Install and Configure AWS CLI
Install AWS CLI and configure credentials:

```
sudo yum install awscli -y
aws configure
```

- Enter your AWS Access Key ID, Secret Access Key, region (e.g., `us-east-1`), and output format (e.g., `json`).

## SonarQube Setup

### Create SonarQube Container
Run the following command to start SonarQube using Docker:

```
docker pull sonarqube
sudo docker run -itd --name sonar -p 9000:9000 sonarqube
```

- Wait for SonarQube to start (check logs: `sudo docker logs sonar`).
- Access at `http://<EC2-Public-IP>:9000`.
- Change default password on first login.
### SonarQube Token
1. Start SonarQube container .
2. Access SonarQube at `http://<EC2-Public-IP>:9000`.
3. Login with default credentials: `admin` / `admin`.
4. Go to **My Account > Security > Generate Tokens**.
5. Create a token (e.g., name: "Jenkins Token").

## Install Trivy (Security Scanner)
```
wget https://github.com/aquasecurity/trivy/releases/download/v0.70.0/trivy_0.70.0_Linux-64bit.tar.gz
tar -xzf trivy_0.70.0_Linux-64bit.tar.gz
mv trivy /usr/local/bin/
chmod +x /usr/local/bin/trivy

# Verify Trivy
trivy --version
```
 ### Verify
  ```
trivy --version
```
## Install Node.js + npm
  ### Setup Node.js repo  
  ```
curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
```
 ### Install Node.js
 ```
sudo yum install -y nodejs
```
 ### Verify
 ```
node -v
npm -v
```

### EC2 Instance 2 (t2.xlarge)
- **Purpose**: Hosts monitoring tools.
- **Tools Installed**:
  - **Prometheus**: Collects metrics from Kubernetes and the application (port 9090).
  - **Grafana**: Visualizes metrics via dashboards (port 3000).
- **Terraform Configuration**:
  - Instance type: `t2.xlarge` (4 vCPUs, 16 GB RAM) for better performance with monitoring workloads.
  - AMI: Same as EC2 Instance 1.
  - Security groups: Allow inbound traffic on ports 9090 (Prometheus), 80 (Grafana), and 22 (SSH).
  - User data script: Installs Helm, then deploys Prometheus and Grafana via Helm charts.
- **Helm Charts**:

 **Helm Installation:**
``` 
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 
sudo chmod 700 get_helm.sh 
sudo ./get_helm.sh 
helm version --client
```
Add Helm Repositories 
```
helm repo add stable https://charts.helm.sh/stable 
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 
helm search repo prometheus-community
```
### Kubernetes Cluster
- **Setup**: Manually created using AWS CLI (e.g., via `eksctl create cluster` or EKS API).
- **Configuration**:
  - Minimum 3 worker nodes (e.g., `t3.medium`) for high availability.
  - VPC and subnets configured to allow communication with EC2 instances.
  - ArgoCD installed in the cluster for GitOps deployments (`kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`).
  - Configured to pull images from AWS ECR using an IAM role for the Kubernetes nodes.
- **Networking**: Security groups allow Kubernetes API access and communication with Prometheus for metrics scraping.

 **Install and Configure Prometheus and Grafana:**

```
kubectl create namespace prometheus
```
```
helm install stable prometheus-community/kube-prometheus-stack -n prometheus 
```
```
kubectl get pods -n prometheus
 ```
```
kubectl get svc -n prometheus
 ```

```
kubectl patch svc stable-kube-prometheus-sta-prometheus -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'
```
```
kubectl patch svc stable-grafana -n prometheus -p '{"spec": {"type": "LoadBalancer"}}'
```

```
kubectl get secret --namespace prometheus stable-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
``` 

```
kubectl get svc -n prometheus
```

### AWS ECR
- **Purpose**: Private Docker registry for storing application images.
- **Setup**: Created via Terraform or AWS CLI (`aws ecr create-repository --repository-name nodejs`).

### GitHub Repository
- **Purpose**: Stores source code, Dockerfiles, and Kubernetes manifests (`deployment.yaml`, `service.yaml`).
- **Access**: Jenkins authenticates via SSH or GitHub API token.

### Terraform Setup
  ```
  terraform/
  ├── main.tf

  ```
- **Apply**: Run `terraform init`, `terraform plan`, and `terraform apply` to provision resources.

## CI/CD Workflow

The CI/CD pipeline automates building, testing, and deploying a Node.js application using Jenkins as the orchestrator. The pipeline is defined in a `Jenkinsfile` (declarative pipeline) in the GitHub repository.

### Pipeline Stages

1. **Clone Code**:
   - Jenkins clones the repository using Git credentials.
2. **Code Quality Scan**:
   - SonarQube scans the code for bugs, vulnerabilities, and code smells.
   - Configured via `sonar-project.properties` in the repo.
   - Fails if quality gates (e.g., coverage < 80%) are not met.
3. **Build Application**:
   - NPM installs dependencies (`npm install`) and builds the app (`npm run build`).
   - Artifacts are stored temporarily for Docker.
4. **Security Scan (Optional)**:
   - Trivy scans the Docker image for vulnerabilities (`trivy image myapp:latest`).
   - Configured to fail on critical or high-severity vulnerabilities.
5. **Build and Push Docker Image**:
   - Docker builds the image (`docker build -t myapp:$BUILD_NUMBER .`).
   - Tags and pushes to ECR (`docker push <aws-account-id>.dkr.ecr.<region>.amazonaws.com/myapp:$BUILD_NUMBER`).
   - Requires AWS CLI and ECR login (`aws ecr get-login-password`).
6. **Update Manifest**:
   - A script updates `deployment.yaml` in GitHub to reference the new image tag.
   - Example script:
     ```bash
     sed -i "s|image: .*|image: <aws-account-id>.dkr.ecr.<region>.amazonaws.com/myapp:$BUILD_NUMBER|" deployment.yaml
     git commit -m "Update image tag to $BUILD_NUMBER"
     git push origin main
     ```
7. **ArgoCD Sync**:
   - ArgoCD detects the manifest change and syncs the Kubernetes deployment.

### Jenkinsfile Example
```groovy
pipeline {
    agent any

    stages {
    stage('Checkout Code') {
        steps {
            echo 'scm git'
            git branch: 'main', url: 'https://github.com/adarsh0331/Project_7.git'
        }
    }
    

    stage('SonarQube Analysis') {
        steps {
            withSonarQubeEnv('SonarQube') {   // Jenkins -> Manage Jenkins -> Configure System -> SonarQube servers
                 script {
                   def scannerHome = tool 'SonarScannerCLI'   // Jenkins -> Manage Jenkins -> Tools -> SonarQube Scanner installations
                      sh """
                          ${scannerHome}/bin/sonar-scanner \
                          -Dsonar.projectKey=my-devops-app \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://54.167.98.78:9000/ \
                          -Dsonar.login=squ_1d768aa35185eaddb20ecdfbe32f0740c673b5f6
                       """
                    }
                }
            }
        }

    stage('Building the code') {
      steps {
        sh 'ls -ltr'
        // build the project and create a JAR file
        sh 'npm install'
      }
    }

    stage('Build docker image'){
    steps{
        script{
            echo 'docker image build'
        sh 'sudo docker build -t adarshbarkunta/nodejs:${BUILD_NUMBER} .'
        }
    }
}
		
     stage('docker image scan'){
     steps{
         sh "sudo trivy image adarshbarkunta/nodejs:${BUILD_NUMBER}"
     }
 }		


stage('Push image to ECR') {
    steps {
        withAWS(credentials: 'aws-creds', region: 'us-east-1') {
            script {
                sh '''
                  aws ecr get-login-password --region us-east-1 \
                  | sudo docker login --username AWS --password-stdin 526344317172.dkr.ecr.us-east-1.amazonaws.com
                  
                  sudo docker tag adarshbarkunta/nodejs:${BUILD_NUMBER} 526344317172.dkr.ecr.us-east-1.amazonaws.com/nodejs:${BUILD_NUMBER}
                  sudo docker push 526344317172.dkr.ecr.us-east-1.amazonaws.com/nodejs:${BUILD_NUMBER}
                '''
            }
        }
    }
}
       stage('Update Deployment File') {
		
		 environment {
            GIT_REPO_NAME = "Project_7"
            GIT_USER_NAME = "adarsh0331"
        }
		
            steps {
                echo 'Update Deployment File'
				withCredentials([string(credentialsId: 'githubtoken', variable: 'githubtoken')]) 
				{
                  sh '''
                    git config user.email "adarsh@gmail.com"
                    git config user.name "adarsh"
                    BUILD_NUMBER=${BUILD_NUMBER}
					sed -i "s|image: .*|image: 526344317172.dkr.ecr.us-east-1.amazonaws.com/nodejs:$BUILD_NUMBER|" deploymentfiles/deployment.yml
                    git add .
                    
                    git commit -m "Update deployment image to version ${BUILD_NUMBER}"

                    git push https://${githubtoken}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} HEAD:main
                '''
				  
                 }
				
            }
        }

  }
}
```
#  Manual Setup Guide – Kubernetes Tool Server (EC2)
  ##  Step 1: Launch EC2 Instance
AMI: Amazon Linux 2023 / Amazon Linux 
Instance type:
 Recommended: t3.xlarge (or t3.large if cost sensitive)
Storage: 20–30 GB
Key pair: create or use existing
 ## Step 2: Open Required Ports (Security Group)

No inbound ports are strictly required for tools, but ensure:

Type	Port	Purpose
SSH	22	Connect to EC2
## Step 3: Connect to Server
```
ssh -i your-key.pem ec2-user@<EC2-PUBLIC-IP>
```
## Step 4: Update System
```
sudo yum update -y
```
## Step 5: Install Basic Dependencies
```
sudo yum install -y curl wget git tar unzip
```
## STEP 6: Install AWS CLI (IMPORTANT)
```
sudo yum install -y awscli
```
 ## Verify:
```
aws --version
```
## STEP 7: Install kubectl
Download kubectl
```
curl -LO "https://dl.k8s.io/release/$(curl -sSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
## Make executable
```
chmod +x kubectl
```
 ## Move to system path
 ```
sudo mv kubectl /usr/local/bin/
```
## Verify
```
kubectl version --client
```
## STEP 8: Install eksctl
Download eksctl
```
curl -sSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" -o eksctl.tar.gz
```
## Extract
```
tar -xzf eksctl.tar.gz
```
 ### Move binary
 ```
sudo mv eksctl /usr/local/bin/
```
 ### Clean up
 ```
rm -f eksctl.tar.gz
```
 ### Verify
 ```
eksctl version
```
## STEP 9: Install Helm
 Install script method
 ```
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
 ### Verify
 ```
helm version
```
## STEP 10: Configure AWS Credentials (IMPORTANT)

You must configure AWS access:
```
aws configure
```
Enter:

AWS Access Key
Secret Key
Region (e.g. ap-south-1)
Output format (json)
## STEP 11: Add Helm Repositories
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
```
 ### Update repos
helm repo update
## Step 12: Verify Everything
Check tools:
```
kubectl version --client
eksctl version
helm version
aws --version
```
## Monitoring

Monitoring ensures observability of the Kubernetes cluster and application.

### Components
- **Prometheus**:
  - Scrapes metrics from Kubernetes pods, nodes, and the application (if instrumented with `/metrics` endpoint).
  - Configured with scrape jobs in `prometheus.yml`:
    ```yaml
    scrape_configs:
      - job_name: 'kubernetes'
        kubernetes_sd_configs:
        - role: pod
          namespaces:
            names: [default, argocd]
      - job_name: 'application'
        static_configs:
        - targets: ['<app-service>:8080']
    ```
  - Installed via Helm: `helm install prometheus prometheus-community/prometheus`.
- **Grafana**:
  - Connects to Prometheus as a data source.
  - Dashboards display CPU/memory usage, pod health, deployment status, and custom app metrics.
  - Installed via Helm: `helm install grafana grafana/grafana`.
  - Access: `http://<ec2-ip>:3000`, default login (admin/admin).

### Monitoring Flow
1. Kubernetes pods expose metrics (via kube-state-metrics, node-exporter, or app-specific endpoints).
2. Prometheus scrapes metrics at regular intervals.
3. Grafana queries Prometheus to visualize metrics in dashboards.
4. Alerts (optional): Configure in Prometheus with Alertmanager for notifications (e.g., Slack, email) on high CPU or failed deployments.

## Tools Used

| Tool         | Purpose                              | Version (Recommended) | Location              |
|--------------|--------------------------------------|-----------------------|-----------------------|
| Jenkins      | CI/CD pipeline orchestration         | 2.426.x (LTS)         | EC2 Instance 1        |
| SonarQube    | Code quality and security scanning   | 9.9.x (Community)     | EC2 Instance 1        |
| Docker       | Container image building            | 24.x                  | EC2 Instance 1        |
| Trivy        | Image vulnerability scanning         | 0.45.x                | EC2 Instance 1        |
| NPM          | Node.js app building                 | 10.x (with Node.js 20)| EC2 Instance 1        |
| ArgoCD       | GitOps-based Kubernetes deployments  | 2.8.x                 | Kubernetes Cluster    |
| Prometheus   | Metrics collection and alerting      | 2.47.x (via Helm)     | EC2 Instance 2        |
| Grafana      | Metrics visualization                | 10.x (via Helm)       | EC2 Instance 2        |
| GitHub       | Code and manifest storage           | N/A                   | External              |
| AWS ECR      | Docker image registry                | N/A                   | AWS                   |
| Kubernetes   | Container orchestration              | 1.28.x                | AWS (Manual Cluster)  |

All tools are open-source except AWS services. Use latest stable versions unless specified.

## Deployment Flow

The deployment process is GitOps-driven using ArgoCD:

1. **Image Push**: Jenkins builds and pushes the Docker image to AWS ECR.
3. **Manifest Update**: Jenkins updates `deployment.yaml` in GitHub with the new image tag.
   
   - Example `deployment.yaml`:

 ```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mc-app
  labels:
    app: mc-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: mc-app
  template:
    metadata:
      labels:
        app: mc-app
    spec:
      containers:
      - name: mc-app
        image: 526344317172.dkr.ecr.us-east-1.amazonaws.com/nodejs:16
        ports:
        - containerPort: 3000
```
3. **ArgoCD Sync**:
   - ArgoCD monitors the GitHub repo for changes.
   - Detects the updated `deployment.yaml` and triggers a sync.
   - Applies the manifest to Kubernetes using `kubectl apply`.
4. **Kubernetes Deployment**:
   - Kubernetes pulls the image from ECR 
   - Rolls out new pods with a rolling update strategy for zero downtime.
5. **Monitoring**:
   - Prometheus scrapes metrics from the new pods.
   - Grafana visualizes metrics in real-time.

### Rollback
- Revert the `deployment.yaml` commit in GitHub to the previous image tag.
- ArgoCD auto-syncs, rolling back the deployment.
- Alternatively, use `kubectl rollout undo deployment/myapp`.
  
## verified steps to install the AWS CLI on Windows using PowerShell
 ### Step 1: Download AWS CLI Installer

Run this command in PowerShell:
```
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
```
This downloads the official installer from Amazon Web Services.

### Step 2: Install AWS CLI

Run:
```
Start-Process msiexec.exe -Wait -ArgumentList '/i AWSCLIV2.msi /qn'
```
/i → install
/qn → silent install (no UI)

### Step 3: Verify Installation

Close PowerShell and open a new PowerShell window, then run:
```
aws --version
```
Expected output (example):

aws-cli/2.x.x Python/3.x Windows/x86_64

If you see this → installation is successful.

### If You Still Get: “aws not recognized”

This is a PATH issue. Fix it like this:

#### Step 1 Check installation path

AWS CLI is usually installed at:
```
C:\Program Files\Amazon\AWSCLIV2\
```
#### Step 2: Add to PATH

Run in PowerShell:
```
$env:Path += ";C:\Program Files\Amazon\AWSCLIV2\"
```
Then try again:
```
aws --version
```
### Step 4: Configure AWS CLI

Once installed, run:
```
aws configure
```
Enter:

AWS Access Key,
AWS Secret Key,
Region (e.g., us-east-1),
Output format (json).
### To view terrform file in windows powershell
```
type main.tf     
```
  ##### or
  ```
  Get-Content main.tf
  ```
### To edit a terrform file in windows powershell 
```
notepad main.tf
```
   ##### or
```
code main.tf
```
# Install Plugins (Step-by-Step in Jenkins UI)
Install necessary plugins via **Manage Jenkins > Manage Plugins > Available**:
- **Core: Pipeline Plugin,Pipeline: Stage View Plugin**
- **Git:Git Plugin, GitHub Plugin,GitHub Integration,GitHub Authentication**
- **SonarQube Scanner**
- **Docker Pipeline Plugin**
- **Maven Integration**
- **AWS: AWS Credentials Plugin, Pipeline: AWS Steps Plugin**
- **Credentials: Credentials Plugin, Credentials Binding Plugin (Check if they are already installed
Go to:
Manage Jenkins → Plugins → Installed
Search:
  -credentials
  -binding
👉 If you see:
Credentials Plugin ✔
Credentials Binding Plugin ✔**)
 
- **Manage Jenkins → Restart Jenkins**
  
###  Configure Credentials in Jenkins
Add credentials in **Manage Jenkins > Manage Credentials > System > Global credentials**:

**AWS Credentials**
 - **Kind**: AWS Credentials
 - **ID**: aws-creds
 - **Access Key**: <your access key>
 - **Secret Key**: <your secret key>

  **GitHub Token**:
  - Go to **GitHub > Settings > Developer settings > Personal access tokens**.
  - Generate a token with `repo` and `admin:repo_hook` scopes.
  - In Jenkins:
    - **Kind**: Secret text
    - **Secret**: GitHub token
    - **ID**: `githubtoken`
    - **Description**: GitHub access token

  **SonarQube Token**:
  - **Kind**: Secret text
  - **Secret**: SonarQube token 
  - **ID**: `sonar-token`
  - **Description**: SonarQube authentication token

 **Docker Hub Credentials**:
  - **Kind**: Username with password
  - **Username**: Your Docker Hub username
  - **Password**: Your Docker Hub password
  - **ID**: `dockerhub`
  - **Description**: Docker Hub credentials

###  Configure SonarQube in Jenkins
1. Go to **Manage Jenkins > System Configuration > SonarQube Servers**.
2. Add:
   - **Name**: `SonarQube`
   - **Server URL**: `http://<EC2-Public-IP>:9000`
   - **Credentials**: Select `sonar-token`.
3. Go to **Manage Jenkins > Tools > SonarQube Scanner**.
4. Add:
   - **Name**: `SonarScannerCLI`
   - **Install automatically**: Check or specify path.
5. Save.
6. Go to **Manage Jenkins > Tools > maven**.
 7. Add:
   - **Name**: `maven`
   - **Install automatically**: Check or specify path.
8. Save.


#### Configure Docker Permissions (IMPORTANT)

#### On EC2 (not Jenkins UI):
```
sudo usermod -aG docker jenkins
```
```
sudo systemctl restart docker
```
```
sudo chmod 666 /var/run/docker.sock
```
```
sudo systemctl restart jenkins
```
### Attach IAM Role to EC2(jenkins)
  - Step-by-step:
  - Open EC2 → Instances
  - Select your instance
  - Click Actions → Security → Modify IAM Role
  - Attach a role with permissions:
       - AmazonEKSClusterPolicy (or) AdministratorAccess
       - AmazonEC2ContainerRegistryFullAccess
       - AmazonEKSClusterPolicy
       - AmazonEC2FullAccess
       - CloudFormationFullAccess
       - IAMFullAccess
 - If role doesn’t exist:
        - Create IAM Role : jenkins
        - Select EC2 as trusted entity
        - Service or use case: EC2
        -  Attach above policies
### Create from AWS Console (jenkins)
   ##### Go to: AWS Console → Elastic Container Registry (ECR) → Repositories → Create repository
   ##### Repository name: nodejs
   ##### Keep everything default and click: Create repository
## OR
### Create Using AWS CLI
  ##### Run this on Jenkins server:
  ```
 aws ecr create-repository --repository-name myapp --region us-east-1
```
 ##### Expected output:
 ```json
{
  "repository": {
      ...
  }
}
```
   
### Attach IAM Role to EC2(k8s)
  - Step-by-step:
  - Open EC2 → Instances
  - Select your instance
  - Click Actions → Security → Modify IAM Role
  - Attach a role with permissions:
       - AmazonEKSClusterPolicy
       - AmazonEKSWorkerNodePolicy
       - AmazonEC2ContainerRegistryReadOnly
       - AmazonEKS_CNI_Policy
       - AmazonEKSServicePolicy
       - AmazonEC2FullAccess
       - AWSCloudFormationFullAccess
       - IAMFullAccess
   - If role doesn’t exist:
        - Create IAM Role : jenkinsk8s
        - Select EC2 as trusted entity
        - Service or use case: EC2
        -  Attach above policies
  - Attach an inline policy directly to your role:
        - IAM → Roles → jenkinsk8s → Add inline policy
     - Paste this:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## Setup Instructions

1. **Provision Infrastructure**:
   - Clone the Terraform repo: `git clone <terraform-repo>`.
   - Configure AWS credentials (`aws configure`).
   - Run `terraform init`, `terraform plan`, and `terraform apply`.
2. **Create Kubernetes Cluster**:
      
    ```
    eksctl create cluster --name my-cluster --region us-east-1 --nodegroup-name workers --node-type t3.medium --nodes 3
    ```
      - IF not configured kubeconfig after cluster creation. Then run this command
      
       ```
       aws eks update-kubeconfig --region us-east-1 --name my-cluster
       ```
     - **Install ArgoCD:**
      
    ```
    kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
4. **Configure Jenkins**:
   - Access Jenkins at `http://<ec2-1-ip>:8080`.
   - Install plugins: Git, Pipeline, SonarQube Scanner, Docker, AWS Credentials.
   - Configure GitHub webhook and credentials.
   - Add SonarQube server in Jenkins global config.
5. **Set Up Monitoring**:
   - SSH into EC2 Instance 2 and install Helm.
   - Deploy Prometheus and Grafana via Helm commands (see Monitoring section).
   - Configure Grafana with Prometheus data source.
6. **Create GitHub Repository**:
   - Add source code, `Dockerfile`, `Jenkinsfile`, and Kubernetes manifests.
   - Configure webhook to point to Jenkins.
7. **Create ECR Repository**:
   - Run `aws ecr create-repository --repository-name myapp`.
   - Assign IAM roles to EC2 Instance 1 and Kubernetes nodes.
8. **Run Pipeline**:
   - Commit code to GitHub to trigger Jenkins.
   - Monitor pipeline in Jenkins UI, ArgoCD UI, and Grafana dashboards.

## Maintenance

- **Upgrades**: Regularly update tools (Jenkins, ArgoCD, etc.) to stable versions.
- **Backups**: Backup Jenkins home (`~/.jenkins`), SonarQube data, and Grafana dashboards.
- **Security**: Rotate AWS IAM credentials and GitHub tokens periodically.
- **Scaling**: Add more Kubernetes nodes or upgrade EC2 instances for higher workloads.
- **Logs**: Use Kubernetes logs (`kubectl logs`) and Grafana Loki (optional) for log aggregation.

## Troubleshooting

- **Jenkins Failure**: Check pipeline logs in Jenkins UI or `/var/lib/jenkins/logs`.
- **SonarQube Issues**: Verify quality gate settings and network access (port 9000).
- **Trivy Failures**: Adjust severity thresholds if scans are too strict.
- **ArgoCD Sync Issues**: Check ArgoCD UI for sync errors or GitHub connectivity.
- **Monitoring Gaps**: Ensure Prometheus scrape targets are correct and pods expose metrics.

---

## If you have any issues with public key path from your local system
🔍 What’s going wrong

#### Terraform is failing at:

public_key = file("~/.ssh/id_rsa.pub")

Because:

~ (home shortcut) does NOT work in Terraform paths
Terraform expects a real, absolute or relative file path
The file likely doesn’t exist at that path on your Windows system
#### Step-by-step fix
✔️ Step 1: Check if the key exists

On Windows PowerShell, run:
```
dir $HOME\.ssh\
```
Look for:

id_rsa.pub
✔️ Step 2: If NOT present → generate SSH key

Run:
```
ssh-keygen -t rsa -b 4096
```
Press Enter for all prompts.

This will create:

C:\Users\Hp\.ssh\id_rsa
C:\Users\Hp\.ssh\id_rsa.pub

✔️ Step 3: Update Terraform file (IMPORTANT)

#### Replace this:

public_key = file("~/.ssh/id_rsa.pub")

#### With absolute Windows path:

public_key = file("C:/Users/Hp/.ssh/id_rsa.pub")

#### After fixing

Run again:
```
terraform init
terraform plan
```
### Verify the change

Run again:
```
type main.tf
```

#### This is main.tf file with vpc and ec2

provider "aws" {
  region = "us-east-1"
}

# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

# ----------------------------
# Internet Gateway
# ----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# ----------------------------
# Subnets
# ----------------------------
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# ----------------------------
# Route Table
# ----------------------------
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# ----------------------------
# Key Pair
# ----------------------------
resource "aws_key_pair" "mykey" {
  key_name   = "project-new"
  public_key = file("C:/Users/Hp/.ssh/id_ed25519.pub")
}

# ----------------------------
# Security Group
# ----------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH and DevOps tools"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-sg"
  }
}

# ----------------------------
# Instance 1: Jenkins Server
# ----------------------------
resource "aws_instance" "jenkins_server" {
  ami                         = "ami-08982f1c5bf93d976"
  instance_type               = "t2.large"
  key_name                    = aws_key_pair.mykey.key_name
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
                yum update -y

              sudo yum install git -y
  
              # Install Docker

              echo ">>> Installing Docker..."
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user
            

              # Jenkins Installation
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo

              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

              yum install -y java-21-amazon-corretto jenkins

              systemctl enable jenkins
              systemctl start jenkins

              # Allow Jenkins to use Docker
              usermod -aG docker jenkins
              systemctl restart jenkins

              # Install NodeJS
              curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -

              yum install -y nodejs

              # Install Trivy
              wget https://github.com/aquasecurity/trivy/releases/download/v0.70.0/trivy_0.70.0_Linux-64bit.tar.gz

              tar -xzf trivy_0.70.0_Linux-64bit.tar.gz

              mv trivy /usr/local/bin/

              chmod +x /usr/local/bin/trivy

              # SonarQube Requirements
              sysctl -w vm.max_map_count=262144

              echo "vm.max_map_count=262144" >> /etc/sysctl.conf

              # Run SonarQube Container
              docker run -d --name sonarqube \
                -p 9000:9000 \
                -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
                --restart always \
                sonarqube:lts-community
              EOF

  tags = {
    Name = "jenkins-server"
  }
}

# ----------------------------
# Instance 2: K8s Server
# ----------------------------
resource "aws_instance" "k8s_server" {
  ami                         = "ami-08982f1c5bf93d976"
  instance_type               = "t2.xlarge"
  key_name                    = aws_key_pair.mykey.key_name
  subnet_id                   = aws_subnet.subnet2.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash

              yum update -y

              yum install -y curl wget git tar unzip docker

              systemctl start docker
              systemctl enable docker

              usermod -aG docker ec2-user

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -sSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

              chmod +x kubectl

              mv kubectl /usr/local/bin/

              # Install eksctl
              curl -sSL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz -o eksctl.tar.gz

              tar -xzf eksctl.tar.gz

              mv eksctl /usr/local/bin/

              # Install Helm
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

              # Add Helm Repositories
              helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

              helm repo add grafana https://grafana.github.io/helm-charts

              helm repo add argo https://argoproj.github.io/argo-helm

              helm repo update
              EOF

  tags = {
    Name = "k8s-server"
  }
}
---
