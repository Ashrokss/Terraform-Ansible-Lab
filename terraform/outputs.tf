# ============================================================================
# Terraform Outputs
# ============================================================================
# Displays key information after terraform apply completes.
# ============================================================================

# ---------- Control VM ----------

output "control_vm_public_ip" {
  description = "Public IP of the Ansible Control VM"
  value       = azurerm_public_ip.control_vm_pip.ip_address
}

output "control_vm_ssh_command" {
  description = "SSH command to connect to the Ansible Control VM"
  value       = "ssh -i ssh_keys/id_rsa ${var.admin_username}@${azurerm_public_ip.control_vm_pip.ip_address}"
}

# ---------- Application VMs ----------


output "app_vm_private_ips" {
  description = "Private IPs of the Application VMs"
  value = {
    for i, nic in azurerm_network_interface.app_vm_nic :
    "app-vm-${i + 1}" => nic.private_ip_address
  }
}



# ---------- SSH Private Key ----------

output "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  value       = local_file.ssh_private_key.filename
}

# ---------- Ansible Inventory Helper ----------

output "ansible_inventory_content" {
  description = "Content for the Ansible inventory file (copy to control VM)"
  value = <<-EOT
[app_servers]
%{for i, nic in azurerm_network_interface.app_vm_nic~}
app-vm-${i + 1} ansible_host=${nic.private_ip_address}
%{endfor~}

[app_servers:vars]
ansible_user=${var.admin_username}
ansible_ssh_private_key_file=/home/${var.admin_username}/.ssh/id_rsa
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT
}
