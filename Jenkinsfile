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

    stage('Cache Terraform Outputs') {
      steps {
        script {
          env.EKS_CLUSTER_NAME = sh(script: 'terraform -chdir=terraform output -raw eks_cluster_name', returnStdout: true).trim()
          env.SUBNET_IDS_RAW = sh(script: 'terraform -chdir=terraform output -raw subnet_ids', returnStdout: true).trim()
          env.NIFI_PUBLIC_IP = sh(script: 'terraform -chdir=terraform output -raw nifi_public_ip', returnStdout: true).trim()
          env.SUBNET_IDS = env.SUBNET_IDS_RAW.replaceAll(',', ' ')
          echo "Cluster Name: ${env.EKS_CLUSTER_NAME}"
          echo "Subnets: ${env.SUBNET_IDS}"
          echo "EC2 NiFi Public IP: ${env.NIFI_PUBLIC_IP}"
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
          sh """
            for i in {1..30}; do
              nc -zv ${env.NIFI_PUBLIC_IP} 22 && exit 0
              echo 'Waiting for SSH to be available...'
              sleep 10
            done
            echo 'ERROR: SSH port 22 not available after timeout'
            exit 1
          """
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

    stage('Configure kubectl & Tag Subnets') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sh """
            aws eks --region ${AWS_REGION} \
              update-kubeconfig --name ${EKS_CLUSTER_NAME}

            aws ec2 create-tags \
              --resources ${SUBNET_IDS} \
              --tags Key=kubernetes.io/role/elb,Value=1
          """
        }
      }
    }

    stage('Install EBS CSI Driver') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sh """
            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

            aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER_NAME}

            kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.26"

            kubectl rollout status daemonset/aws-ebs-csi-driver -n kube-system --timeout=3m
          """
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

    stage('Deploy NiFi to EKS') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
          sh '''
            set -e
            export FULL_TAG=${FULL_TAG}
            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

            kubectl apply -f k8s/nifi-namespace.yaml
            kubectl apply -f k8s/gp2-csi.yaml
            envsubst < k8s/nifi-deployment.yaml | kubectl apply -n nifi -f -
            kubectl rollout status statefulset/nifi -n nifi --timeout=5m
            kubectl apply -f k8s/nifi-service.yaml -n nifi
          '''
        }
      }
    }

    stage('Expose Endpoints') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: env.AWS_CREDS,
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY'
        )]) {
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

  }

  post {
    failure {
      echo 'Build or deployment failed – check the logs!'
    }
  }
}