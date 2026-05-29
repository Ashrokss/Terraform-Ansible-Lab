# ============================================================================
# Variable Definitions
# ============================================================================
# All configurable parameters for the infrastructure deployment.
# Values are supplied via terraform.tfvars
# ============================================================================

# ---------- Azure Context ----------

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the existing Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

# ---------- Networking ----------

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
}

variable "subnet_name" {
  description = "Name of the Subnet"
  type        = string
}

variable "subnet_address_prefixes" {
  description = "Address prefixes for the Subnet"
  type        = list(string)
}

# ---------- Virtual Machines ----------

variable "admin_username" {
  description = "Admin username for all VMs"
  type        = string
}

variable "vm_size" {
  description = "Size of the Azure VMs"
  type        = string
}

variable "app_vm_count" {
  description = "Number of application VMs to provision"
  type        = number
}

# ---------- Tags ----------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
