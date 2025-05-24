output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.prefect_cluster.arn
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "ecs_service_name" {
  description = "Name of the ECS service running the Prefect worker"
  value       = aws_ecs_service.prefect_worker_service.name
}
