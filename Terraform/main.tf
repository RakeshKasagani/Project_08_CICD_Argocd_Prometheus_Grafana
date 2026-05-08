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
              yum install -y git docker wget curl unzip tar

              # Start Docker
              systemctl start docker
              systemctl enable docker

              # Add users to Docker group
              usermod -aG docker ec2-user

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
