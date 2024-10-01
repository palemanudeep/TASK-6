resource "aws_iam_role" "role_for_the_ecs_tasks" {
  name = "role_for_the_ecs_tasks_new_service"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "ecs_task_execution_policy_new_service"
  description = "Policy for ECS task execution to access ECR and CloudWatch Logs"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_exec_policy" {
  name        = "ecs_exec_policy_new_service"
  description = "Policy for ECS Exec to enable exec into containers"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
  role       = aws_iam_role.role_for_the_ecs_tasks.name
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
  role       = aws_iam_role.role_for_the_ecs_tasks.name
}
