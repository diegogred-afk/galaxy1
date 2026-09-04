pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Deploy Galaxium') {
            steps {
                sh '''
                    ssh -o BatchMode=yes -o StrictHostKeyChecking=no diego@host.minikube.internal '
                        cd /home/diego/galaxium-travels-copy &&
                        git pull --ff-only galaxy main &&
                        docker compose --profile hold-service up -d --build
                    '
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    ssh -o BatchMode=yes diego@host.minikube.internal '
                        cd /home/diego/galaxium-travels-copy &&
                        docker compose --profile hold-service ps
                    '
                '''
            }
        }
    }
}
