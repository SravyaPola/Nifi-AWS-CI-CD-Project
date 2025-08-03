pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-2'
        NIFI_BUCKET        = 'my-nifi-artifacts'
        NIFI_VERSION       = '1.26.0'
    }

    stages {
        stage('Clean & Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'aws-creds',
                            usernameVariable: 'AWS_ACCESS_KEY_ID',
                            passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                        )
                    ]) {
                        sh """
                            terraform init
                            terraform apply -auto-approve \
                                -var="aws_region=${AWS_DEFAULT_REGION}" \
                                -var="s3_bucket_name=${NIFI_BUCKET}"
                        """
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
                    env.EC2_IP = sh(
                        script: "terraform -chdir=terraform output -raw nifi_public_ip",
                        returnStdout: true
                    ).trim()
                    // Retry SSH connect up to 10 times, sleeping 10s between tries
                    retry(10) {
                        echo "Waiting for SSH on ${env.EC2_IP}:22..."
                        sleep 10
                        sh "nc -zv ${env.EC2_IP} 22"
                    }
                }
            }
        }

        stage('Install Java') {
            steps {
                sshagent(['nifi-ssh-key']) {
                    sh """
                        ansible-playbook \
                            -i inventory.ini \
                            ansible/playbooks/install-java.yml \
                            --extra-vars "aws_region=${AWS_DEFAULT_REGION}"
                    """
                }
            }
        }

        stage('Deploy NiFi') {
            steps {
                sshagent(['nifi-ssh-key']) {
                    sh """
                        ansible-playbook \
                            -i inventory.ini \
                            ansible/playbooks/deploy-nifi.yml \
                            --extra-vars "s3_bucket_name=${NIFI_BUCKET} aws_region=${AWS_DEFAULT_REGION}"
                    """
                }
            }
        }
    }

    post {
        success {
            script {
                def ip = sh(
                    script: "terraform -chdir=terraform output -raw nifi_public_ip",
                    returnStdout: true
                ).trim()
                echo "=================================================="
                echo "NiFi UI should be up at: http://${ip}:8080/nifi"
                echo "=================================================="
            }
        }
        failure {
            echo 'Build or deployment failed. Check the logs for details.'
        }
    }
}
