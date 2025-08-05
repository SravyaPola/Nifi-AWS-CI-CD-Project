pipeline {
  agent any

  environment {
    AWS_REGION   = 'us-east-2'
    S3_BUCKET    = 'my-nifi-artifacts'
    NIFI_VERSION = '1.26.0'
  }

  stages {
    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            sh '''
              export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
              export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
              terraform init
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
        sshagent(['nifi-ssh-key']) {
          sh 'ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml'
        }
      }
    }

    stage('Deploy NiFi') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sshagent(['nifi-ssh-key']) {
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
          credentialsId: 'aws-creds',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          script {
            def acctId   = sh(
              script: "aws sts get-caller-identity --query Account --output text --region ${AWS_REGION}",
              returnStdout: true
            ).trim()
            def registry = "${acctId}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            def repo     = "nifi-custom"
            def imageTag = "${NIFI_VERSION}"
            env.FULL_TAG = "${registry}/${repo}:${imageTag}"

            sh """
              mkdir -p docker
              aws s3 cp \
                s3://${S3_BUCKET}/nifi-${imageTag}-bin.zip \
                docker/nifi-${imageTag}-bin.zip \
                --region ${AWS_REGION}

              aws ecr describe-repositories \
                --repository-names ${repo} \
                --region ${AWS_REGION} \
              || aws ecr create-repository \
                --repository-name ${repo} \
                --region ${AWS_REGION}

              aws ecr get-login-password --region ${AWS_REGION} \
              | docker login --username AWS --password-stdin ${registry}

              docker build \
                --build-arg NIFI_ZIP=nifi-${imageTag}-bin.zip \
                -t ${env.FULL_TAG} \
                docker/

              docker push ${env.FULL_TAG}
            """
          }
        }
      }
    }
  }

  post {
    success {
      script {
        def ip = sh(
          script: 'terraform -chdir=terraform output -raw nifi_public_ip',
          returnStdout: true
        ).trim()
        echo "=============================="
        echo "NiFi is up at: http://${ip}:8080/nifi"
        echo "Docker image pushed to ECR: ${env.FULL_TAG}"
        echo "=============================="
      }
    }
    failure {
      echo 'Build, deployment or containerization failed. Check the logs for details.'
    }
  }
}
