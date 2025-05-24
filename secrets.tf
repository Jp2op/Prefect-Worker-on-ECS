resource "aws_secretsmanager_secret" "prefect_api_key" {
  name        = "prefect-api-key-v12"
  description = "Prefect Cloud API key for ECS worker"
}

resource "aws_secretsmanager_secret_version" "prefect_api_key_version" {
  secret_id     = aws_secretsmanager_secret.prefect_api_key.id
  # Store the key as a plain string, not JSON
  secret_string = var.prefect_api_key
}