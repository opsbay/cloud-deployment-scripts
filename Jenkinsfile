#!/usr/bin/env groovy
// Jenkinsfile for cloud-deployment-scripts

// Thanks https://stackoverflow.com/a/4244184/424301
Random random = new Random()
def captchaLeft = random.nextInt(12) + 1
def captchaRight = random.nextInt(12) + 1
def String captchaAnswer = (captchaLeft * captchaRight)
def captchaAnswerHash = ((captchaAnswer as Integer) ^ 123456789).toString()

def captchaQuestion = """Solve CAPTCHA to apply production changes or to destroy anything:
What do you get when you multiply ${captchaLeft} by ${captchaRight}?
"""

properties([
    parameters([
        choiceParam(name: 'awsAccount',
                     description: 'Target AWS Account',
                     choices: [
                        "hobsons-naviancedev",
                        "hobsons-navianceprod",
                     ].join("\n")),
        booleanParam(name: 'runPacker',
                     description: 'Attempt to run Packer?',
                     defaultValue: false),
        booleanParam(name: 'applyPlan',
                     defaultValue: false,
                     description: 'Attempt to Apply Terraform Plan?'),
        booleanParam(name: 'destroy',
                     defaultValue: false,
                     description: '***** Use with extreme caution ***** Attempt to Destroy Infrastructure?'),
        booleanParam(name: 'targetVPC',
                     description: 'Only Target the VPC module (helps resolve circular dependencies)?',
                     defaultValue: false),
        stringParam(name: 'targets',
                     description: 'Run Terraform vs. specific targets? (modules or other Resource Addresses, see https://www.terraform.io/docs/internals/resource-addressing.html) Separate module names with spaces, or leave blank for all addresses. Example: "module.vpc"',
                     defaultValue: ''),
        booleanParam(name: 'rotateServers',
                     defaultValue: false,
                     description: 'Attempt to rotate servers after Terrform?'),
        stringParam(name: 'serversToRotate',
                    defaultValue: 'tf-blue-ridge-api-qa-asg',
                    description: 'Auto Scaling Group to rotate (can use trailing wildcard, as in "tf-*")'),
        stringParam(name: 'captchaGuess',
                    defaultValue: '',
                    description: captchaQuestion),
        stringParam(name: 'captchaAnswerHash',
                    defaultValue: captchaAnswerHash,
                    description: "CAPTCHA answer hash (do not modify)"),
    ])
])

def shortaccount = params.awsAccount.split('-')[1]
currentBuild.displayName = "#${BUILD_NUMBER}: ${shortaccount} "

def aws_account_credentials = (params.awsAccount=='hobsons-navianceprod') ?  'unmanaged-jenkins-terraform-prod' : 'unmanaged-jenkins-terraform'

