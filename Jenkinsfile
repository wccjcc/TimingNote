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
        MATTERMOST_WEBHOOK_CRED_ID = "mattermost-webhook-url"
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
                    AWS_ACCESS_KEY_ID
                    AWS_SECRET_ACCESS_KEY
                    AWS_REGION
                    AWS_S3_BUCKET
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
                        docker compose --env-file "$APP_ENV_FILE" -f "$APP_COMPOSE_FILE" run --rm flyway
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
                    if (s == 'SUCCESS') return '\u2705'
                    if (s == 'FAILED') return '\u274C'
                    return '\u23ED'
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

                // Fallback: if build succeeded but stage flags were not updated,
                // treat them as success for a clean summary message.
                if (currentBuild.currentResult == 'SUCCESS'
                        && env.ENV_STATUS == 'SKIPPED'
                        && env.MIGRATION_STATUS == 'SKIPPED'
                        && env.DEPLOY_STATUS == 'SKIPPED') {
                    env.ENV_STATUS = 'SUCCESS'
                    env.MIGRATION_STATUS = 'SUCCESS'
                    env.DEPLOY_STATUS = 'SUCCESS'
                }

                def envLine = "${iconFor(env.ENV_STATUS)} Env   : ${env.ENV_STATUS}"
                def migrationLine = "${iconFor(env.MIGRATION_STATUS)} Flyway: ${env.MIGRATION_STATUS}"
                def deployLine = "${iconFor(env.DEPLOY_STATUS)} Deploy: ${env.DEPLOY_STATUS}"

                def overallOk = (currentBuild.currentResult == 'SUCCESS')
                def title = overallOk ? '\u2705 CI/CD SUCCESS' : '\u274C CI/CD FAILURE'
                def stageInfo = overallOk ? '' : "- Failed Stage: ${env.FAILED_STAGE ?: 'unknown'}"

                def branchName = (env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'unknown').replaceFirst('^origin/', '')
                def lines = [
                        "${title} (${branchName})",
                        "",
                        envLine,
                        migrationLine,
                        deployLine
                ]
                if (stageInfo) {
                    lines << stageInfo
                }
                lines += [
                        "",
                        "- Commit: ${(env.GIT_COMMIT ?: 'unknown').take(8)}",
                        "- Tag: ${env.BUILD_TAG}",
                        "- Build: #${env.BUILD_NUMBER}",
                        "👉 ${env.BUILD_URL}"
                ]
                def text = lines.join('\n')

                def payload = groovy.json.JsonOutput.toJson([
                        username  : 'Jenkins',
                        icon_emoji: overallOk ? ':white_check_mark:' : ':x:',
                        text      : text
                ])

                withCredentials([string(credentialsId: "${env.MATTERMOST_WEBHOOK_CRED_ID}", variable: "MM_WEBHOOK_URL")]) {
                    writeFile file: 'mattermost-payload.json', text: payload
                    sh """
                        set +e
                        curl -sS -X POST -H 'Content-Type: application/json' \\
                          --data @mattermost-payload.json \\
                          "\$MM_WEBHOOK_URL" >/dev/null
                    """
                }
            }

            sh '''
                set +e
                rm -f "$APP_ENV_FILE"
                rm -f mattermost-payload.json
            '''
        }
    }
}
