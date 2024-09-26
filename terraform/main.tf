terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.63.0"
    }
  }

  backend "s3" {
    bucket         = "medusa-terraform-state-bucket-new-unique"  # Replace with your unique bucket name
    key            = "terraform/state"  # Path within the bucket to store the state file
    region         = "ap-south-1"  # AWS region for the S3 bucket
    dynamodb_table = "new-terraform-lock-table"  # Replace with your DynamoDB table name for state locking
    encrypt        = true
  }
}

resource "aws_service_discovery_private_dns_namespace" "medusa_namespace" {
  name        = "medusa.local" 
  vpc         = aws_vpc.main.id  
}

resource "aws_service_discovery_service" "medusa_service" {
  name                 = "medusa-postgres-service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.medusa_namespace.id

    dns_records {
      type = "A" # or "SRV" depending on your needs
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "medusa_postgres" {
  family                   = "medusa_postgres"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.role_for_the_ecs_tasks.arn
  task_role_arn            = aws_iam_role.role_for_the_ecs_tasks.arn
  
  container_definitions = jsonencode([{
    name      = "medusa_postgres"
    image     = "postgres:13"
    essential = true
    portMappings = [{
      containerPort = 5432
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "POSTGRES_USER"
        value = "medusa"
      },
      {
        name  = "POSTGRES_PASSWORD"
        value = "medusa_password"
      },
      {
        name  = "POSTGRES_DB"
        value = "medusa_db"
      }
    ]
  }])
}

# ECS Service for Medusa Postgres
resource "aws_ecs_service" "postgres_service" {
  name                   = "medusa-postgres-service"
  cluster                = aws_ecs_cluster.cluster_to_deploy_the_containers.id
  task_definition        = aws_ecs_task_definition.medusa_postgres.arn
  desired_count          = 1
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = [aws_subnet.subnet_id.id]
    security_groups  = [aws_security_group.sg_id.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.medusa_service.arn
  }
}

# ECS Task Definition for Medusa Backend
resource "aws_ecs_task_definition" "medusa_backend_server" {
  family                   = "medusa_backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.role_for_the_ecs_tasks.arn
  task_role_arn            = aws_iam_role.role_for_the_ecs_tasks.arn
  
  container_definitions = jsonencode([{
    name      = "medusa_backend"
    image     = "440744245577.dkr.ecr.ap-south-1.amazonaws.com/medusa-ecr:${var.image_tag}"  # Updated image reference
    essential = true
    portMappings = [{
      containerPort = 9000
    }]
    environment = [
      {
        name  = "POSTGRES_USER"
        value = "medusa"
      },
      {
        name  = "POSTGRES_PASSWORD"
        value = "medusa_password"
      },
      {
        name  = "POSTGRES_DB"
        value = "medusa_db"
      },
      {
        name  = "DATABASE_URL"
        value = "postgres://medusa:medusa_password@medusa-postgres-service.medusa.local:5432/medusa_db"
      }
    ]
  }])
}

# ECS Service for Medusa Backend
resource "aws_ecs_service" "pearlthoughts_medusa" {
  name                   = "pearlthoughts_medusa-service"
  cluster                = aws_ecs_cluster.cluster_to_deploy_the_containers.id
  task_definition        = aws_ecs_task_definition.medusa_backend_server.arn
  enable_execute_command = true
  desired_count          = 1
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  } 

  network_configuration {
    subnets          = [aws_subnet.subnet_id.id]
    security_groups  = [aws_security_group.sg_id.id]
    assign_public_ip = true
  }
}

# S3 Bucket for Terraform State Management
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "medusa-terraform-state-bucket-new-unique"  # Make sure this bucket name is unique
  acl    = "private"
  region = "ap-south-1"
}

# DynamoDB Table for Terraform State Locking
resource "aws_dynamodb_table" "terraform_lock_table" {
  name           = "new-terraform-lock-table"  # Name of the DynamoDB table for state locking
  billing_mode   = "PAY_PER_REQUEST"
  attribute {
    name = "LockID"
    type = "S"
  }
  hash_key = "LockID"
}

