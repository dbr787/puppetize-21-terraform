provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      created_by = "${var.email}"
      project_id = "${var.project_id}"
    }
  }
}
