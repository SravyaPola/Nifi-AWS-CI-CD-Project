pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-creds')
        AWS_SECRET_ACCESS_KEY = credentials('aws-creds')
        NIFI_ARTIFACT_URL = 'https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip'
        NIFI_ZIP_NAME     = 'nifi-1.26.0-bin.zip'
        REMOTE_NIFI_ZIP   = '/home/ubuntu/nifi-1.26.0-bin.zip'
    }

    stages {
        stage('Clean Workspace') { steps { cleanWs() } }

        stage('Checkout Code') {
            steps {
                git url: 'https://github.com/SravyaPola/Nifi-AWS-CI-CD-Project.git', branch: 'main'
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps { sh 'bash scripts/gen-inventory.sh' }
        }

        stage('Install Java') {
            steps {
                sshagent (credentials: ['nifi-ssh-key']) {
                    sh 'ansible-playbook -i inventory.ini ansible/playbooks/install-java.yml'
                }
            }
        }

        stage('Download NiFi Artifact') {
            steps {
                sh 'curl -L -o ${NIFI_ZIP_NAME} ${NIFI_ARTIFACT_URL}'
            }
        }

        stage('Copy NiFi Zip to EC2') {
            steps {
                script {
                    env.EC2_PUBLIC_IP = sh(
                        script: 'terraform -chdir=terraform output -raw nifi_public_ip',
                        returnStdout: true
                    ).trim()
                }
                sshagent (credentials: ['nifi-ssh-key']) {
                    sh '''
                        scp -o StrictHostKeyChecking=no ${NIFI_ZIP_NAME} ubuntu@${EC2_PUBLIC_IP}:${REMOTE_NIFI_ZIP}
                    '''
                }
            }
        }

        stage('Deploy & Start NiFi') {
            steps {
                sshagent (credentials: ['nifi-ssh-key']) {
                    sh 'ansible-playbook -i inventory.ini ansible/playbooks/deploy-nifi.yml'
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
