variable "namespace" {
  description = "Kubernetes namespace for Medicine Stock API"
  type        = string
  default     = "medicine-stock"
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "log_level" {
  description = "Application log level (DEBUG, INFO, WARNING, ERROR)"
  type        = string
  default     = "INFO"
}

variable "docker_username" {
  description = "Docker registry username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "docker_password" {
  description = "Docker registry password"
  type        = string
  sensitive   = true
  default     = ""
}