version: 0.2

env:
  git-credential-helper: yes
  shell: bash
  parameter-store:
    SSH_KEY: id_rsa
    SSH_PUB: id_rsa.pub
    SNYK_TOKEN: SNYK_TOKEN  # Add SNYK_TOKEN here
    jiraApiToken: jiraApiToken
    jiraBaseUrl: jiraBaseUrl
    snykOrgID: snykOrgID
    docker_pass: docker_pass
phases:
  build:
    commands:
      - pwd && ls -l
      - mkdir -p ~/.ssh
      - echo "$SSH_KEY" > ~/.ssh/id_rsa
      - echo "$SSH_PUB" > ~/.ssh/id_rsa.pub
      - ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
      - chmod 600 ~/.ssh/id_rsa
      - eval "$(ssh-agent -s)"
      - chmod +x orchestrate.sh  # Add execute permission to orchestrate.sh
      - chmod +x PublishMessageToSlack.sh  # Add execute permission to PublishMessageToSlack.sh
      - ./orchestrate.sh
