variable "project_id" {
  description = "The ID of the GCP project."
  type        = string
}

variable "region" {
  description = "The region where GCP resources will be created."
  type        = string
  default     = "us-central1"
}
