pipeline {
  agent any

  environment {
    AWS_REGION = 'us-east-2'
    S3_BUCKET = 'my-nifi-artifacts'
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
          sh "for i in {1..30}; do nc -zv $publicIp 22 && exit 0; sleep 5; done; exit 1"
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
            sh '''
                AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
                --query Account --output text --region ${AWS_REGION})
                ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                ECR_REPO="nifi-custom"
                IMAGE_TAG="${NIFI_VERSION}"
                FULL_TAG="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

                mkdir -p docker
                aws s3 cp \
                s3://${S3_BUCKET}/nifi-${IMAGE_TAG}-bin.zip \
                docker/nifi-${IMAGE_TAG}-bin.zip \
                --region ${AWS_REGION}

                aws ecr describe-repositories \
                    --repository-names ${ECR_REPO} \
                    --region ${AWS_REGION} \
                || aws ecr create-repository \
                    --repository-name ${ECR_REPO} \
                    --region ${AWS_REGION}

                aws ecr get-login-password --region ${AWS_REGION} \
                | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                docker build \
                --build-arg NIFI_ZIP=nifi-${IMAGE_TAG}-bin.zip \
                -t ${FULL_TAG} \
                docker/

                docker push ${FULL_TAG}
            '''
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
