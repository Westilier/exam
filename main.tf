terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  zone = "ru-central1-a"
  service_account_key_file = "./key.json"
  folder_id = "b1gdhj8q62q1nntkdcjl"
}

resource "yandex_vpc_network" "app_network" {
  name = "app-network"
}

resource "yandex_vpc_subnet" "app_subnet" {
  name = "web-subnet-a"
  zone = "ru-central1-a"
  network_id = yandex_vpc_network.app_network.id
  v4_cidr_blocks = ["192.168.0.0/24"]
}

resource "yandex_container_registry" "app_registry" {
  name = "app-registry"
  folder_id = "b1gdhj8q62q1nntkdcjl"
}

resource "yandex_iam_service_account" "k8s_sa" {
  name = "k8s-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "k8s_roles" {
  folder_id = "b1gdhj8q62q1nntkdcjl"
  for_each = toset(["k8s.clusters.agent", "vpc.publicAdmin", "container-registry.images.puller"])
  role = each.value
  member = "serviceAccount:${yandex_iam_service_account.k8s_sa.id}"
}

resource "yandex_kubernetes_cluster" "k8s_cluster" {
  name = "k8s-cluster"
  network_id = yandex_vpc_network.app_network.id

  master {
    zonal {
      zone = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.app_subnet.id
    }
    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
}

resource "yandex_kubernetes_node_group" "k8s_nodes" {
  cluster_id = yandex_kubernetes_cluster.k8s_cluster.id
  name = "k8s-node-group"

  instance_template {
    platform_id = "standard-v3"
    network_interface {
      nat = true
      subnet_ids = [yandex_vpc_subnet.app_subnet.id]
    }
    resources {
      cores  = 2
      memory = 2
    }
    boot_disk {
      type = "network-hdd"
      size = 32
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }
}

resource "yandex_mdb_postgresql_cluster" "postgres_cluster" {
  name = "postgres-cluster"
  network_id  = yandex_vpc_network.app_network.id
  environment = "PRESTABLE"
  config {
    version = 15
    resources {
      resource_preset_id = "s3-c2-m8"
      disk_type_id = "network-hdd"
      disk_size = 10
    }
  }

  host {
    zone = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.app_subnet.id
  }
}

resource "yandex_mdb_postgresql_database" "app_db" {
  cluster_id = yandex_mdb_postgresql_cluster.postgres_cluster.id
  name = "app_db"
  owner = "db_user"
  depends_on = [yandex_mdb_postgresql_user.db_user]
}

resource "yandex_mdb_postgresql_user" "db_user" {
  cluster_id = yandex_mdb_postgresql_cluster.postgres_cluster.id
  name = "db_user"
  password = "postgres"
}