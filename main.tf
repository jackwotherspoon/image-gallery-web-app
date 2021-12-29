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
