# Define the project_id variable
variable "project_id" {
  description = "The GCP project ID"
  type = string
  default = "new-vote-be"
}

variable "region" {
  description = "The GCP region"
  type = string
  default = "europe-west1"
}

variable "zone_l" {
  description = "The zone letter for deployment"
  type = string
  default = "b"
}

variable "request_collection_id" {
  description = "The Firestore collection ID for requests"
  type        = string
  default     = "requests"
}

variable "request_ttl_field_id" {
  description = "The field ID in Firestore for TTL"
  type        = string
  default     = "created_at"
}

variable "request_ttl" {
  description = "TTL duration in seconds"
  type        = string
  default     = "86400s"  // 24 hours
}

variable "instance_idle" {
  description = "The maximum idle duration in seconds"
  type        = string
  default     = "1800"  // 30 minutes
}

variable "instance_start_duration" {
  description = "Instance startup duration in milli-seconds"
  type        = string
  default     = "60000"  // 1 minutes
}

# Local Computed Variables
locals {
  zone = "${var.region}-${var.zone_l}"
}

resource "null_resource" "zip_function" {
  provisioner "local-exec" {
    command = "sh ./zip_fonction.sh"
  }

    depends_on = [
    null_resource.zip_function
  ]
}


provider "google" {
  project = var.project_id
  region  = var.region
  zone    = local.zone
}
# Create subnets for VPC Access connector if needed
resource "google_compute_subnetwork" "subnet" {
  name        = "serverless-subnet"
  ip_cidr_range = "10.8.0.0/28"
  region      = var.region
  network     = "default"
}

# Create the Serverless VPC Access connector
resource "google_vpc_access_connector" "vpc_connector" {
  name               = "serverless-vpc-connector"
  region             = var.region
  subnet {
    name = google_compute_subnetwork.subnet.name
  }
}

resource "google_project_service" "cloudfunctions" {
  service = "cloudfunctions.googleapis.com"
}

resource "google_project_service" "firestore" {
  service = "firestore.googleapis.com"
}

resource "google_project_service" "cloudscheduler" {
  service = "cloudscheduler.googleapis.com"
}

# Reserve a static external IP address
resource "google_compute_address" "static_ip" {
  name = "hello-world-static-ip"
}

resource "google_compute_instance" "app_instance" {
  name         = "hello-world-instance"
  machine_type = "f1-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    echo "Hello, World!" > /var/www/html/index.html
    systemctl start apache2
    systemctl enable apache2
  EOF

  tags = ["http-server"]
}

resource "google_compute_firewall" "default" {
  name    = "default-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Output the static IP address
output "static_ip_address" {
  value = google_compute_address.static_ip.address
  description = "The static IP address reserved for the instance."
}

output "firewall_source_ranges" {
  description = "The source ranges allowed by the firewall rule"
  value       =  [google_compute_subnetwork.subnet.ip_cidr_range]
}

# Google Cloud Function to check instance activity and stop if idle
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-function-bucket"
  location = "EU"
}

resource "google_storage_bucket_object" "proxy_zip" {
  name   = "proxy_v4.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "functions/proxy.zip"
}

resource "google_cloudfunctions_function" "proxy" {
  name                  = "http-function"
  description           = "A function that logs timestamp and proxies requests"
  runtime               = "nodejs16"
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.proxy_zip.name
  trigger_http          = true
  entry_point           = "handler"
  vpc_connector         = google_vpc_access_connector.vpc_connector.id

  environment_variables = {
    PROJECT_ID = var.project_id
    TARGET_URL = google_compute_address.static_ip.address,
    COLLECTION_ID = var.request_collection_id,
    ZONE          = local.zone,
    INSTANCE_NAME = google_compute_instance.app_instance.name,
    INSTANCE_START_DURATION = var.instance_start_duration
  }
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.proxy.project
  region         = google_cloudfunctions_function.proxy.region
  cloud_function = google_cloudfunctions_function.proxy.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_project_iam_member" "proxy_function_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_cloudfunctions_function.proxy.service_account_email}"
}



output "proxy_url" {
  description = "The URL of the deployed Cloud Function"
  value       = google_cloudfunctions_function.proxy.https_trigger_url
}

# Shutdown function

resource "google_storage_bucket_object" "shutdown_zip" {
  name   = "shutdown_function.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "functions/shutdown.zip"
}

resource "google_cloudfunctions_function" "shutdown" {
  name                  = "shutdownFunction"
  description           = "Shuts down a GCE instance if no requests in last 2 minutes"
  runtime               = "nodejs16"
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.shutdown_zip.name
  trigger_http          = true
  entry_point           = "checkAndShutdown"

  environment_variables = {
    PROJECT_ID    = var.project_id,
    ZONE          = local.zone,
    INSTANCE_NAME = google_compute_instance.app_instance.name,
    INSTANCE_MAX_IDLE_DURATION = var.instance_idle
    COLLECTION_ID = var.request_collection_id,
  }
}

resource "google_cloud_scheduler_job" "shutdown_scheduler" {
  name             = "shutdown-scheduler"
  description      = "Schedules the shutdown function"
  schedule         = "*/15 * * * *" // Run every 15 minutes
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.shutdown.https_trigger_url
    oidc_token {
      service_account_email = google_service_account.shutdown_scheduler_service_account.email
    }
  }

}

resource "google_service_account" "shutdown_scheduler_service_account" {
  account_id   = "shutdown-scheduler-sa"
  display_name = "Scheduler Service Account"
}

resource "google_project_iam_member" "shutdown_scheduler_service_account_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.shutdown_scheduler_service_account.email}"
}

resource "google_project_iam_member" "shutdown_function_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_cloudfunctions_function.shutdown.service_account_email}"
}



## clean

resource "google_storage_bucket_object" "clean_up_zip" {
  name   = "clean_up.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "functions/clean_up.zip"
}

resource "google_cloudfunctions_function" "clean_up_function" {
  name                  = "cleanUpFunction"
  description           = "Cleans up old request logs, keeping only the latest one"
  runtime               = "nodejs16"
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.clean_up_zip.name
  trigger_http          = true
  entry_point           = "cleanUpRequests"

  environment_variables = {
    PROJECT_ID = var.project_id,
    COLLECTION_ID = var.request_collection_id
  }
}

resource "google_cloud_scheduler_job" "cleanup_scheduler" {
  name             = "cleanup-scheduler"
  description      = "Schedules the cleanup function"
  schedule         = "0 0 */3 * *" // Run every 3 days
  time_zone        = "Etc/UTC"
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.clean_up_function.https_trigger_url
    oidc_token {
      service_account_email = google_service_account.cleanup_scheduler_service_account.email
    }
  }

  depends_on = [google_cloudfunctions_function_iam_member.invoker]
}


resource "google_service_account" "cleanup_scheduler_service_account" {
  account_id   = "cleanup-scheduler-sa"
  display_name = "Cleanup Scheduler Service Account"
}

resource "google_project_iam_member" "scheduler_service_account_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.cleanup_scheduler_service_account.email}"
}