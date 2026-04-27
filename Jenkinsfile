pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '30'))
    }

    environment {
        APP_COMPOSE_FILE = "docker-compose.app.yml"
        APP_ENV_FILE = ".env.prod"
        ENV_STATUS = "SKIPPED"
        MIGRATION_STATUS = "SKIPPED"
        DEPLOY_STATUS = "SKIPPED"
        FAILED_STAGE = ""
    }

    stages {
        stage("Checkout") {
            steps {
                checkout scm
            }
        }

        stage("Inject env.prod") {
            steps {
                script {
                    env.FAILED_STAGE = "Inject env.prod"
                }
                withCredentials([file(credentialsId: "timingnote-env-prod", variable: "ENV_PROD_FILE")]) {
                    sh '''
                        set -eu
                        cp "$ENV_PROD_FILE" "$APP_ENV_FILE"
                        chmod 600 "$APP_ENV_FILE"
                    '''
                }
                script {
                    env.ENV_STATUS = "SUCCESS"
                }
            }
        }

        stage("Validate env.prod keys") {
            steps {
                sh '''
                    set -eu
                    required_keys="
                    SPRING_PROFILES_ACTIVE
                    DB_NAME
                    DB_USERNAME
                    DB_PASSWORD
                    RABBITMQ_USERNAME
                    RABBITMQ_PASSWORD
                    DEVICE_SECRET_PEPPER
                    AI_INTERNAL_SECRET
                    GMS_KEY
                    GMS_BASE_URL
                    MAIN_MODEL
                    STT_MODEL
                    "

                    for key in $required_keys; do
                      if ! grep -q "^${key}=" "$APP_ENV_FILE"; then
                        echo "Missing required key in $APP_ENV_FILE: $key"
                        exit 1
                      fi
                    done

                    profile="$(grep '^SPRING_PROFILES_ACTIVE=' "$APP_ENV_FILE" | cut -d'=' -f2 | tr -d '\\r')"
                    if [ "$profile" != "prod" ]; then
                      echo "SPRING_PROFILES_ACTIVE must be 'prod' for deployment. current=$profile"
                      exit 1
                    fi
                '''
            }
        }

        stage("Validate Compose") {
            steps {
                sh '''
                    set -eu
                    docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" config >/dev/null
                '''
            }
        }

        stage("Build Images") {
            steps {
                sh '''
                    set -eu
                    docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" build --pull
                '''
            }
        }

        stage("Start Dependencies") {
            steps {
                sh '''
                    set -eu
                    docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" up -d postgres redis rabbitmq elasticsearch fastapi
                '''
            }
        }

        stage("Flyway Migrate (must run once)") {
            steps {
                script {
                    env.FAILED_STAGE = "Flyway Migrate (must run once)"
                }
                timeout(time: 10, unit: 'MINUTES') {
                    sh '''
                        set -eu
                        docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" run --rm \
                          -e SPRING_PROFILES_ACTIVE=prod \
                          -e SPRING_MAIN_WEB_APPLICATION_TYPE=none \
                          springboot
                    '''
                }
                script {
                    env.MIGRATION_STATUS = "SUCCESS"
                }
            }
        }

        stage("Deploy Spring Boot") {
            steps {
                script {
                    env.FAILED_STAGE = "Deploy Spring Boot"
                }
                sh '''
                    set -eu
                    docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" up -d springboot
                '''
                script {
                    env.DEPLOY_STATUS = "SUCCESS"
                }
            }
        }
    }

    post {
        always {
            script {
                def iconFor = { String s ->
                    if (s == 'SUCCESS') return '[OK]'
                    if (s == 'FAILED') return '[FAIL]'
                    return '[SKIP]'
                }

                if (currentBuild.currentResult != 'SUCCESS') {
                    if (env.ENV_STATUS != 'SUCCESS') {
                        env.ENV_STATUS = 'FAILED'
                    } else if (env.MIGRATION_STATUS != 'SUCCESS') {
                        env.MIGRATION_STATUS = 'FAILED'
                    } else if (env.DEPLOY_STATUS != 'SUCCESS') {
                        env.DEPLOY_STATUS = 'FAILED'
                    }
                }

                def envLine = "${iconFor(env.ENV_STATUS)} Env Inject : ${env.ENV_STATUS}"
                def migrationLine = "${iconFor(env.MIGRATION_STATUS)} Flyway     : ${env.MIGRATION_STATUS}"
                def deployLine = "${iconFor(env.DEPLOY_STATUS)} Deploy     : ${env.DEPLOY_STATUS}"

                def overallOk = (currentBuild.currentResult == 'SUCCESS')
                def title = overallOk ? 'CI/CD SUCCESS' : 'CI/CD FAILURE'
                def stageInfo = overallOk ? '' : "\\n- Failed Stage: ${env.FAILED_STAGE ?: 'unknown'}"

                def branchName = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'unknown').replaceFirst('^origin/', '')
                def text = "${title} (${branchName})\\n\\n" +
                        "${envLine}\\n${migrationLine}\\n${deployLine}" +
                        "${stageInfo}\\n\\n" +
                        "- Build: #${env.BUILD_NUMBER}\\n" +
                        "- URL: ${env.BUILD_URL}"

                def payload = groovy.json.JsonOutput.toJson([
                        username  : 'Jenkins',
                        icon_emoji: overallOk ? ':white_check_mark:' : ':x:',
                        text      : text
                ])

                withCredentials([string(credentialsId: "mattermost-webhook-url", variable: "MM_WEBHOOK_URL")]) {
                    sh """
                        set +e
                        curl -sS -X POST -H 'Content-Type: application/json' \\
                          -d '${payload.replace("'", "'\"'\"'")}' \\
                          "\$MM_WEBHOOK_URL" >/dev/null
                    """
                }
            }

            sh '''
                set +e
                rm -f "$APP_ENV_FILE"
            '''
        }
    }
}
