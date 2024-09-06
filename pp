pipeline {
    agent { label 'agent93' }  

    parameters {
        string(name: 'AWS_ACCESS_KEY_ID', defaultValue: '', description: 'AWS Access Key ID')
        string(name: 'AWS_SECRET_ACCESS_KEY', defaultValue: '', description: 'AWS Secret Access Key')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS Region')
        string(name: 'STEAMPIPE_PORT', defaultValue: '9194', description: 'Port for Steampipe')
        string(name: 'POWERPIPE_PORT', defaultValue: '9040', description: 'Port for Powerpipe')
        string(name: 'IMAGE_NAME', defaultValue: 'pp-sp-img', description: 'Docker image for Powerpipe and Steampipe')
        string(name: 'DOCKER_NETWORK', defaultValue: '', description: 'Docker Network Name (optional)')
        string(name: 'CONTAINER_NAME', defaultValue: '', description: 'Container Name (optional)')
    }

    environment {
        AWS_ACCESS_KEY_ID = "${params.AWS_ACCESS_KEY_ID}"
        AWS_SECRET_ACCESS_KEY = "${params.AWS_SECRET_ACCESS_KEY}"
        AWS_REGION = "${params.AWS_REGION}"
        STEAMPIPE_PORT = "${params.STEAMPIPE_PORT}"
        POWERPIPE_PORT = "${params.POWERPIPE_PORT}"
        IMAGE_NAME = "${params.IMAGE_NAME}"

        DOCKER_NETWORK = "${params.DOCKER_NETWORK ?: 'aws_default_network'}"
        CONTAINER_NAME_BASE = "${params.CONTAINER_NAME ?: 'default_container'}"
    }

    stages {
        stage('Check AWS Credentials') {
            steps {
                script {
                    def awsCheck = sh (
                        script: "aws sts get-caller-identity --region ${AWS_REGION}",
                        returnStatus: true
                    )
                    if (awsCheck != 0) {
                        error "Invalid AWS Credentials"
                    }
                }
            }
        }

        stage('Check Port Availability') {
            steps {
                script {
                    def isPortAvailable = { port ->
                        def result = sh (
                            script: "netstat -tuln | grep -q ':${port} '",
                            returnStatus: true
                        )
                        return result == 1
                    }

                    if (!isPortAvailable(STEAMPIPE_PORT)) {
                        error "Port ${STEAMPIPE_PORT} is already in use."
                    }

                    if (!isPortAvailable(POWERPIPE_PORT)) {
                        error "Port ${POWERPIPE_PORT} is already in use."
                    }

                    echo "Both Steampipe Port (${STEAMPIPE_PORT}) and Powerpipe Port (${POWERPIPE_PORT}) are available."
                }
            }
        }

        stage('Create Docker Network') {
            steps {
                script {
                    def networkExists = sh (
                        script: "docker network ls --filter name=${DOCKER_NETWORK} --format '{{.Name}}'",
                        returnStdout: true
                    ).trim()

                    if (networkExists == "") {
                        sh "docker network create ${DOCKER_NETWORK}"
                        echo "Created Docker network: ${DOCKER_NETWORK}"
                    } else {
                        echo "Docker network already exists: ${DOCKER_NETWORK}"
                    }
                }
            }
        }

        stage('Run Docker Container') {
            steps {
                script {
                    def containerName = ""
                    for (int i = 1; i <= 3; i++) {
                        def candidateName = "${CONTAINER_NAME_BASE}_${i}"
                        def containerExists = sh (
                            script: "docker ps -a --filter name=${candidateName} --format '{{.Names}}'",
                            returnStdout: true
                        ).trim()

                        if (containerExists == "") {
                            containerName = candidateName
                            break
                        }
                    }

                    if (containerName == "") {
                        error "All containers (${CONTAINER_NAME_BASE}_1, ${CONTAINER_NAME_BASE}_2, ${CONTAINER_NAME_BASE}_3) are already in use."
                    }

                    echo "Selected container name: ${containerName}"

                    sh """
                    docker run -d --name ${containerName} \\
                      --network ${DOCKER_NETWORK} \\
                      -p ${STEAMPIPE_PORT}:${STEAMPIPE_PORT} \\
                      -p ${POWERPIPE_PORT}:${POWERPIPE_PORT} \\
                      -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \\
                      -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \\
                      -e AWS_REGION=${AWS_REGION} \\
                      ${IMAGE_NAME}
                    """
                }
            }
        }

        stage('Initialize and Install Modules') {
            steps {
                script {
                    sh """
                    docker exec -it ${containerName} /bin/bash -c '
                    mkdir -p /home/powerpipe/mod && cd /home/powerpipe/mod &&
                    powerpipe mod init &&
                    powerpipe mod install github.com/turbot/steampipe-mod-aws-compliance &&
                    steampipe query "select * from aws_s3_bucket;"
                    '
                    """
                }
            }
        }

        stage('Start Services') {
            steps {
                script {
                    sh """
                    docker exec -d ${containerName} /bin/bash -c '
                    nohup steampipe service start --port ${STEAMPIPE_PORT} > /home/powerpipe/steampipe.log 2>&1 &
                    nohup powerpipe server --port ${POWERPIPE_PORT} > /home/powerpipe/powerpipe.log 2>&1 &
                    '
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                echo "Containers created but not deleted in this pipeline run."
            }
        }
    }
}
