#!/usr/bin/env bash
sudo apt-get install jq
CLUSTER='trashy-cluster'
CONTAINER_INSTANCE='fda9944f-87b4-4788-a574-9003c2471ee1'
DOCKER_IMAGE='docker-repo'
TASK='trashy-task-2'
SERVICE='trashy-service'
TAG='latest'
FAMILY='trashy-task-2'
aws configure set region $AWS_REGION
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
$(aws ecr get-login --no-include-email --region $AWS_REGION)
docker build -t app .
docker tag app $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$DOCKER_IMAGE
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$DOCKER_IMAGE

task_template='[
  {
    "name": "%s",
    "image": "%s.dkr.ecr.eu-central-1.amazonaws.com/%s:%s",
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
task_def=$(printf "$task_template" $TASK $AWS_ACCOUNT_ID $DOCKER_IMAGE $TAG)
aws ecs register-task-definition --container-definitions "$task_def" --family $FAMILY
aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition trashy-task-2

RUNNING_TASK=$(aws ecs list-tasks --cluster trashy-cluster | jq -r '.taskArns | .[0]')
aws ecs stop-task --task $RUNNING_TASK  --cluster trashy-cluster
aws ecs start-task --task-definition trashy-task-2  --cluster trashy-cluster --container-instances $CONTAINER_INSTANCE
