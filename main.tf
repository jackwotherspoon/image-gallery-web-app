# Specify the GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Create a GCS Bucket
resource "google_storage_bucket" "image_bucket" {
  name     = var.bucket_name
  location = var.region
}

# Enables the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
  disable_on_destroy = true
}

# Create a Cloud Run service
resource "google_cloud_run_service" "image_gallery_service" {
  name     = "image-gallery-service"
  location = "us-central1"

  template {
    spec {
      containers {
        image = var.container_image
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
  depends_on = [google_project_service.run_api]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.image_gallery_service.location
  project     = google_cloud_run_service.image_gallery_service.project
  service     = google_cloud_run_service.image_gallery_service.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

# Create Service Account to Invoke Cloud Run
resource "google_service_account" "run_invoker" {
  account_id  = "run-pub-sub-invoker"
  description = "Service account for invoking Cloud Run from Pub/Sub"
  project     = var.project_id
}

# add IAM Policy Binding to Service Account
resource "google_project_iam_binding" "invoker_binding" {
  role    = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.run_invoker.email}"
  ]
  project = var.project_id
}

# Create a Pub/Sub Topic
resource "google_pubsub_topic" "bucket_topic" {
  name = "cloud-storage-topic"
}
