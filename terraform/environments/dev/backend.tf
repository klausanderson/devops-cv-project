terraform {
  required_version = ">= 1.7.0"

  # This bucket must already exist - created once by `bootstrap/` (see its
  # main.tf comment). The bucket name here must match tf_state_bucket_name
  # over there.
  backend "gcs" {
    bucket = "klaus-devops-journey-tfstate"
    prefix = "clusters/dev"
  }
}
