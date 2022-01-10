# Specify the GCP Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# access data about current project
data "google_project" "project" {
}

# Create a GCS Bucket
resource "google_storage_bucket" "image_bucket" {
  name     = var.bucket_name
  location = var.region
  force_destroy = true
}

# Enables the Cloud Run API
resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
  disable_on_destroy = true
}

# Enables the Cloud Vision API
resource "google_project_service" "vision_api" {
  service = "vision.googleapis.com"
  disable_on_destroy = true
}

#Enables the Cloud Firestore API
resource "google_project_service" "firestore_api" {
  service = "firestore.googleapis.com"
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
  account_id  = "cloud-run-pub-sub-invoker"
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

# Enable Pub/Sub to create authentication tokens
resource "google_project_iam_binding" "token_binding" {
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  ]
  project = var.project_id
}

# Create a Pub/Sub Topic
resource "google_pubsub_topic" "bucket_topic" {
  name = "cloud-storage-topic"
}

# Create a Pub/Sub Subscription
resource "google_pubsub_subscription" "bucket_subscription" {
  name  = "cloud-storage-subscription"
  topic = google_pubsub_topic.bucket_topic.name
  push_config {
    push_endpoint = google_cloud_run_service.image_gallery_service.status[0].url

    oidc_token {
      service_account_email = google_service_account.run_invoker.email
    }
  }
}

# Configure Cloud Storage to publish Pub/Sub message
resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.image_bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.bucket_topic.id
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  depends_on = [google_pubsub_topic_iam_binding.binding]
}

# Enable notifications by giving the correct IAM permission to a unique service account.
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = google_pubsub_topic.bucket_topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

# Enable App Engine (required for Firestore)
resource "google_app_engine_application" "app" {
  project     = var.project_id
  location_id = "us-central"
  database_type = "CLOUD_FIRESTORE"
}

# Create Firebase Project
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}
