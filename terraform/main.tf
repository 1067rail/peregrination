resource "google_service_account" "api_gateway_service_account" {
  account_id   = "api-gateway-sa"
  display_name = "API Gateway Service Account"
}

resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "my-api"
}

resource "google_api_gateway_api_config" "api_cfg" {
  provider      = google-beta
  api           = google_api_gateway_api.api.api_id
  api_config_id = "my-api-config"

  openapi_documents {
    document {
      path = "spec.yaml"
      contents = base64encode(templatefile("openapi.yaml", {
        address = {
          default = google_cloudfunctions2_function.default.service_config[0].uri
        }
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.api_gateway_service_account.id
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "api_gw" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.api_cfg.id
  gateway_id = "my-gateway"
  region     = var.region
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "/tmp/function-source.zip"
  source_dir  = "../functions"
  excludes = [
    "node_modules/**",
    "lib/**",
  ]
}

resource "google_storage_bucket" "default" {
  name                        = "${var.project_id}-gcf-source"
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "object" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.default.name
  source = data.archive_file.default.output_path
}

resource "google_cloudfunctions2_function" "default" {
  name        = "peregrination-function"
  location    = var.region
  description = "a v2 cloud function"

  build_config {
    runtime     = "nodejs22"
    entry_point = "helloHttp"
    source {
      storage_source {
        bucket = google_storage_bucket.default.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
  }
}

resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloudfunctions2_function.default.location
  service  = google_cloudfunctions2_function.default.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.api_gateway_service_account.email}"
}
