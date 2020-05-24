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
resource "google_storage_bucket_iam_binding" "storage_admin_eu" {
  bucket = "eu.artifacts.${var.project}.appspot.com"
  role = "roles/storage.admin"
  members = [
    join(":", ["serviceAccount", google_service_account.circleci_builder.email])
  ]
}