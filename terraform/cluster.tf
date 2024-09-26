resource "aws_ecs_cluster" "cluster_to_deploy_the_containers" {
  name = var.clustername_in_the_ecr
}
