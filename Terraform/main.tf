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
}

# ----------------------------
# Subnets
# ----------------------------
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
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
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

# Key Pair (use your existing public key)
resource "aws_key_pair" "mykey" {
  key_name   = "project"
  public_key = file("C:/Users/Hp/.ssh/id_ed25519.pub")
}

# Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH and HTTP"

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
    description = "prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "app"
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
}

# ----------------------------
# Instance 1: jenkins
# ----------------------------
resource "aws_instance" "Jenkins_server" {
  ami           = "ami-08982f1c5bf93d976" # Amazon Linux 2 (us-east-1)
  instance_type = "t2.large"
  key_name      = aws_key_pair.mykey.key_name
  subnet_id     = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

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
              sudo usermod -aG docker $USER

              # Install Jenkins

              echo ">>> Installing Jenkins..."

              sudo yum update -y
              sudo wget -O /etc/yum.repos.d/jenkins.repo  https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              sudo yum upgrade
              sudo yum install java-21-amazon-corretto -y
              sudo yum install jenkins -y
              sudo systemctl enable jenkins
              sudo systemctl start jenkins


              # Install Trivy

              echo ">>> Installing Trivy..."
              sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.56.2_Linux-64bit.rpm


              # Install SonarQube (with Docker)

              echo ">>> Installing SonarQube using Docker..."

             # Fix required kernel setting
             sudo sysctl -w vm.max_map_count=262144
             echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

            # Remove old container if exists
            sudo docker rm -f sonarqube || true

            # Run SonarQube (updated version)
            sudo docker run -d --name sonarqube \
            -p 9000:9000 \
            -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
            --restart always \
            sonarqube:community

              # Install Node.js + npm

              echo ">>> Installing Node.js & npm..."
              curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
              sudo yum install -y nodejs


              # Final Info

              echo ">>> Installation Completed!"
              echo "Jenkins running on: http://<your-server-ip>:8080"
              echo "SonarQube running on: http://<your-server-ip>:9000"
              echo "Use 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword' for Jenkins password."
              EOF

  tags = {
    Name = "jenkins-Server"
  }
}

# ----------------------------
# Instance 2: k8s Server
# ----------------------------
resource "aws_instance" "k8s_server" {
  ami           = "ami-08982f1c5bf93d976"
  instance_type = "t2.xlarge"
  key_name      = aws_key_pair.mykey.key_name
  subnet_id     = aws_subnet.subnet2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  associate_public_ip_address = true

  root_block_device {
  volume_size = 30
  volume_type = "gp3"
}

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              
              # Install dependencies

              echo ">>> Installing required packages..."
              sudo yum install -y curl wget git tar

              # Install kubectl

              echo ">>> Installing kubectl..."
              curl -LO "https://dl.k8s.io/release/$(curl -sSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              chmod +x kubectl
              sudo mv kubectl /usr/local/bin/
              kubectl version --client
              curl -sSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" -o eksctl.tar.gz
              tar -xzf eksctl.tar.gz
              sudo mv eksctl /usr/local/bin/
              eksctl version


              # Install Helm

              echo ">>> Installing Helm..."
              curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


              # Add Helm Repos

              echo ">>> Adding Helm repositories..."
              helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
              helm repo add grafana https://grafana.github.io/helm-charts
              helm repo add argo https://argoproj.github.io/argo-helm
              helm repo update

              EOF

  tags = {
    Name = "k8s-Server"
  }
}