def wrapStep = { steps ->
    withCredentials([usernamePassword(credentialsId: aws_account_credentials,
                                      passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                                      usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm', 'defaultFg': 1, 'defaultBg': 2]) {
              // This is the current syntax for invoking a build wrapper, naming the class.
              wrap([$class: 'TimestamperBuildWrapper']) {
                  steps()
              }
        }
    }
}

void sendHipchatNotification(String message, Boolean notify = false, String color = null) {
    def time = "after ${currentBuild.durationString}"
    def result = currentBuild.result ?: ''
    def decoded_job_name=java.net.URLDecoder.decode(env.JOB_NAME, "UTF-8");
    switch (currentBuild.result) {
        case 'SUCCESS':
            color = color ?: 'GREEN'
            break
        case 'FAILURE':
            notify = true
            color = color ?: 'RED'
            break
        case 'UNSTABLE':
            color = color ?: 'YELLOW'
            notify = true
            break
        case 'ABORTED':
            color = color ?: 'GRAY'
            notify = true
            break
        case 'NOT_BUILT':
            color = color ?: 'GRAY'
            break
        default:
            color = color ?: 'PURPLE'
            break
    }

    message =  """
               ${message}<br/>
               <a href=\"$env.BUILD_URL\">${decoded_job_name} #${env.BUILD_NUMBER}</a><br/>
               ${result} ${time}
               """
    hipchatSend color: color,
                notify: notify,
                room: "Naviance Modernization Notification Room",
                message: message
}


def actions = []

def reallyApply = false

env.BRANCH_NAME = env.BRANCH_NAME ?: 'master'

def runStages = { mainBuild ->
    stage("Validate") {
        def message = ""
        actions.push("validate")
        if (params.destroy && params.applyPlan) {
            message += "Either pick applyPlan or destroy, not both. "
        } else if (params.destroy || (params.applyPlan && params.awsAccount == "hobsons-navianceprod")) {
            if (! params.captchaGuess) {
                message += "No CAPTCHA guess detected. "
            } else {
                def Integer guess = params.captchaGuess as Integer
                def Integer answer = (params.captchaAnswerHash as Integer) ^ 123456789
                def guessHash = (guess ^ 123456789).toString()
                if (guess != answer) {
                    message += "CAPTCHA answer was wrong. guess: ${guess} answer: ${answer} guessHash: ${guessHash} answerHash: ${params.captchaAnswerHash}. "
                }
            }
        }
        if (params.awsAccount == "hobsons-navianceprod" && 
            "${env.BRANCH_NAME}" != "master") {
          message += "You may only run terraform against ${params.awsAccount} from the master branch. "
        }
        if (params.awsAccount == "hobsons-navianceprod" &&
            "${env.JOB_NAME}" != "Build-and-Deploy/cloud-deployment-scripts-deploy") {
          message += "You may only run terraform against ${params.awsAccount} from the [main deploy job](https://jenkins.devops.naviance.com/job/Build-and-Deploy/job/cloud-deployment-scripts-deploy/). "
        }
        if (message != "") {
            echo message
            sendHipchatNotification(message,false,'YELLOW')
            currentBuild.result = 'UNSTABLE'
            currentBuild.description = message
        }
    }
    if (currentBuild.result != 'UNSTABLE') {
        mainBuild()
    }
}

def mainBuild = {
    node {
        stage("Checkout") {
            actions.push("checkout")
            git url: 'git@github.com:naviance/cloud-deployment-scripts.git', credentialsId: 'github-hobsonsbuildserver-ssh', branch: "${env.BRANCH_NAME}"
            sh 'git clean -fdx && cp env.sh.sample env.sh'

            def author = sh (
                script: 'git --no-pager show -s --format=%ae',
                returnStdout: true
            ).trim()
            def revision = sh (
                script: 'git describe --always --tags --long',
                returnStdout: true
            ).trim()
            currentBuild.description = [
                "${revision} by ${author}"
            ].join("\n")
        }
        stage("Run Linters") {
            actions.push("lint")
                wrapStep({
                    sh 'make'
                    stash includes: '**', excludes: '.git/', name: 'src'
                })
        }
    }
    if (params.runPacker) {
        stage("Run Packer") {
            actions.push("pack")
            node {
                unstash 'src'
                wrapStep({
                    sh '''
                       set -euo pipefail
                       source ./env.sh
                       cd packer
                       make
                       cd ..
                       # The docker container will emit some root owned files
                       # and archiving those will go badly
                       sudo chown "$USER" .
                       '''
                })
            }
        }
    }
    stage ("Generate Terraform Plan") {
        actions.push("plan")
        node {
            unstash 'src'
            env.TARGET_VPC_ONLY = params.targetVPC
            env.MODULES = params.targets
            wrapStep({
                dir('terraform') {
                    def destroyParam = params.destroy ? " -destroy" : ""
                    sh "./run_terraform.sh plan${destroyParam}"
                }
                // The docker container for packer may have emitted some root owned files
                // and archiving those will go badly
                sh 'sudo chown "$USER" .'
            })
            stash includes: 'terraform/*.plan', name: 'plan'
            // Stash any files starting with 'tf-plan-dep-', we will need them when we run the apply
            stash includes: 'terraform/**/tf-plan-dep-*', name: 'plan_dependencies', allowEmpty: true
        }
    }
    if (params.applyPlan || params.destroy) {
        stage("Operator Review") {
            // This strategy did not work due to a sandbox access exception on getting the exception cause:
            // https://support.cloudbees.com/hc/en-us/articles/226554067-Pipeline-How-to-add-an-input-step-with-timeout-that-continues-if-timeout-is-reached-using-a-default-value
            // So instead we will use a strategy much like naviance-db does where we ask at the start whether we want
            // to do a mutation.
            try {
                actions.push("review")
                timeout(time: 30, unit: 'MINUTES') {
                    def destroyMessage = "DESTROY INFRASTRUCTURE in ${params.awsAccount}? Use with EXTREME caution!!!"
                    def applyMessage = "Apply Plan vs. ${params.awsAccount}?"
                    feedback = params.destroy ? destroyMessage : applyMessage

                    sendHipchatNotification("Feedback Required: ${feedback}", true)
                    input message: "${feedback}", ok: 'Apply'
                    reallyApply = true
                    }
            } catch (err) {
                currentBuild.result = 'UNSTABLE'
                throw err
            }
        }
    }
    if (reallyApply) {
        def stageName
        if (params.applyPlan) {
            actions.push("apply")
            stageName = "Apply"
        }
        if (params.destroy) {
            actions.push("destroy")
            stageName = "Destroy"
        }
        echo "${stageName} Terraform Plan in ${params.awsAccount}"
        stage("${stageName} Terraform Plan") {
            node {
                unstash 'src'
                unstash 'plan'
                unstash 'plan_dependencies'
                wrapStep({
                    dir('terraform') {
                        sh "./run_terraform.sh apply tf-plan-${BUILD_NUMBER}.plan"

                        if (params.awsAccount == "hobsons-navianceprod") {
                            sh "mkdir -p ../build && ../bin/manage-codedeploy-permissions.sh generate > ../build/codedeploy-policy.json"
                            withCredentials([usernamePassword(credentialsId: "unmanaged-jenkins-terraform",
                                    passwordVariable: 'AWS_SECRET_ACCESS_KEY',
                                    usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                                sh "../bin/manage-codedeploy-permissions.sh install < ../build/codedeploy-policy.json"
                            }
                        }
                    }
                })
            }
        }
    }
    if (params.rotateServers) {
        actions.push("rotate")
        currentBuild.description += "rotated servers: ${serversToRotate}"
        stage("Rotate Servers") {
            node {
                unstash 'src'
                wrapStep({
                    sh "bin/rotate-servers.sh ${serversToRotate}"
                })
            }
        }
    }
}

try {
    sendHipchatNotification("Build Started")
    runStages(mainBuild)
    currentBuild.result = currentBuild.result ?: "SUCCESS"
} catch (err) {
    if (currentBuild.result != 'UNSTABLE') {
        currentBuild.result = 'FAILURE'
        throw err
    }
} finally {
    stage("Notify") {
        currentBuild.displayName += actions.join(' ')
        message =  "Build Finished. Actions attempted: ${actions.join(' ')}"
        sendHipchatNotification(message)
    }
}
