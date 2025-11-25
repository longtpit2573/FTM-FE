// Jenkinsfile for FTM Frontend (React + Vite)
// 
// Architecture:
// - Runs on Kubernetes agent pod with Docker CLI and kubectl
// - Pod template 'docker-builder' defined in Jenkins Configuration as Code (JCasC)
// - Multi-stage pipeline: Checkout → Docker Build → Push to ACR → Update GitOps
// - Triggers ArgoCD auto-sync for deployment to AKS

pipeline {
    agent {
        label 'docker-builder'  // Use the pod template with Docker support
    }

    environment {
        // ACR Configuration
        ACR_NAME = 'acrftmfrontenddev'
        ACR_REGISTRY = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME = 'ftm-frontend'
        IMAGE_TAG = "v1.0.${env.BUILD_NUMBER}"
        
        // GitOps Configuration
        GITOPS_REPO = 'https://github.com/longtpit2573/Infrastructure.git'
        GITOPS_PATH = 'applications/overlays/dev'
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('📋 Checkout') {
            steps {
                script {
                    echo '========================================='
                    echo '  FTM Frontend CI/CD Pipeline'
                    echo '========================================='
                    
                    checkout scm
                    
                    env.GIT_COMMIT_SHORT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                    
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    
                    echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Message: ${env.GIT_COMMIT_MSG}"
                    echo "Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    echo '========================================='
                }
            }
        }
        
        stage('🐳 Build & Push with Kaniko') {
            steps {
                container('kaniko') {
                    script {
                        echo 'Building frontend image with Kaniko...'
                        
                        // Get ACR credentials and create Docker config
                        withCredentials([usernamePassword(
                            credentialsId: 'acr-frontend-credentials',
                            usernameVariable: 'ACR_USER',
                            passwordVariable: 'ACR_PASS'
                        )]) {
                            sh """
                                echo "Creating Docker config for ACR authentication..."
                                
                                # Create Docker config.json for Kaniko
                                mkdir -p /kaniko/.docker
                                
                                # Encode credentials properly (base64 without newlines)
                                AUTH=\$(printf "%s:%s" "\${ACR_USER}" "\${ACR_PASS}" | base64 -w 0)
                                
                                cat > /kaniko/.docker/config.json <<EOF
{
  "auths": {
    "${ACR_REGISTRY}": {
      "auth": "\${AUTH}"
    }
  }
}
EOF
                                
                                echo "Docker config created successfully"
                            """
                        }
                        
                        // Build and push with Kaniko
                        sh """
                            echo "Building and pushing frontend image with Kaniko..."
                            echo "Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                            echo "Build context: \$(pwd)"
                            
                            # Verify Dockerfile exists
                            ls -la Dockerfile
                            
                            /kaniko/executor \\
                              --context=\$(pwd) \\
                              --dockerfile=\$(pwd)/Dockerfile \\
                              --destination=${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \\
                              --destination=${ACR_REGISTRY}/${IMAGE_NAME}:latest \\
                              --cache=true \\
                              --cache-ttl=24h \\
                              --compressed-caching=false \\
                              --snapshot-mode=redo \\
                              --log-format=text \\
                              --verbosity=info
                            
                            echo "✅ Frontend image built and pushed successfully with Kaniko"
                        """
                    }
                }
            }
        }
        
        stage('📝 Update GitOps Repository') {
            steps {
                script {
                    echo 'Updating GitOps repository with new frontend image tag...'
                    
                    withCredentials([usernamePassword(
                        credentialsId: 'git-credentials', 
                        usernameVariable: 'GIT_USER', 
                        passwordVariable: 'GIT_PASS'
                    )]) {
                        sh '''
                            set -e
                            
                            echo "Installing kustomize..."
                            if [ ! -f ./kustomize ]; then
                                curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
                            fi
                            
                            chmod +x ./kustomize
                            KUSTOMIZE_PATH=$(pwd)/kustomize
                            echo "Kustomize path: ${KUSTOMIZE_PATH}"
                            
                            ${KUSTOMIZE_PATH} version
                            
                            echo "Cloning GitOps repository..."
                            rm -rf gitops
                            git clone https://${GIT_USER}:${GIT_PASS}@github.com/longtpit2573/Infrastructure.git gitops
                            
                            cd gitops/${GITOPS_PATH}
                            
                            echo "Current kustomization.yaml:"
                            cat kustomization.yaml
                            
                            echo ""
                            echo "Updating frontend image tag..."
                            ${KUSTOMIZE_PATH} edit set image ${ACR_REGISTRY}/${IMAGE_NAME}=${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                            
                            echo ""
                            echo "Changes to kustomization.yaml:"
                            git diff kustomization.yaml
                            
                            git config user.name "Jenkins CI"
                            git config user.email "jenkins@longops.io.vn"
                            
                            git add kustomization.yaml
                            
                            if git diff --staged --quiet; then
                                echo "No changes to commit"
                            else
                                git commit -m "chore: update frontend image to ${IMAGE_TAG} [skip ci]"
                                
                                echo "Pushing changes to GitOps repository..."
                                git push https://${GIT_USER}:${GIT_PASS}@github.com/longtpit2573/Infrastructure.git main
                                
                                echo "✅ GitOps repository updated successfully"
                            fi
                        '''
                    }
                    
                    echo '✅ GitOps repo updated'
                    echo '⏳ ArgoCD will auto-sync in ~3 minutes'
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo '========================================='
                echo '  ✅ CI/CD PIPELINE SUCCESS'
                echo '========================================='
                echo "Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                echo "Commit: ${env.GIT_COMMIT_SHORT}"
                echo "Message: ${env.GIT_COMMIT_MSG}"
                echo ''
                echo 'Next steps:'
                echo '1. ✅ Docker image built and pushed to ACR'
                echo '2. ✅ GitOps repo updated with new image tag'
                echo '3. ⏳ ArgoCD will detect change in ~3 minutes'
                echo '4. ⏳ New pods will be deployed to AKS'
                echo ''
                echo "View deployment:"
                echo "  kubectl get pods -n ftm-production -w"
                echo ''
                echo "View ArgoCD app:"
                echo "  kubectl get application ftm-frontend -n argocd"
                echo '========================================='
            }
        }
        failure {
            script {
                echo '========================================='
                echo '  ❌ PIPELINE FAILED'
                echo '========================================='
                echo "Build: ${env.BUILD_NUMBER}"
                echo "Commit: ${env.GIT_COMMIT_SHORT}"
                echo "Check logs: ${env.BUILD_URL}console"
                echo ''
                echo 'Common issues:'
                echo '1. Check Docker daemon is running in pod'
                echo '2. Verify ACR credentials are correct'
                echo '3. Ensure Git credentials have push access'
                echo '4. Check network connectivity to ACR and GitHub'
                echo '5. Frontend build errors (check npm dependencies)'
                echo '========================================='
            }
        }
        cleanup {
            script {
                echo 'Cleaning up workspace...'
                sh 'rm -rf gitops kustomize || true'
            }
        }
    }
}
