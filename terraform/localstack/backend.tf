terraform {
  # Use local backend for LocalStack development
  backend "local" {
    path = "terraform.tfstate"
  }
}
