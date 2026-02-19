output "ecr_url" {
  value = aws_ecr_repository.strapi.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.strapi.name
}

output "ecs_service" {
  value = aws_ecs_service.strapi.name
}

output "strapi_task_count" {
  value = aws_ecs_service.strapi.desired_count
}
