variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-south-1"
}

variable "ecs_desired_count" {
  description = "Number of running Strapi tasks"
  type        = number
  default     = 1
}

variable "strapi_port" {
  description = "Port for Strapi"
  type        = number
  default     = 1337
}
