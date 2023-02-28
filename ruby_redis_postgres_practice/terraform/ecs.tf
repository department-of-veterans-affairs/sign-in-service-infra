locals {
  service_name = var.service_name
  ecs_containers_vars = {
    cloudwatch_log_group    = aws_cloudwatch_log_group.service.id
    cloudwatch_log_region   = data.aws_region.current.name
    database_url_secret_arn = aws_ssm_parameter.database_url.arn
    redis_url_secret_arn    = aws_ssm_parameter.redis_url.arn
    service_name            = local.service_name
  }
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "ecs-docker-service"
  retention_in_days = 14
}

data "aws_ecs_task_definition" "service" {
  task_definition = aws_ecs_task_definition.service.family
}

resource "aws_ecs_cluster" "service" {
  name = local.service_name
}

resource "aws_ecs_service" "service" {
  name = local.service_name

  cluster                            = aws_ecs_cluster.service.id
  deployment_minimum_healthy_percent = "50"
  desired_count                      = 2
  iam_role                           = aws_iam_role.service_ecs_service_role.arn
  task_definition = "${aws_ecs_task_definition.service.family}:${max(
    aws_ecs_task_definition.service.revision,
    data.aws_ecs_task_definition.service.revision,
  )}"

  load_balancer {
    target_group_arn = aws_lb_target_group.service_ecs.arn
    container_name   = "app"
    container_port   = 3000
  }

  ordered_placement_strategy {
    field = "instanceId"
    type  = "spread"
  }
}

resource "aws_ecs_task_definition" "service" {
  family = local.service_name

  container_definitions    = templatefile("files/container_definitions.json", local.ecs_containers_vars)
  cpu                      = "1024"
  execution_role_arn       = aws_iam_role.service_execution_role.arn
  memory                   = "256"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.service_task_role.arn
}

resource "aws_iam_role" "service_task_role" {
  name        = "${local.service_name}-task"
  description = "Allow ${local.service_name} task to use AWS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "service_execution_role" {
  name        = "${local.service_name}-task-execution-role"
  description = "Allow ${local.service_name} task to use ECS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${local.service_name}-task-execution-role"
  }
}

resource "aws_iam_policy" "service_secrets" {
  name        = "${local.service_name}-secrets"
  description = "Allow access to get secrets from Secrets Manager and Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "secretsmanager:ListSecrets"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
        ]
        Effect = "Allow"
        Resource = [
          aws_ssm_parameter.database_url.arn,
          aws_ssm_parameter.redis_url.arn,
          data.aws_kms_alias.aws_ssm.target_key_arn,
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service_task_execution_role_secrets" {
  role       = aws_iam_role.service_execution_role.name
  policy_arn = aws_iam_policy.service_secrets.arn
}

resource "aws_iam_role_policy_attachment" "service_task_execution_role_amazon" {
  role       = aws_iam_role.service_execution_role.name
  policy_arn = "arn:aws-us-gov:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "service_ecs_service_role" {
  name        = "${local.service_name}-ecs-service-role"
  description = "Allow ${local.service_name} service to use AWS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service_ecs_service_role_amazon" {
  role       = aws_iam_role.service_ecs_service_role.name
  policy_arn = "arn:aws-us-gov:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}
