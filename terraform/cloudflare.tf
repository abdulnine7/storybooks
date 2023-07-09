provider "cloudflare" { 
    # version = "~> 2.0" # Commented out because it's already defined in main.tf
    api_token = var.cloudflare_api_token
}

# Zone
data "cloudflare_zones" "cf_zones" {
  filter {
    name = var.domain_name
  }
}

# DNS A Records
resource "cloudflare_record" "example" {
  zone_id = data.cloudflare_zones.cf_zones.zones.0.id
  name    = "storybooks${terraform.workspace == "prod" ? "" : "-${terraform.workspace}"}"
  value   = google_compute_address.ip_address.address
  type    = "A"
  proxied = true
}