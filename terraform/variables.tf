variable "region" {
  default = "ap-south-1"
}

variable "db_password" { type = string, sensitive = true }
variable "app_keys" { type = string, sensitive = true }
variable "api_token_salt" { type = string, sensitive = true }
variable "admin_jwt_secret" { type = string, sensitive = true }
variable "transfer_token_salt" { type = string, sensitive = true }
variable "jwt_secret" { type = string, sensitive = true }
