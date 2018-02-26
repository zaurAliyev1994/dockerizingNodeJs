#!/usr/bin/env bash

# more bash-friendly output for jq
JQ="jq --raw-output --exit-status"

configure_aws_cli(){
	aws configure set region $AWS_REGION
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
}

deploy_cluster() {
    CLUSTER='trashy-cluster-2'
    DOCKER_IMAGE='docker-repo'
    TASK='trashy-task-2'
    SERVICE='trashy-service-2'
    TAG='latest'
    FAMILY='trashy-task-2'
    make_task_def
    register_definition
    if [[ $(aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $revision | \
                   $JQ '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service."
        return 1
    fi

    # wait for older revisions to disappear
    # not really necessary, but nice for demos
    for attempt in {1..30}; do
        if stale=$(aws ecs describe-services --cluster $CLUSTER --services $SERVICE | \
                       $JQ ".services[0].deployments | .[] | select(.taskDefinition != \"$revision\") | .taskDefinition"); then
            echo "Waiting for stale deployments:"
            echo "$stale"
            sleep 5
        else
            echo "Deployed!"
            return 0
        fi
    done
    echo "Service update took too long."
    return 1
}

make_task_def(){
  task_template='[
              {
                "name": "%s",
                "image": "%s.dkr.ecr.us-east-1.amazonaws.com/%s:%s",
                "essential": true,
                "memory": 128,
                "portMappings": [
                  {
                    "containerPort": 8080,
                    "hostPort": 80
                  }
                ]
              }
            ]'
            task_def=$(printf "$task_template" $TASK $AWS_ACCOUNT_ID $DOCKER_IMAGE $CIRCLE_SHA1)
}

push_ecr_image(){
    eval $(aws ecr get-login --no-include-email --region $AWS_REGION)
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$DOCKER_IMAGE:$CIRCLE_SHA1
}

register_definition() {

    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $FAMILY | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}
configure_aws_cli
push_ecr_image
deploy_cluster