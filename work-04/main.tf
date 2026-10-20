# ---------- сеть ----------
resource "yandex_vpc_network" "net" {
  name = "shrainer-06-tf-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "shrainer-06-tf-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.16.1.0/24"]
}

# ---------- образ ----------
data "yandex_compute_image" "base" {
  family = "ubuntu-2204-lts"
}

# ---------- машина ----------
resource "yandex_compute_instance" "app" {
  name                      = "shrainer-06-tf-app"
  hostname                  = "shrainer-06-tf-app"
  zone                      = "ru-central1-d"
  platform_id               = "standard-v3"
  allow_stopping_for_update = true

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 4
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.base.id
      size     = 25
      type     = "network-hdd"
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.extra.id
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.tpl.yaml", {
      ssh_key = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
    })
  }

  labels = {
    env   = "dev"
    owner = "shrainer-06"
  }
}

# ---------- дополнительный диск ----------
resource "yandex_compute_disk" "extra" {
  name = "shrainer-06-tf-extra"
  type = "network-hdd"
  zone = "ru-central1-d"
  size = 15
}

# ---------- вывод ----------
output "app_ip" {
  description = "публичный адрес машины"
  value       = yandex_compute_instance.app.network_interface.0.nat_ip_address
}
