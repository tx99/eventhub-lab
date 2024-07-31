variable "tenant_id" {
  description = "The tenant ID of your Azure subscription"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to be created"
  type        = string
  default     = "eventhub-lab"
}

variable "location" {
  description = "The location of the resources to be created"
  type        = string
  default     = "North Europe"
}

variable "eventhub_namespace_name" {
  description = "The name of the Event Hub namespace to be created"
  type        = string
  default     = "evthubnamespace2344"
}

variable "eventhub_name" {
  description = "The name of the Event Hub to be created"
  type        = string
  default     = "myeventhub"  # Replace with your desired default name
}


variable "node_pool_name" {
  description = "The name of the node pool to be created in AKS"
  type        = string
  default     = "system"
}

variable "vm_size" {
  description = "The size of the VMs to be used in the node pool"
  type        = string
  default     = "Standard_D2_v2"
}

variable "dns_prefix" {
  description = "The DNS prefix to use for the AKS cluster"
  type        = string
  default     = "aks"
}