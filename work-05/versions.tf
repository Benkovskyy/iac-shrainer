terraform {
  required_version = ">= 1.8"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.220.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = pathexpand("~/.yc-keys/shrainer-06-key.json")

  cloud_id  = "b1g7o5pstrdmckrm54am"
  folder_id = "b1gig580ge9bttu4itso"
  zone      = "ru-central1-d"
}
