provider "google" {
    credentials = file("terraform-sa-key.json")
    project     = var.gcp_project_id
    region      = "us-central1"
    zone        = "us-central1-c"
    # version     = "~> 3.38" # Commented out because it's already defined in main.tf
}

# IP address for the VM
resource "google_compute_address" "ip_address" {
    name = "storybooks-ip-${terraform.workspace}"
}

# Network
data "google_compute_network" "mynetwork" {
    name = "default"
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
    name    = "allow-http-${terraform.workspace}"
    network = data.google_compute_network.mynetwork.name

    allow {
        protocol = "tcp"
        ports    = ["80"]
    }

    source_ranges = ["0.0.0.0/0"]

    target_tags = ["allow-http-${terraform.workspace}"]
  
}

# OS Image 
data "google_compute_image" "cos_image" {
    family  = "cos-stable"
    project = "cos-cloud"
}

# Compute Instance
resource "google_compute_instance" "vm_instance" {
    name         = "${var.app_name}-vm-${terraform.workspace}"
    machine_type = var.gcp_machine_type
    zone         = "us-central1-c"

    tags = google_compute_firewall.allow_http.target_tags

    boot_disk {
        initialize_params {
            image = data.google_compute_image.cos_image.self_link
        }
    }

    network_interface {
        network = data.google_compute_network.mynetwork.name
        access_config {
            nat_ip = google_compute_address.ip_address.address
        }
    }

    service_account {
        scopes = ["storage-ro"]
    }
}