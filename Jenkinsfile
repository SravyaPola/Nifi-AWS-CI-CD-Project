pipeline {
  agent any

  environment {
    AWS_REGION   = 'us-east-2'
    S3_BUCKET    = 'my-nifi-artifacts'
    NIFI_VERSION = '1.26.0'
    AWS_CREDS    = 'aws-creds'      
    SSH_KEY      = 'nifi-ssh-key'    
  }

  stages {
    stage('Prepare') {
        steps {
            cleanWs()
            checkout scm
        }
    }
    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            sh '''
              export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
              export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
              terraform init -upgrade
              terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Generate Inventory') {
      steps {
        sh 'bash scripts/gen-inventory.sh'
      }
    }

    stage('Wait for SSH') {
      steps {
        script {
          def publicIp = sh(
            script: 'terraform -chdir=terraform output -raw nifi_public_ip',
            returnStdout: true
          ).trim()
          sh "for i in {1..30}; do nc -zv $publicIp 22 && exit 0; sleep 10; done; exit 1"
        }
      }
    }

    stage('Install Java') {
      steps {
        sshagent([env.SSH_KEY]) {
          sh 'ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml'
        }
      }
    }

    stage('Deploy NiFi') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sshagent([env.SSH_KEY]) {
            sh '''
              export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
              export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
              ansible-playbook -i inventory.ini ansible/playbooks/deploy-nifi.yml \
                --extra-vars "s3_bucket=${S3_BUCKET} region=${AWS_REGION}"
            '''
          }
        }
      }
    }

    stage('Containerize & Push to ECR') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          script {
            def acctId = sh(
              script: "aws sts get-caller-identity --query Account --output text --region ${AWS_REGION}",
              returnStdout: true
            ).trim()
            def registry = "${acctId}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            def repo     = "nifi-custom"
            def tag      = "${NIFI_VERSION}"
            env.FULL_TAG = "${registry}/${repo}:${tag}"

            sh """
              mkdir -p docker
              aws s3 cp s3://${S3_BUCKET}/nifi-${tag}-bin.zip docker/
              aws ecr describe-repositories --repository-names ${repo} --region ${AWS_REGION} \
                || aws ecr create-repository --repository-name ${repo} --region ${AWS_REGION}

              aws ecr get-login-password --region ${AWS_REGION} \
                | docker login --username AWS --password-stdin ${registry}

              docker build --build-arg NIFI_ZIP=nifi-${tag}-bin.zip \
                -t ${env.FULL_TAG} docker/
              docker push ${env.FULL_TAG}
            """
          }
        }
      }
    }

    stage('Configure kubectl for EKS') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sh '''
            aws eks --region ${AWS_REGION} \
              update-kubeconfig --name $(terraform -chdir=terraform output -raw eks_cluster_name)
          '''
        }
      }
    }

    stage('Deploy NiFi to EKS') {
      steps {
        sh '''
          kubectl apply -f k8s/nifi-namespace.yaml
          export FULL_TAG=${FULL_TAG}
          envsubst < k8s/nifi-deployment.yaml | kubectl apply -n nifi -f -
          kubectl apply -n nifi -f k8s/nifi-service.yaml
        '''
      }
    }

    stage('Expose Endpoints') {
      steps {
        script {
          def ec2Ip = sh(
            script: 'terraform -chdir=terraform output -raw nifi_public_ip',
            returnStdout: true
          ).trim()
          def eksHost = sh(
            script: "kubectl -n nifi get svc nifi -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
            returnStdout: true
          ).trim()
          echo "NiFi on EC2 → http://${ec2Ip}:8080/nifi"
          echo "NiFi on EKS → http://${eksHost}:8080/nifi"
        }
      }
    }
  }

  post {
    failure {
      echo 'Build or deployment failed – check the logs!'
    }
  }
}
