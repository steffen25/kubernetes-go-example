# Modules
module "gke" {
    source = "./gke"
}

module "k8s" {
    source = "./k8s"

    cluster_endpoint = "${module.gke.cluster_endpoint}"

    client_certificate     = "${module.gke.client_certificate}"
    client_key             = "${module.gke.client_key}"
    cluster_ca_certificate = "${module.gke.cluster_ca_certificate}"
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master."
  sensitive   = true
  value       = module.gke.cluster_endpoint
}

output "client_certificate" {
  description = "Public certificate used by clients to authenticate to the cluster endpoint."
  value       = module.gke.client_certificate
}

output "client_key" {
  description = "Private key used by clients to authenticate to the cluster endpoint."
  sensitive   = true
  value       = module.gke.client_key
}

output "cluster_ca_certificate" {
  description = "The public certificate that is the root of trust for the cluster."
  sensitive   = true
  value       = module.gke.cluster_ca_certificate
}