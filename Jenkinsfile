// Windows Jenkins agent — uses bat steps directly.
pipeline {
    agent any

    parameters {
        choice(name: 'BROWSER', choices: ['chromium', 'firefox', 'webkit'], description: 'Browser project to run')
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        // All runs share one test account (and its server-side cart), so never run builds in parallel.
        disableConcurrentBuilds()
    }

    environment {
        CI = 'true'
        BASE_URL = 'https://rahulshettyacademy.com'
    }

    stages {
        stage('Check tools') {
            steps {
                bat 'node -v'
                bat 'npm -v'
            }
        }

        stage('Install dependencies') {
            steps {
                bat 'npm ci'
            }
        }

        stage('Install browser') {
            steps {
                bat "npx playwright install ${params.BROWSER}"
            }
        }

        stage('Run tests') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'rsa-app-login',
                                                  usernameVariable: 'APP_USER',
                                                  passwordVariable: 'APP_PASSWORD')]) {
                    bat "npx playwright test --project=${params.BROWSER}"
                }
            }
        }
    }

    post {
        always {
            junit testResults: 'test-results/junit.xml', allowEmptyResults: true
            archiveArtifacts artifacts: 'playwright-report/**, screenshots/**, test-results/**', allowEmptyArchive: true
            publishHTML(target: [
                reportName           : 'Playwright Report',
                reportDir            : 'playwright-report',
                reportFiles          : 'index.html',
                keepAll              : true,
                alwaysLinkToLastBuild: true,
                allowMissing         : true
            ])
        }
    }
}
