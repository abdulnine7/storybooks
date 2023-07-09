#  GENERAL
variable "app_name" {
  description = "Name of the application"
  type        = string
}

# ATLAS
variable "atlas_project_id" {
  description = "Atlas Project ID"
  type        = string
}

variable "database_name" {
  description = "Database Name"
  type        = string
}

variable "mongodbatlas_public_key" {
    description = "MongoDB Atlas Public Key"
    type        = string
}

variable "mongodbatlas_private_key" {
    description = "MongoDB Atlas Private Key"
    type        = string
}

variable "atlas_user_password" {
    description = "MongoDB Atlas User Password"
    type        = string
}

# GCP
variable "gcp_machine_type" {
    description = "GCP Machine Type"
    type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

# Cloudflare
variable "cloudflare_api_token" {
    description = "Cloudflare API Token"
    type        = string
}

variable "domain_name" {
    description = "Domain Name"
    type        = string
}