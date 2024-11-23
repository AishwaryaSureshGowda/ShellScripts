#!/bin/bash

set -e

# Global settings
releaseJsonFile='repo.json'
region='us-east-1'
jiraProjectKey='INFRA'
jiraUsername='aishwarya@scrut.io'
jiraBaseUrl='https://gomigo.atlassian.net' # Add your Jira base URL here

# Check if repo.json file exists and display its contents
if [[ -f "$releaseJsonFile" ]]; then
    echo "repo.json file exists."
    cat "$releaseJsonFile"
else
    echo "repo.json file does not exist. Exiting."
    exit 1
fi

SnykTest() {
    echo '>>> Initiating the branch for Snyk tests'

    # Extract the list of repositories from the JSON file
    repoList=$(jq -c '.config[]' "$releaseJsonFile")

    # Loop through each repository configuration
    for item in ${repoList}; do
        repo=$(echo "$item" | jq -r '.repo')

        echo -e "\n>>> -------------------------------------------------------------------------------------------------\n"
        git clone "$repo"
        repoName=$(basename "$repo" .git)
        (
            cd "$repoName" || exit

            # Extract REPOSITORY_URI from buildspec.yml
            if [[ -f "buildspec.yml" ]]; then
                REPOSITORY_URI=$(grep -oP '(?<=REPOSITORY_URI=)[^ ]+' buildspec.yml)
            else
                echo "buildspec.yml file does not exist in the cloned repository. Exiting."
                exit 1
            fi

            # Install Snyk CLI and snyk-to-html if not already installed
            npm install -g snyk snyk-to-html
            snyk auth "$SNYK_TOKEN"  # Authenticate with Snyk using the provided token

            # Function to create Jira ticket
            create_jira_ticket() {
            local reportType=$1
            local reportFile=$2
            local jiraSummary="SNYT-TEST | $repoName | $reportType"
            local jiraDescription="Snyk report for $repoName. See details at: s3://scrut-snyk-notification-dev/$reportFile"

            curl -D- -u "$jiraUsername:$jiraApiToken" \
                -X POST \
                --data '{
                    "fields": {
                        "project": {
                            "key": "'"$jiraProjectKey"'"
                        },
                        "summary": "'"$jiraSummary"'",
                        "description": "'"$jiraDescription"'",
                        "issuetype": {
                            "name": "Bug"
                        },
                        "labels": ["snyk","devops","security"],
                        "customfield_10072": [{"value": "development"}]
                    }
                }' \
                -H "Content-Type: application/json" \
                "$jiraBaseUrl/rest/api/2/issue/"
                                  }


            # For Node.js Project
            if [[ -f "package.json" ]]; then
                # Snyk code test
                echo ">>> Running Snyk code test for Node.js..."
                npm install --force

                #snyk monitor
                snyk monitor
                
                snyk code test --json-file-output=results-code.json || true 
                # Check if results-code.json exists, create if not
                if [ ! -f results-code.json ]; then
                echo '{}' > results-code.json
                fi

                if [[ -f "results-code.json" ]]; then
                    snyk-to-html -i results-code.json -o results-code.html
                    aws s3 cp results-code.html "s3://scrut-snyk-notification-dev/snyk-code-test/results-code-$repoName.html"
                    create_jira_ticket "Snyk code test" "snyk-code-test/results-code-$repoName.html"
                else
                    echo "No issues found in Node.js code test, skipping HTML conversion and upload."
                fi

                # Snyk test
                echo ">>> Running Snyk test for Node.js..."
                npm install --force
                snyk test --json-file-output=results-test.json || true


                # Check if results-test.json exists, create if not
                if [ ! -f results-test.json ]; then
                echo '{}' > results-test.json
                fi

                if [[ -f "results-test.json" ]]; then
                    snyk-to-html -i results-test.json -o results-test.html
                    aws s3 cp results-test.html "s3://scrut-snyk-notification-dev/snyk-test/results-test-$repoName.html"
                    create_jira_ticket "Snyk test" "snyk-test/results-test-$repoName.html"
                else
                    echo "No issues found in Node.js test, skipping HTML conversion and upload."
                fi

                # Snyk container test
                echo ">>> Running Snyk container test for Node.js..."
                aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$REPOSITORY_URI"
                snyk container test "$REPOSITORY_URI:latest" --json-file-output=results-container.json || true

                # Check if results-container.json exists, create if not
                if [ ! -f results-container.json ]; then
                echo '{}' > results-container.json
                fi

                if [[ -f "results-container.json" ]]; then
                    snyk-to-html -i results-container.json -o results-container.html
                    aws s3 cp results-container.html "s3://scrut-snyk-notification-dev/snyk-container-test/results-container-$repoName.html"
                    create_jira_ticket "Snyk container test" "snyk-container-test/results-container-$repoName.html"
                else
                    echo "No issues found in Node.js container test, skipping HTML conversion and upload."
                fi
            fi

            # For Python project
            if [[ -f "requirements.txt" ]]; then
                echo ">>> Running Snyk test for Python..."
                pip install -r requirements.txt  # Ensure dependencies are installed

                # Snyk test for Python
                snyk test --file=requirements.txt --json-file-output=results-pytest.json || true

                # Check if results-pytest.json exists, create if not
                if [ ! -f results-pytest.json ]; then
                echo '{}' > results-pytest.json
                fi

                if [[ -f "results-pytest.json" ]]; then
                    snyk-to-html -i results-pytest.json -o results-pytest.html
                    aws s3 cp results-pytest.html "s3://scrut-snyk-notification-dev/snyk-pytest/results-pytest-$repoName.html"
                    create_jira_ticket "Snyk test for Python" "snyk-pytest/results-pytest-$repoName.html"
                else
                    echo "No issues found in Python test, skipping HTML conversion and upload."
                fi

                # Snyk code test for Python
                echo ">>> Running Snyk code test for Python..."
                snyk code test --file=requirements.txt --json-file-output=results-pycodetest.json || true

                # Check if results-pycodetest.json exists, create if not
                if [ ! -f results-pycodetest.json]; then
                echo '{}' > results-pycodetest.json
                fi

                if [[ -f "results-pycodetest.json" ]]; then
                    snyk-to-html -i results-pycodetest.json -o results-pycodetest.html
                    aws s3 cp results-pycodetest.html "s3://scrut-snyk-notification-dev/snyk-pytest/results-pycodetest-$repoName.html"
                    create_jira_ticket "Snyk code test for Python" "snyk-pytest/results-pycodetest-$repoName.html"
                else
                    echo "No issues found in Python code test, skipping HTML conversion and upload."
                fi

                # Snyk container test for Python
                echo ">>> Running Snyk container test for Python..."
                aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$REPOSITORY_URI"
                snyk container test "$REPOSITORY_URI:latest" --file=requirements.txt --json-file-output=results-pycontainertest.json || true

                # Check if results-pycontainertest.json exists, create if not
                if [ ! -f results-pycontainertest.json ]; then
                echo '{}' > results-pycontainertest.json
                fi

                if [[ -f "results-pycontainertest.json" ]]; then
                    snyk-to-html -i results-pycontainertest.json -o results-pycontainertest.html
                    aws s3 cp results-pycontainertest.html "s3://scrut-snyk-notification-dev/snyk-pytest/results-pycontainertest-$repoName.html"
                    create_jira_ticket "Snyk container test for Python" "snyk-pytest/results-pycontainertest-$repoName.html"
                else
                    echo "No issues found in Python container test, skipping HTML conversion and upload."
                fi
            fi
        )

        rm -rf "$repoName"
        echo ">>> Done with $repoName!"
    done
}

# Call the function at the end to execute it when the script runs
SnykTest
