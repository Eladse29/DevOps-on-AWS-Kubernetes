def repositoryUrl = 'https://github.com/Eladse29/DevOps-on-AWS-Kubernetes.git'
def repositoryBranch = '*/task5'

pipelineJob('application-ci') {
    description('''
        CI Pipeline for the DevOps on AWS project.

        Triggered by a GitHub push.
        Performs validation, linting, tests, image build, image scan,
        immutable tagging and push to Amazon ECR.

        This job must not deploy the application.
    '''.stripIndent().trim())

    disabled(false)

    quietPeriod(0)

    logRotator {
        numToKeep(20)
        artifactNumToKeep(10)
    }

    triggers {
        githubPush()
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url(repositoryUrl)
                    }

                    branch(repositoryBranch)

                    extensions {
                        cloneOptions {
                            shallow(false)
                            noTags(false)
                            timeout(10)
                        }

                        cleanBeforeCheckout()
                    }
                }
            }

            scriptPath('Jenkinsfile-ci')
            lightweight(false)
        }
    }
}

pipelineJob('application-cd') {
    description('''
        CD Pipeline for the DevOps on AWS project.

        Receives an existing immutable image tag and image digests
        created by application-ci.

        Validates the Helm charts, deploys the same version to Kubernetes,
        waits for rollout completion and performs smoke tests.

        This job must not build Docker images.
    '''.stripIndent().trim())

    disabled(false)

    quietPeriod(0)

    logRotator {
        numToKeep(20)
        artifactNumToKeep(10)
    }

    parameters {
        stringParam(
            'IMAGE_TAG',
            '',
            'Required immutable image tag created by application-ci. The value latest is forbidden.'
        )

        stringParam(
            'CI_BUILD_NUMBER',
            '',
            'Jenkins build number of the application-ci run that created this release.'
        )

        stringParam(
            'GIT_COMMIT_SHA',
            '',
            'Git commit SHA associated with the release.'
        )

        stringParam(
            'FRONTEND_DIGEST',
            '',
            'Immutable frontend image digest produced by application-ci.'
        )

        stringParam(
            'BACKEND_DIGEST',
            '',
            'Immutable backend image digest produced by application-ci.'
        )

        stringParam(
            'WORKER_DIGEST',
            '',
            'Immutable worker image digest produced by application-ci.'
        )

        choiceParam(
            'TARGET_NAMESPACE',
            [
                'devops-app'
            ],
            'Kubernetes namespace allowed for deployment.'
        )

        stringParam(
            'RELEASE_DESCRIPTION',
            '',
            'Optional description of this deployment.'
        )
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url(repositoryUrl)
                    }

                    branch(repositoryBranch)

                    extensions {
                        cloneOptions {
                            shallow(false)
                            noTags(false)
                            timeout(10)
                        }

                        cleanBeforeCheckout()
                    }
                }
            }

            scriptPath('Jenkinsfile-cd')
            lightweight(false)
        }
    }
}
