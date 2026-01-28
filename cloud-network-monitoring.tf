locals {
  # Cloud Network Monitoring
  # https://docs.datadoghq.com/network_monitoring/cloud_network_monitoring/setup/?tab=ecsfargate

  # Environment variables for Cloud Network Monitoring
  cmn_environment = var.enable_cloud_network_monitoring ? [
    {
      "name" : "DD_SYSTEM_PROBE_NETWORK_ENABLED",
      "value" : "true"
    },
    {
      "name" : "DD_NETWORK_CONFIG_ENABLE_EBPFLESS",
      "value" : "true"
    },
    {
      "name" : "DD_PROCESS_AGENT_ENABLED",
      "value" : "true"
    }
  ] : []

  # Linux parameters for Cloud Network Monitoring
  # Fargate only supports adding SYS_PTRACE capability
  # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_KernelCapabilities.html
  cmn_linux_param_capability_sys_ptrace = var.enable_cloud_network_monitoring
}
