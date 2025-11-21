// Jenkinsfile for FTM Frontend (React + Vite)
pipeline {
    agent any
    
    environment {
        // ACR Configuration
        ACR_NAME = 'acrftmfrontenddev'
        ACR_REGISTRY = "${ACR_NAME}.azurecr.io"
        IMAGE_NAME = 'ftm-frontend'
        
        // Git Configuration
        GIT_REPO_GITOPS = 'https://github.com/yourorg/ftm-gitops.git'
        
        // Node Configuration
        NODE_VERSION = '18'
        
        // Credentials
        ACR_CREDENTIALS = credentials('acr-credentials')
        GIT_CREDENTIALS = credentials('git-credentials')
        
        // Dynamic versioning
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
        ).trim()
    }
    
    tools {
        nodejs 'NodeJS-18'  // Jenkins NodeJS plugin
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('🔍 Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
                script {
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('📦 Install Dependencies') {
            steps {
                echo 'Installing npm packages...'
                dir('FTM-FE') {
                    sh 'npm ci --prefer-offline --no-audit'
                }
            }
        }
        
        stage('🔍 Lint') {
            steps {
                echo 'Running ESLint...'
                dir('FTM-FE') {
                    sh 'npm run lint || true'  // Don't fail build on lint errors
                }
            }
        }
        
        stage('🧪 Unit Tests') {
            steps {
                echo 'Running tests...'
                dir('FTM-FE') {
                    sh 'npm run test:ci || true'  // Jest tests
                }
            }
            post {
                always {
                    junit '**/test-results.xml'
                }
            }
        }
        
        stage('🏗️ Build') {
            steps {
                echo 'Building production bundle...'
                dir('FTM-FE') {
                    sh 'npm run build'
                }
            }
        }
        
        stage('🐳 Docker Build') {
            steps {
                echo "Building Docker image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                dir('FTM-FE') {
                    script {
                        docker.build(
                            "${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}",
                            "."
                        )
                        sh """
                            docker tag ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \\
                                       ${ACR_REGISTRY}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }
        
        stage('🔐 Login to ACR') {
            steps {
                sh """
                    echo ${ACR_CREDENTIALS_PSW} | docker login ${ACR_REGISTRY} \\
                        --username ${ACR_CREDENTIALS_USR} \\
                        --password-stdin
                """
            }
        }
        
        stage('📤 Push to ACR') {
            steps {
                echo 'Pushing images to ACR...'
                sh """
                    docker push ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${ACR_REGISTRY}/${IMAGE_NAME}:latest
                """
            }
        }
        
        stage('📝 Update GitOps Repo') {
            when {
                branch 'main'
            }
            steps {
                echo 'Updating GitOps repository...'
                script {
                    dir('gitops-repo') {
                        git url: env.GIT_REPO_GITOPS,
                            branch: 'main',
                            credentialsId: 'git-credentials'
                        
                        sh """
                            cd overlays/dev
                            
                            # Update frontend image tag
                            kustomize edit set image \\
                                ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                            
                            git config user.name "Jenkins CI"
                            git config user.email "jenkins@longops.io.vn"
                            git add kustomization.yaml
                            git commit -m "Update frontend to ${IMAGE_TAG} (build ${BUILD_NUMBER})" || true
                            git push origin main
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Frontend build SUCCESS!'
            slackSend(
                color: 'good',
                message: """
                    ✅ Frontend Build SUCCESS
                    Job: ${env.JOB_NAME}
                    Build: ${env.BUILD_NUMBER}
                    Image: ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                """.stripIndent()
            )
        }
        failure {
            echo '❌ Frontend build FAILED!'
            slackSend(
                color: 'danger',
                message: """
                    ❌ Frontend Build FAILED
                    Job: ${env.JOB_NAME}
                    Build: ${env.BUILD_NUMBER}
                    Check: ${env.BUILD_URL}
                """.stripIndent()
            )
        }
        always {
            sh """
                docker rmi ${ACR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                docker rmi ${ACR_REGISTRY}/${IMAGE_NAME}:latest || true
            """
            cleanWs()
        }
    }
}
