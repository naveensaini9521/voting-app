pipeline {
    agent any

    environment {
        DOCKER_CREDENTIALS_ID = 'dockerhub-credentials'
        KUBECONFIG_CRED_ID = 'kubeconfig-jenkins-token'

        DOCKER_USERNAME = 'naveen9521'
        IMAGE_NAME = 'vote-app-project'
        NAMESPACE = 'voting-app'

        IMAGE_TAG = "${BUILD_NUMBER}"
        FULL_IMAGE = "${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Lint') {
            steps {
                sh '''
                python3 -m venv .venv
                . .venv/bin/activate

                pip install --upgrade pip
                pip install flake8

                flake8 vote/app.py --count --max-complexity=10 --statistics || true
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t ${FULL_IMAGE} ./vote
                '''
            }
        }

        stage('Push Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CREDENTIALS_ID}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {

                    sh '''
                    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

                    docker push ${FULL_IMAGE}

                    docker logout
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {

                withKubeConfig([credentialsId: "${KUBECONFIG_CRED_ID}"]) {

                    sh '''

                    kubectl create namespace ${NAMESPACE} \
                    --dry-run=client -o yaml | kubectl apply -f -

                    kubectl apply -f k8s-specifications/secrets.yaml -n ${NAMESPACE}

                    kubectl set image deployment/vote \
                    vote=${FULL_IMAGE} \
                    -n ${NAMESPACE} || true

                    kubectl apply -f k8s-specifications/ -n ${NAMESPACE}

                    kubectl rollout status deployment/vote \
                    -n ${NAMESPACE} --timeout=300s
                    '''
                }
            }
        }

        stage('Verify') {
            steps {

                withKubeConfig([credentialsId: "${KUBECONFIG_CRED_ID}"]) {

                    sh '''
                    kubectl get pods -n ${NAMESPACE}

                    kubectl get svc -n ${NAMESPACE}
                    '''
                }
            }
        }

        stage('Smoke Test') {

            steps {

                withKubeConfig([credentialsId: "${KUBECONFIG_CRED_ID}"]) {

                    sh '''

                    NODE_PORT=$(kubectl get svc vote \
                    -n ${NAMESPACE} \
                    -o jsonpath='{.spec.ports[0].nodePort}')

                    MINIKUBE_IP=$(minikube ip)

                    curl -f http://${MINIKUBE_IP}:${NODE_PORT}/

                    '''
                }
            }
        }

    }

    post {

        success {

            echo "Deployment Successful"
        }

        failure {

            withKubeConfig([credentialsId: "${KUBECONFIG_CRED_ID}"]) {

                sh '''

                kubectl get pods -n ${NAMESPACE}

                kubectl describe pods -n ${NAMESPACE}

                '''
            }
        }

        always {

            cleanWs()
        }
    }
}