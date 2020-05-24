terraform {
  # The modules used in this guide require Terraform 0.12, additionally we depend on a bug fixed in version 0.12.7.
  required_version = ">= 0.12.7"
  backend "gcs" {
    bucket = "tf-state-go-kubernetes"
    prefix = "terraform-state"
  }
}

provider "google" {
  version = "~> 2.9.0"
  project = var.project
  region  = var.region
}

provider "google-beta" {
  version = "~> 2.9.0"
  project = var.project
  region  = var.region
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A PRIVATE CLUSTER IN GOOGLE CLOUD PLATFORM
# ---------------------------------------------------------------------------------------------------------------------

module "gke_cluster" {
  # Use a version of the gke-cluster module that supports Terraform 0.12
  source = "git::git@github.com:gruntwork-io/terraform-google-gke.git//modules/gke-cluster?ref=v0.3.8"

  name = var.cluster_name

  project  = var.project
  location = var.location
  network  = module.vpc_network.network

  # We're deploying the cluster in the 'public' subnetwork to allow outbound internet access
  # See the network access tier table for full details:
  # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
  subnetwork = module.vpc_network.public_subnetwork

  # When creating a private cluster, the 'master_ipv4_cidr_block' has to be defined and the size must be /28
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  # This setting will make the cluster private
  enable_private_nodes = "true"

  # To make testing easier, we keep the public endpoint available. In production, we highly recommend restricting access to only within the network boundary, requiring your users to use a bastion host or VPN.
  disable_public_endpoint = "false"

  # With a private cluster, it is highly recommended to restrict access to the cluster master
  # However, for testing purposes we will allow all inbound traffic.
  master_authorized_networks_config = [
    {
      cidr_blocks = [
        {
          cidr_block   = "0.0.0.0/0"
          display_name = "all-for-testing"
        },
      ]
    },
  ]

  cluster_secondary_range_name = module.vpc_network.public_subnetwork_secondary_range_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NODE POOL
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_node_pool" "node_pool" {
  provider = google-beta

  name     = "private-pool"
  project  = var.project
  location = var.location
  cluster  = module.gke_cluster.name

  initial_node_count = "1"

  autoscaling {
    min_node_count = "1"
    max_node_count = "5"
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "COS"
    machine_type = "n1-standard-1"

    labels = {
      private-pools-example = "true"
    }

    # Add a private tag to the instances. See the network access tier table for full details:
    # https://github.com/gruntwork-io/terraform-google-network/tree/master/modules/vpc-network#access-tier
    tags = [
      module.vpc_network.private,
      "private-pool-example",
    ]

    disk_size_gb = "10"
    disk_type    = "pd-standard"
    preemptible  = false

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CUSTOM SERVICE ACCOUNT TO USE WITH THE GKE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "gke_service_account" {
  source = "git::git@github.com:gruntwork-io/terraform-google-gke.git//modules/gke-service-account?ref=v0.3.8"

  name        = var.cluster_service_account_name
  project     = var.project
  description = var.cluster_service_account_description
}

# ---------------------------------------------------------------------------------------------------------------------
# ALLOW THE CUSTOM SERVICE ACCOUNT TO PULL IMAGES FROM THE GCR REPO
# ---------------------------------------------------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "member" {
  bucket = "artifacts.${var.project}.appspot.com"
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.gke_service_account.email}"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A NETWORK TO DEPLOY THE CLUSTER TO
# ---------------------------------------------------------------------------------------------------------------------

module "vpc_network" {
  source = "github.com/gruntwork-io/terraform-google-network.git//modules/vpc-network?ref=v0.2.1"

  name_prefix = "${var.cluster_name}-network-${random_string.suffix.result}"
  project     = var.project
  region      = var.region

  cidr_block           = var.vpc_cidr_block
  secondary_cidr_block = var.vpc_secondary_cidr_block
}

# Use a random suffix to prevent overlap in network names
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A GCS bucket to store various stuff including its own service account with read+write access
# ---------------------------------------------------------------------------------------------------------------------
# GCS storage bucket
resource "google_storage_bucket" "go_kubernetes_storage" {
  name          = "go-kubernetes-storage"
  location      = "europe-north1"
}

// Storage Service Account
resource "google_service_account" "storage_reader_writer" {
  account_id = "storagereadwrite"
  display_name = "Bucket reader writer"
  project = var.project
}

// Service Account Key
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.storage_reader_writer.name
}

// IAM Bindings
resource "google_storage_bucket_iam_binding" "bucket_creator" {
  bucket = google_storage_bucket.go_kubernetes_storage.name
  role = "roles/storage.objectCreator"
  members = [
    join(":", ["serviceAccount", google_service_account.storage_reader_writer.email])
  ]
}

resource "google_storage_bucket_iam_binding" "bucket_reader" {
  bucket = google_storage_bucket.go_kubernetes_storage.name
  role = "roles/storage.objectViewer"
  members = [
    join(":", ["serviceAccount", google_service_account.storage_reader_writer.email])
  ]
}

# CircleCI
resource "google_service_account" "circleci_builder" {
  account_id = "circlecibuilder"
  display_name = "CircleCI builder"
  project = var.project
}

resource "google_service_account_key" "circleci_key" {
  service_account_id = google_service_account.circleci_builder.name
}
// IAM Bindings
resource "google_storage_bucket_iam_binding" "storage_admin" {
  bucket = "artifacts.${var.project}.appspot.com"
  role = "roles/storage.admin"
  members = [
    join(":", ["serviceAccount", google_service_account.circleci_builder.email])
  ]
}