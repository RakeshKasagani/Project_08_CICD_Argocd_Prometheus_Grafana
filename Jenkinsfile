pipeline {
    agent any

    stages {
    stage('Checkout Code') {
        steps {
            echo 'scm git'
            git branch: 'main', url: 'https://github.com/RakeshKasagani/Project_08_CICD_Argocd_Prometheus_Grafana.git'
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
                          -Dsonar.host.url=http://32.197.223.131:9000/ \
                          -Dsonar.login=squ_78d1843e5b167bcc412823a4b65e50ecf1d90c8d
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
        sh 'docker build -t rakesh/nodejs:${BUILD_NUMBER} .'
        }
    }
}
		
     stage('docker image scan'){
     steps{
         sh "trivy image rakesh/nodejs:${BUILD_NUMBER}"
     }
 }		


stage('Push image to ECR') {
    steps {
        withAWS(credentials: 'aws-creds', region: 'us-east-1') {
            script {
                sh '''
                  aws ecr get-login-password --region us-east-1 \
                  | docker login --username AWS --password-stdin 436735645837.dkr.ecr.us-east-1.amazonaws.com
                  
                   docker tag rakesh/nodejs:${BUILD_NUMBER} 436735645837.dkr.ecr.us-east-1.amazonaws.com/nodejs:${BUILD_NUMBER}
                   docker push 436735645837.dkr.ecr.us-east-1.amazonaws.com/nodejs:${BUILD_NUMBER}
                '''
            }
        }
    }
}
       stage('Update Deployment File') {
		
		 environment {
            GIT_REPO_NAME = "Project_7"
            GIT_USER_NAME = "rakesh"
        }
		
            steps {
                echo 'Update Deployment File'
				withCredentials([string(credentialsId: 'githubtoken', variable: 'githubtoken')]) 
				{
                  sh '''
                    git config user.email "rakesh@gmail.com"
                    git config user.name "rakesh"
                    BUILD_NUMBER=${BUILD_NUMBER}
                   #sed -i "s/mc:.*/mc:${BUILD_NUMBER}/g" deploymentfiles/deployment.yml
					sed -i "s|image: .*|image: 436735645837.dkr.ecr.us-east-1.amazonaws.com/nodejs:$BUILD_NUMBER|" deploymentfiles/deployment.yml
                    git add .
                    
                    git commit -m "Update deployment image to version ${BUILD_NUMBER}"

                    git push https://${githubtoken}@github.com/RakeshKasagani/Project_08_CICD_Argocd_Prometheus_Grafana.git HEAD:main
                '''
				  
                 }
				
            }
        }

  }
}
