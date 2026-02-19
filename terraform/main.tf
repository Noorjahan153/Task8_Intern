provider "aws" { region = var.region }

# --- NETWORK ---
data "aws_availability_zones" "azs" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
}

resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.main.id }

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.igw.id }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- SECURITY GROUPS ---
resource "aws_security_group" "ecs" {
  name   = "strapi-ecs-sg"
  vpc_id = aws_vpc.main.id
  ingress { from_port=1337, to_port=1337, protocol="tcp", cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0, to_port=0, protocol="-1", cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "rds" {
  name   = "strapi-rds-sg"
  vpc_id = aws_vpc.main.id
  ingress { from_port=5432, to_port=5432, protocol="tcp", security_groups=[aws_security_group.ecs.id] }
}

# --- RDS ---
resource "aws_db_subnet_group" "main" {
  name       = "strapi-db-subnet"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "postgres" {
  identifier        = "strapi-db"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  username          = "strapi"
  password          = var.db_password
  db_name           = "strapi"
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

# --- ECR ---
resource "aws_ecr_repository" "strapi" {
  name                 = "strapi-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# --- ECS ---
resource "aws_ecs_cluster" "main" { name = "strapi-cluster" }

resource "aws_iam_role" "execution" {
  name = "strapi-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = "sts:AssumeRole"
      Effect   = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "strapi" {
  name              = "/ecs/strapi"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "strapi" {
  family                   = "strapi-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name  = "strapi"
    image = "${aws_ecr_repository.strapi.repository_url}:latest"
    essential = true
    portMappings = [{ containerPort=1337, protocol="tcp" }]
    environment = [
      { name="NODE_ENV", value="production" },
      { name="DATABASE_CLIENT", value="postgres" },
      { name="DATABASE_HOST", value=aws_db_instance.postgres.address },
      { name="DATABASE_PORT", value="5432" },
      { name="DATABASE_NAME", value="strapi" },
      { name="DATABASE_USERNAME", value="strapi" },
      { name="DATABASE_PASSWORD", value=var.db_password },
      { name="APP_KEYS", value=var.app_keys },
      { name="API_TOKEN_SALT", value=var.api_token_salt },
      { name="ADMIN_JWT_SECRET", value=var.admin_jwt_secret },
      { name="TRANSFER_TOKEN_SALT", value=var.transfer_token_salt },
      { name="JWT_SECRET", value=var.jwt_secret }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group" = aws_cloudwatch_log_group.strapi.name
        "awslogs-region" = var.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# --- ALB + ECS Service ---
resource "aws_lb" "alb" {
  name               = "strapi-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "tg" {
  name        = "strapi-tg"
  port        = 1337
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action { type="forward", target_group_arn=aws_lb_target_group.tg.arn }
}

resource "aws_ecs_service" "strapi" {
  name            = "strapi-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.strapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "strapi"
    container_port   = 1337
  }

  depends_on = [aws_lb_listener.http]
}

