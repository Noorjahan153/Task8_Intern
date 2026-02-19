output "strapi_url" {
  description = "The public URL of Strapi"
  value       = aws_lb.alb.dns_name
}
