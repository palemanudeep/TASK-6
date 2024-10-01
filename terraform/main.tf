resource "aws_service_discovery_private_dns_namespace" "medusa_namespace" {
  name        = "medusa.local_new_service"
  vpc         = aws_vpc.main.id  
}

resource "aws_service_discovery_service" "medusa_service" {
  name                 = "medusa-postgres-service_new_service"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.medusa_namespace.id

    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "medusa_postgres" {
  family                   = "medusa_postgres_new_service"
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

resource "aws_ecs_service" "postgres_service" {
  name                   = "medusa-postgres-service_new_service"
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

resource "aws_ecs_task_definition" "medusa_backend_server" {
  family                   = "medusa_backend_new_service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.role_for_the_ecs_tasks.arn
  task_role_arn            = aws_iam_role.role_for_the_ecs_tasks.arn

  container_definitions = jsonencode([{
    name      = "medusa_backend"
    image     = "440744245577.dkr.ecr.ap-south-1.amazonaws.com/medusa-backend-prod:${var.image_tag}"
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
        value = "postgres://medusa:medusa_password@medusa-postgres-service_new_service.medusa.local_new_service:5432/medusa_db"
      }
    ]
  }])
}

resource "aws_ecs_service" "pearlthoughts_medusa" {
  name                   = "pearlthoughts_medusa-service_new_service"
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
