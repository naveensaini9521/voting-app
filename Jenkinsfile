pipeline {
    agent any
    triggers {
        // Triggers the job via GitHub Webhook on every push
        githubPush() 
    }
    environment {
        DOCKER_CREDENTIALS_ID = 'dockerhub-creds'
        GIT_CRED_ID = 'github-pat'
        DOCKER_USERNAME = 'naveen9521'
        IMAGE_NAME = 'vote-app-project'
        NAMESPACE = 'voting-app'
    }

    stages {
        
        stage('Verify Cluster') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                sh '''
                    echo "========== Cluster Nodes =========="
                    kubectl set image deployment/vote -n voting-app vote=docker.io/naveen9521/vote-app-project:latest
                    kubectl rollout restart deployment/vote -n voting-app
                    echo ""
                    echo "========== Pods in ${NAMESPACE} =========="
                    kubectl get pods -n ${NAMESPACE}
                    echo ""
                    echo "========== Services in ${NAMESPACE} =========="
                    kubectl get svc -n ${NAMESPACE}
                '''
                }
            }
        }
        
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/naveensaini9521/voting-app.git',
                    credentialsId: "${GIT_CRED_ID}"
            }
        }

        stage('Change Detection') {
            steps {
                script {
                    def changedFiles = sh(
                        script: "git diff --name-only HEAD~1 HEAD || true",
                        returnStdout: true
                    ).trim()
                    def touchesVote = changedFiles.split('\n').any { it.startsWith('vote/') }
                    if (!touchesVote) {
                        echo "No changes under vote/** — skipping pipeline."
                        currentBuild.result = 'NOT_BUILT'
                        error("Aborting: no vote/** changes.")
                    }
                }
            }
        }

        stage('Auto Versioning') {
            steps {
                script {
                    def latestTag = sh(
                        script: "git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0'",
                        returnStdout: true
                    ).trim()
                    
                    def versionStr = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag
                    def bits = versionStr.tokenize('.')
                    def major = bits[0].toInteger()
                    def minor = bits[1].toInteger()
                    def patch = bits[2].toInteger()
                    
                    def commitLog = sh(script: "git log --format=%s -n 5", returnStdout: true).trim().toLowerCase()
                    
                    if (commitLog.contains('breaking change:') || commitLog.contains('feat!')) {
                        major++; minor = 0; patch = 0
                    } else if (commitLog.contains('feat:') || commitLog.contains('feature:')) {
                        minor++; patch = 0
                    } else {
                        patch++
                    }
                    
                    env.NEW_TAG = "v${major}.${minor}.${patch}"
                    env.IMAGE_TAG = "${major}.${minor}.${patch}"
                    env.FULL_IMAGE = "${DOCKER_USERNAME}/${IMAGE_NAME}:${env.IMAGE_TAG}"
                    
                    echo "New version: ${env.NEW_TAG}"
                    echo "Image: ${env.FULL_IMAGE}"
                }
            }
        }

        stage('Lint: Python') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
        
                    pip install --upgrade pip
                    pip install flake8
        
                    flake8 vote/ \
                        --count \
                        // --exit-zero \
                        --max-complexity=10 \
                        --max-line-length=120 \
                        --statistics
                '''
            }
        }

        stage('Lint: Kubernetes Manifests') {
            steps {
                sh '''
                    curl -sSLo kubeconform.tar.gz \
                      https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
                    tar -xzf kubeconform.tar.gz kubeconform
                    ./kubeconform -strict -summary k8s-specifications/*.yaml
                '''
            }
        }

        stage('Build & Push Image') {
            steps {
                sh 'docker build -t ${FULL_IMAGE} -t ${DOCKER_USERNAME}/${IMAGE_NAME}:latest ./vote'

                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDENTIALS_ID,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        // docker push ${FULL_IMAGE}
                        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }
        
        stage('Verify Cluster') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                sh '''
                    echo "========== Cluster Nodes =========="
                    kubectl set image deployment/vote -n voting-app vote=docker.io/naveen9521/vote-app-project:latest
                    kubectl rollout restart deployment/vote -n voting-app
                    echo ""
                    echo "========== Pods in ${NAMESPACE} =========="
                    kubectl get pods -n ${NAMESPACE}
                    echo ""
                    echo "========== Services in ${NAMESPACE} =========="
                    kubectl get svc -n ${NAMESPACE}
                '''
                }
            }

            }

        stage('Smoke Test') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {

                sh '''
                    kubectl port-forward -n ${NAMESPACE} svc/vote 18080:80 > /tmp/pf.log 2>&1 &
                    PF_PID=$!
                    sleep 5
                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18080/)
                    kill -9 $PF_PID 2>/dev/null || true
                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "SMOKE TEST FAILED — expected 200, got ${HTTP_CODE}"
                        exit 1
                    fi
                    echo "Smoke test passed!"
                '''
                }
            }
        }

        stage('Tag Release') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${GIT_CRED_ID}",
                    usernameVariable: 'GIT_USER',
                    passwordVariable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@localhost"
                        git remote set-url origin https://${GIT_USER}:${GIT_TOKEN}@github.com/naveensaini9521/voting-app.git
                        git tag -a ${NEW_TAG} -m "Release ${NEW_TAG} - Build #${BUILD_NUMBER}"
                        git push origin ${NEW_TAG}
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded — ${FULL_IMAGE} deployed and verified!"
            echo "Tagged as: ${NEW_TAG}"
        }
        failure {
            echo "Pipeline failed."
        
            sh '''
                kubectl get all -n ${NAMESPACE} || true
                kubectl describe svc vote -n ${NAMESPACE} || true
                kubectl get endpoints vote -n ${NAMESPACE} || true
                kubectl describe deployment vote -n ${NAMESPACE} || true
                kubectl logs -l app=vote -n ${NAMESPACE} --tail=100 || true
            '''
        }
        always {
            sh '''
                minikube stop || true
                minikube delete || true
                rm -rf .ci-manifests .venv kubeconform kubeconform.tar.gz || true
            '''
            cleanWs()
        }
    }
}