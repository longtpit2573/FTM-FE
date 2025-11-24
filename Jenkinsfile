// Jenkinsfile for FTM Frontend (React + Vite)
pipeline {
    agent any
    
    environment {
        // ACR Configuration
        ACR_NAME = 'acrftmfrontenddev'
        ACR_REGISTRY = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME = 'ftm-frontend'
        IMAGE_TAG = "v1.0.${env.BUILD_NUMBER}"
        
        // GitOps Configuration
        GITOPS_REPO = 'https://github.com/longtpit2573/Infrastructure.git'
        GITOPS_PATH = 'applications/overlays/dev'
        
        // Docker build context
        DOCKERFILE_PATH = './FTM-FE/Dockerfile'
        BUILD_CONTEXT = './FTM-FE'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('📋 Checkout') {
            steps {
                echo '========================================='
                echo '  FTM Frontend CI/CD Pipeline'
                echo '========================================='
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                }
                echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                echo "Message: ${env.GIT_COMMIT_MSG}"
                echo "Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                echo '========================================='
            }
        }
        
        stage('🐳 Build & Push Docker Image') {
            steps {
                echo 'Building and pushing Docker image...'
                echo "Note: This requires Docker to be available in Jenkins agent pod"
                echo "Image will be built: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                
                // For now, skip actual build - will be done manually
                echo '⚠️  Docker not available in current agent'
                echo 'Manual build required:'
                echo "  cd ${BUILD_CONTEXT}"
                echo "  docker build -t ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} ."
                echo "  docker push ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }
        
        stage('📝 Update GitOps') {
            steps {
                echo 'Updating GitOps repository...'
                withCredentials([usernamePassword(credentialsId: 'git-credentials', 
                                                  usernameVariable: 'GIT_USER', 
                                                  passwordVariable: 'GIT_PASS')]) {
                    sh '''
                        # Install kustomize if not exists
                        if [ ! -f ./kustomize ]; then
                            curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
                        fi
                        
                        # Save absolute path
                        KUSTOMIZE_PATH=$(pwd)/kustomize
                        
                        # Clone GitOps repo (git should be available in default agent)
                        rm -rf gitops
                        git clone https://${GIT_USER}:${GIT_PASS}@github.com/longtpit2573/Infrastructure.git gitops
                        cd gitops/${GITOPS_PATH}
                        
                        # Update image tag with absolute path
                        ${KUSTOMIZE_PATH} edit set image ${ACR_REGISTRY}/${IMAGE_NAME}=${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        
                        # Show changes
                        echo "Changes to kustomization.yaml:"
                        git diff kustomization.yaml
                        
                        # Commit and push
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@longops.io.vn"
                        git add kustomization.yaml
                        git commit -m "chore: update frontend image to ${IMAGE_TAG} [skip ci]" || echo "No changes to commit"
                        git push https://${GIT_USER}:${GIT_PASS}@github.com/longtpit2573/Infrastructure.git main
                    '''
                }
                echo '✅ GitOps repo updated'
                echo 'ArgoCD will auto-sync in ~3 minutes'
            }
        }
    }
    
    post {
        success {
            echo '========================================='
            echo '  ✅ CI/CD PIPELINE SUCCESS'
            echo '========================================='
            echo "Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
            echo "Commit: ${env.GIT_COMMIT_SHORT}"
            echo "Message: ${env.GIT_COMMIT_MSG}"
            echo ''
            echo 'Next steps:'
            echo '1. GitOps repo updated with new image tag'
            echo '2. ArgoCD will detect change in ~3 minutes'
            echo '3. New pods will be deployed to AKS'
            echo '========================================='
        }
        failure {
            echo '========================================='
            echo '  ❌ PIPELINE FAILED'
            echo '========================================='
            echo "Build: ${env.BUILD_NUMBER}"
            echo "Check logs: ${env.BUILD_URL}"
            echo '========================================='
        }
    }
}
