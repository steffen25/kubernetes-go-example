provider "kubernetes" {
  load_config_file = true
  host = var.cluster_endpoint

  client_certificate     = var.client_certificate
  client_key             = var.client_key
  cluster_ca_certificate = var.cluster_ca_certificate
}