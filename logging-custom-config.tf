locals {
  has_custom_parsers       = length(var.log_config_parsers) > 0
  has_custom_filters       = length(var.log_config_filters) > 0
  enable_custom_log_config = var.log_collection.enabled && var.s3_config_bucket != null && (local.has_custom_parsers || local.has_custom_filters)

  # Combine parser filters with standalone filters
  all_filters = concat(
    # Parser filters from log_config_parsers
    [
      for parser in var.log_config_parsers : {
        name         = "parser"
        parser       = parser.name
        match        = try(parser.filter.match, null)
        key_name     = try(parser.filter.key_name, null)
        reserve_data = try(parser.filter.reserve_data, false)
        preserve_key = try(parser.filter.preserve_key, false)
        unescape_key = try(parser.filter.unescape_key, false)
      } if parser.filter != null
    ],
    # Standalone filters from log_config_filters
    var.log_config_filters
  )
  has_filters = length(local.all_filters) > 0

  # Generate YAML parser configuration
  yaml_parsers_config = local.has_custom_parsers ? yamlencode({
    parsers = [
      for parser in var.log_config_parsers : {
        for key, value in parser : key => (
          # Convert booleans to "on"/"off" strings, but only if value is not null
          key == "time_keep" || key == "skip_empty_values"
          ? (value != null ? (value ? "on" : "off") : null)
          : value
        ) if value != null && key != "filter"
      }
    ]
  }) : ""

  # Generate classic .conf parser configuration using templatefile
  conf_parsers_config = local.has_custom_parsers ? join("\n\n", [
    for parser in var.log_config_parsers : replace(
      templatefile("${path.module}/parser.conf.tftpl", { parser = parser }),
      "\n{2,}",
      "\n"
    )
  ]) : ""

  # Generate YAML filter configuration for all filters
  yaml_filters_config = local.has_filters ? yamlencode({
    pipeline = {
      filters = [
        for filter in local.all_filters : merge(
          {
            for key, value in filter : key => (
              # Convert booleans to "on"/"off" strings
              key == "reserve_data" || key == "preserve_key" || key == "unescape_key" ? (value ? "on" : "off") : value
            ) if value != null && !contains(["add_fields", "rename_fields", "remove_fields"], key)
          },
          # Modify filter properties need special handling for dynamic keys
          try(filter.add_fields, null) != null ? filter.add_fields : {},
          try(filter.rename_fields, null) != null ? { for k, v in filter.rename_fields : "rename" => "${k} ${v}" } : {},
          try(filter.remove_fields, null) != null ? { for field in filter.remove_fields : "remove" => field } : {}
        )
      ]
    }
  }) : ""

  # Generate classic .conf filter configuration for all filters using templatefile
  conf_filters_config = local.has_filters ? join("\n\n", [
    for filter in local.all_filters : replace(
      templatefile("${path.module}/filter.conf.tftpl", { filter = filter }),
      "\n{2,}",
      "\n"
    )
  ]) : ""

  # Combined configuration based on format
  parsers_config_content = var.log_config_file_format == "yaml" ? local.yaml_parsers_config : local.conf_parsers_config
  filters_config_content = var.log_config_file_format == "yaml" ? local.yaml_filters_config : local.conf_filters_config

  # File keys with module path prefix
  parsers_config_key = "${module.path.id}/parsers.${var.log_config_file_format}"
  filters_config_key = "${module.path.id}/filters.${var.log_config_file_format}"

  # S3 ARNs for init process environment variables
  parsers_config_s3_arn = local.enable_custom_log_config && local.has_custom_parsers ? "arn:aws:s3:::${var.s3_config_bucket.name}/${local.parsers_config_key}" : null
  filters_config_s3_arn = local.enable_custom_log_config && local.has_filters ? "arn:aws:s3:::${var.s3_config_bucket.name}/${local.filters_config_key}" : null

  # Environment variables for init process multi-config support
  custom_config_environment = local.enable_custom_log_config && local.has_custom_parsers ? concat(
    local.parsers_config_s3_arn != null ? [
      {
        name  = "aws_fluent_bit_init_s3_1"
        value = local.parsers_config_s3_arn
      }
    ] : [],
    local.filters_config_s3_arn != null ? [
      {
        name  = "aws_fluent_bit_init_s3_2"
        value = local.filters_config_s3_arn
      }
    ] : []
  ) : []
}

data "aws_s3_bucket" "config" {
  count = local.enable_custom_log_config ? 1 : 0

  bucket = var.s3_config_bucket.name
}

data "aws_kms_key" "config_bucket" {
  count = local.enable_custom_log_config && var.s3_config_bucket != null && try(var.s3_config_bucket.kms_key_id, null) != null ? 1 : 0

  key_id = var.s3_config_bucket != null ? var.s3_config_bucket.kms_key_id : null
}

# Upload parsers configuration to S3
resource "aws_s3_object" "parsers_config" {
  count = local.enable_custom_log_config && local.has_custom_parsers ? 1 : 0

  bucket       = data.aws_s3_bucket.config[0].id
  key          = local.parsers_config_key
  content      = local.parsers_config_content
  content_type = var.log_config_file_format == "yaml" ? "application/x-yaml" : "text/plain"
  etag         = md5(local.parsers_config_content)
}

# Upload filters configuration to S3 (only if there are filters defined)
resource "aws_s3_object" "filters_config" {
  count = local.enable_custom_log_config && local.has_filters ? 1 : 0

  bucket       = data.aws_s3_bucket.config[0].id
  key          = local.filters_config_key
  content      = local.filters_config_content
  content_type = var.log_config_file_format == "yaml" ? "application/x-yaml" : "text/plain"
  etag         = md5(local.filters_config_content)
}
