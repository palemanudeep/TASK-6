
variable "clustername_in_the_ecr" {
  description = "name for the cluster in the ecr"
  type        = string  
  default     = "medusa_prod_cluster"
}

variable "image_tag" {
  description = "The image tag for the Docker container"
  type        = string
}
