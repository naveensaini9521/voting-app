pipeline {
    agent any
    triggers {
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
        
                    echo "========== Changed Files =========="
                    echo changedFiles
        
                    def touchesVote = changedFiles.split("\\n").any {
                        it.startsWith("vote/")
                    }
        
                    if (!touchesVote) {
                        currentBuild.result = 'NOT_BUILT'
                        error("Aborting: no vote/** changes.")
                    }
        
                    echo "Changes detected in vote/. Continuing..."
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
                    flake8 vote/ --count --max-complexity=10 --max-line-length=120 --statistics --exit-zero
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
                sh '''
                    export DOCKER_BUILDKIT=1
        
                    docker build -t ${FULL_IMAGE} -t ${DOCKER_USERNAME}/${IMAGE_NAME}:latest ./vote
                '''
        
                withCredentials([usernamePassword(
                    credentialsId: env.DOCKER_CREDENTIALS_ID,
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${FULL_IMAGE}
                        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy to Fresh kind Cluster & Smoke Test') {
            steps {
                sh '''#!/bin/bash
                    set -euo pipefail
        
                    echo "===== Create fresh kind cluster ====="
                    kind delete cluster --name vote-ci || true
                    kind create cluster --name vote-ci --wait 300s
        
                    echo "===== Verify cluster ====="
                    kubectl cluster-info
                    kubectl get nodes
        
                    echo "===== Load Docker image into kind ====="
                    kind load docker-image ${FULL_IMAGE} --name vote-ci
        
                    echo "===== Create namespace ====="
                    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
        
                    echo "===== Deploy vote service ====="
                    kubectl apply -f k8s-specifications/ -n ${NAMESPACE}
                    kubectl set image deployment/vote vote=${FULL_IMAGE} -n ${NAMESPACE}
        
                    echo "===== Wait for deployment ====="
                    kubectl rollout status deployment/vote -n ${NAMESPACE} --timeout=180s
        
                    echo "===== Smoke Test ====="
                    kubectl port-forward svc/vote -n ${NAMESPACE} 8080:80 >/tmp/port-forward.log 2>&1 &
                    PF_PID=$!
                    trap "kill $PF_PID 2>/dev/null || true" EXIT
        
                    sleep 10
                    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/)
        
                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "Smoke test failed! Expected HTTP 200 but got ${HTTP_CODE}"
                        kubectl get pods -n ${NAMESPACE}
                        kubectl describe deployment vote -n ${NAMESPACE}
                        kubectl logs deployment/vote -n ${NAMESPACE} --tail=100
                        exit 1
                    fi
        
                    echo "Smoke test passed (HTTP 200)"
                '''
            }
        }

        stage('Tag Release') {
            // when {
            //     branch 'main'
            // }
            steps {
                withCredentials([string(
                    credentialsId: env.GIT_CRED_ID,
                    variable: 'GIT_TOKEN'
                )]) {
                    sh '''
                        set -e
                        
                        echo "Creating tag: ${NEW_TAG}"
                        
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@localhost"
                        git remote set-url origin https://naveensaini9521:${GIT_TOKEN}@github.com/naveensaini9521/voting-app.git
                        git fetch --tags
                        
                        if git rev-parse -q --verify "refs/tags/${NEW_TAG}" >/dev/null 2>&1; then
                            echo "Tag ${NEW_TAG} already exists. Skipping."
                        else
                            git tag -a "${NEW_TAG}" -m "Release ${NEW_TAG} - Build #${BUILD_NUMBER} - Image ${FULL_IMAGE}"
                            git push origin "${NEW_TAG}"
                            echo "Tag ${NEW_TAG} pushed successfully"
                        fi
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
            withCredentials([file(credentialsId: 'minikube-kubeconfig', variable: 'KUBECONFIG')]) {
                sh '''
                    kubectl get all -n ${NAMESPACE} || true
                    kubectl describe svc vote -n ${NAMESPACE} || true
                    kubectl get endpoints vote -n ${NAMESPACE} || true
                    kubectl describe deployment vote -n ${NAMESPACE} || true
                    kubectl logs -l app=vote -n ${NAMESPACE} --tail=100 || true
                '''
            }
        }
        always {
            sh '''
                rm -rf .ci-manifests .venv kubeconform kubeconform.tar.gz || true
            '''
            cleanWs()
        }
    }
}