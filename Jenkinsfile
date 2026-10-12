// Windows Jenkins agent - uses bat steps directly.
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

            // Build a JS-free HTML summary for the email (Gmail blocks the interactive report's JS)
            withEnv(["BUILD_RESULT=${currentBuild.currentResult}"]) {
                bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\make_email_report.ps1'
            }

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
                attachmentsPattern: 'email-report.html',
                body: """
                    <p>Build result: <b>${currentBuild.currentResult}</b></p>
                    <ul>
                        <li>Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}</li>
                        <li>Browser: ${params.BROWSER}</li>
                        <li>Allure report (detailed analysis): <a href="${env.BUILD_URL}allure/">${env.BUILD_URL}allure/</a></li>
                        <li>Playwright HTML report (interactive, in Jenkins): <a href="${env.BUILD_URL}Playwright_20Report/">open</a></li>
                        <li>Console log: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></li>
                    </ul>
                    <p>A JS-free HTML test summary is attached as <b>email-report.html</b>. The full interactive Playwright report (which needs JavaScript and so cannot be emailed) and the Allure report are on the Jenkins build page above.</p>
                """.stripIndent()
            )
        }

        failure {
            // Auto-create (or comment on) a Jira bug when the build fails.
            withCredentials([usernamePassword(credentialsId: 'jira-api',
                                              usernameVariable: 'JIRA_USER',
                                              passwordVariable: 'JIRA_TOKEN')]) {
                bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\create_jira_bug.ps1'
            }
        }
    }
}
