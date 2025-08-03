pipeline {
  agent any

  environment {
    AWS_REGION = 'us-east-2'
    S3_BUCKET = 'my-nifi-artifacts'
  }

  stages {
    stage('Terraform Apply') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
            usernameVariable: 'AWS_ACCESS_KEY_ID',
            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          dir('terraform') {
            // Pass AWS creds to Terraform
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

    stage('Install Java') {
      steps {
        sshagent(['nifi-ssh-key']) {
          sh 'ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml'
        }
      }
    }

    stage('Deploy NiFi') {
      steps {
        // Export AWS creds so Ansible can access S3!
        withCredentials([usernamePassword(credentialsId: 'aws-creds',
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
        echo "=============================="
      }
    }
    failure {
      echo 'Build or deployment failed. Check the logs for details.'
    }
  }
}
