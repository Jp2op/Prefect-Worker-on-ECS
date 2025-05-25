provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "prefect-ecs"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    Name = "prefect-ecs"
  }
}

# Custom ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "prefect-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = module.vpc.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow ingress from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = {
    Name = "prefect-ecs-sg"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "prefect_cluster" {
  name = "prefect-cluster"

  service_connect_defaults {
    namespace = aws_service_discovery_private_dns_namespace.prefect_dns.arn
  }

  tags = {
    Name = "prefect-ecs"
  }
}

# Service Discovery (Cloud Map)
resource "aws_service_discovery_private_dns_namespace" "prefect_dns" {
  name        = "default.prefect.local"
  vpc         = module.vpc.vpc_id
  description = "Private DNS for Prefect ECS"
}

# IAM Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "prefect-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "secrets_manager_access" {
  name = "PrefectSecretsPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = [aws_secretsmanager_secret.prefect_api_key.arn] # Best practice: Scope to the specific secret
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/prefect-worker"
  retention_in_days = 7
}

# ECS Task Definition with CloudWatch Logs
resource "aws_ecs_task_definition" "prefect_worker" {
  family                   = "prefect-worker-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512" # Consider increasing to 512 or 1024 for testing
  memory                   = "1024" # Consider increasing to 1024 or 2048 for testing

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "prefect-worker",
      image     = "prefecthq/prefect:2-latest",
      essential = true,
      command   = ["prefect", "worker", "start", "--pool", var.work_pool_name],
      # TEMPORARY: Override command to print environment variables and then sleep
      # command = ["sh", "-c", "env && echo '--- SECRET VALUE CHECK ---' && echo $PREFECT_API_KEY && sleep 300"],
      secrets = [
        {
          name      = "PREFECT_API_KEY",
          valueFrom = aws_secretsmanager_secret.prefect_api_key.arn
        }
      ],
      environment = [
        {
          name  = "PREFECT_API_URL",
          value = "https://api.prefect.cloud/api/accounts/${var.prefect_account_id}/workspaces/${var.prefect_workspace_id}"
        },
        {
          name  = "PREFECT_WORK_POOL_NAME",
          value = var.work_pool_name
        },
        {
          name  = "PREFECT_ACCOUNT_ID",
          value = var.prefect_account_id
        },
        {
          name  = "PREFECT_WORKSPACE_ID",
          value = var.prefect_workspace_id
        },
        # Add Prefect debug logging
        {
          name  = "PREFECT_LOGGING_LEVEL",
          value = "DEBUG" # This give more verbose output from Prefect
        },
        {
          name  = "PREFECT_AGENT_QUERY_INTERVAL", # Example of another Prefect var
          value = "10"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "prefect_worker_service" {
  name            = "dev-worker"
  cluster         = aws_ecs_cluster.prefect_cluster.id
  task_definition = aws_ecs_task_definition.prefect_worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_policy,
    aws_cloudwatch_log_group.ecs_logs
  ]
}