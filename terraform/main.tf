provider "aws" {
  region = var.aws_region
}

# ----------------------------
# VPC & Subnets
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "strapi-vpc" }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "strapi-public-${count.index+1}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "strapi-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ----------------------------
# Security Group
# ----------------------------
resource "aws_security_group" "ecs" {
  name_prefix = "strapi-ecs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = var.strapi_port
    to_port     = var.strapi_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "strapi-ecs-sg" }
}

# ----------------------------
# CloudWatch Log Group
# ----------------------------
resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/strapi"
  retention_in_days = 7
}

# ----------------------------
# ECS Cluster
# ----------------------------
resource "aws_ecs_cluster" "strapi" {
  name = "strapi-cluster"
}

# ----------------------------
# IAM Role for ECS Task
# ----------------------------
resource "aws_iam_role" "execution" {
  name = "strapi-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ----------------------------
# ECR Repository
# ----------------------------
resource "aws_ecr_repository" "strapi" {
  name                 = "strapi"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ----------------------------
# ECS Task Definition
# ----------------------------
resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name  = "strapi"
    image = "${aws_ecr_repository.strapi.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort = var.strapi_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.strapi.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ----------------------------
# ECS Service
# ----------------------------
resource "aws_ecs_service" "strapi" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.strapi.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy_attachment.execution]
}
