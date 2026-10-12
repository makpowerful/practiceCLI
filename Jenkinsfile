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

            // Allure report in Jenkins for detailed analysis (the plugin generates, publishes and archives it)
            allure includeProperties: false, results: [[path: 'allure-results']]

            archiveArtifacts artifacts: 'allure-results/**, playwright-report/**, screenshots/**', allowEmptyArchive: true

            // Zip the Playwright HTML report into one file so it can be attached to the email
            bat 'if exist playwright-report powershell -NoProfile -Command "Compress-Archive -Path playwright-report\\* -DestinationPath playwright-report.zip -Force"'

            publishHTML(target: [
                reportName           : 'Playwright Report',
                reportDir            : 'playwright-report',
                reportFiles          : 'index.html',
                keepAll              : true,
                alwaysLinkToLastBuild: true,
                allowMissing         : true
            ])

            emailext(
                to: 'mak_powerful@yahoo.co.in',
                subject: "Playwright CI - ${currentBuild.currentResult}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                mimeType: 'text/html',
                attachmentsPattern: 'playwright-report.zip',
                body: """
                    <p>Build result: <b>${currentBuild.currentResult}</b></p>
                    <ul>
                        <li>Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}</li>
                        <li>Browser: ${params.BROWSER}</li>
                        <li>Allure report (detailed analysis): <a href="${env.BUILD_URL}allure/">${env.BUILD_URL}allure/</a></li>
                        <li>Playwright HTML report (in Jenkins): <a href="${env.BUILD_URL}Playwright_20Report/">open</a></li>
                        <li>Console log: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></li>
                    </ul>
                    <p>The Playwright HTML report is attached as <b>playwright-report.zip</b> — unzip and open index.html.</p>
                """.stripIndent()
            )
        }
    }
}
