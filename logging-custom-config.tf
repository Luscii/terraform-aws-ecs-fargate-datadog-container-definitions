locals {
  enable_custom_log_config = var.log_collection.enabled && var.s3_config_bucket_name != null
  has_custom_parsers       = length(var.log_config_parsers) > 0

  # Generate YAML parser configuration
  yaml_parsers_config = local.has_custom_parsers ? yamlencode({
    parsers = [
      for parser in var.log_config_parsers : merge(
        {
          name   = parser.name
          format = parser.format
        },
        parser.time_key != null ? { time_key = parser.time_key } : {},
        parser.time_format != null ? { time_format = parser.time_format } : {},
        parser.time_keep != null ? { time_keep = parser.time_keep ? "on" : "off" } : {},
        parser.regex != null ? { regex = parser.regex } : {},
        parser.decode_field != null ? { decode_field = parser.decode_field } : {},
        parser.decode_field_as != null ? { decode_field_as = parser.decode_field_as } : {},
        parser.types != null ? { types = parser.types } : {},
        parser.skip_empty_values != null ? { skip_empty_values = parser.skip_empty_values ? "on" : "off" } : {}
      )
    ]
  }) : ""

  # Generate classic .conf parser configuration
  conf_parsers_config = local.has_custom_parsers ? join("\n\n", [
    for parser in var.log_config_parsers : join("\n", concat(
      ["[PARSER]"],
      ["    Name   ${parser.name}"],
      ["    Format ${parser.format}"],
      parser.time_key != null ? ["    Time_Key    ${parser.time_key}"] : [],
      parser.time_format != null ? ["    Time_Format ${parser.time_format}"] : [],
      parser.time_keep != null ? ["    Time_Keep   ${parser.time_keep ? "On" : "Off"}"] : [],
      parser.regex != null ? ["    Regex  ${parser.regex}"] : [],
      parser.decode_field != null ? ["    Decode_Field    ${parser.decode_field}"] : [],
      parser.decode_field_as != null ? ["    Decode_Field_As ${parser.decode_field_as}"] : [],
      parser.types != null ? ["    Types  ${parser.types}"] : [],
      parser.skip_empty_values != null ? ["    Skip_Empty_Values ${parser.skip_empty_values ? "On" : "Off"}"] : []
    ))
  ]) : ""

  # Generate YAML filter configuration for parsers
  yaml_filters_config = local.has_custom_parsers ? yamlencode({
    pipeline = {
      filters = [
        for parser in var.log_config_parsers : merge(
          {
            name   = "parser"
            parser = parser.name
          },
          parser.filter != null && parser.filter.match != null ? { match = parser.filter.match } : {},
          parser.filter != null && parser.filter.key_name != null ? { key_name = parser.filter.key_name } : {},
          parser.filter != null && parser.filter.reserve_data != null ? { reserve_data = parser.filter.reserve_data ? "on" : "off" } : {},
          parser.filter != null && parser.filter.preserve_key != null ? { preserve_key = parser.filter.preserve_key ? "on" : "off" } : {},
          parser.filter != null && parser.filter.unescape_key != null ? { unescape_key = parser.filter.unescape_key ? "on" : "off" } : {}
        ) if parser.filter != null
      ]
    }
  }) : ""

  # Generate classic .conf filter configuration for parsers
  conf_filters_config = local.has_custom_parsers ? join("\n\n", [
    for parser in var.log_config_parsers : join("\n", concat(
      ["[FILTER]"],
      ["    Name   parser"],
      ["    Parser ${parser.name}"],
      parser.filter != null && parser.filter.match != null ? ["    Match  ${parser.filter.match}"] : [],
      parser.filter != null && parser.filter.key_name != null ? ["    Key_Name ${parser.filter.key_name}"] : [],
      parser.filter != null && parser.filter.reserve_data != null ? ["    Reserve_Data ${parser.filter.reserve_data ? "On" : "Off"}"] : [],
      parser.filter != null && parser.filter.preserve_key != null ? ["    Preserve_Key ${parser.filter.preserve_key ? "On" : "Off"}"] : [],
      parser.filter != null && parser.filter.unescape_key != null ? ["    Unescape_Key ${parser.filter.unescape_key ? "On" : "Off"}"] : []
    )) if parser.filter != null
  ]) : ""

  # Combined configuration based on format
  parsers_config_content = var.log_config_file_format == "yaml" ? local.yaml_parsers_config : local.conf_parsers_config
  filters_config_content = var.log_config_file_format == "yaml" ? local.yaml_filters_config : local.conf_filters_config

  # File keys with module path prefix
  parsers_config_key = "${module.path.id}/parsers.${var.log_config_file_format}"
  filters_config_key = "${module.path.id}/filters.${var.log_config_file_format}"

  # S3 ARNs for init process environment variables
  parsers_config_s3_arn = local.enable_custom_log_config && local.has_custom_parsers ? "arn:aws:s3:::${var.s3_config_bucket_name}/${local.parsers_config_key}" : null
  filters_config_s3_arn = local.enable_custom_log_config && local.has_custom_parsers && anytrue([for p in var.log_config_parsers : p.filter != null]) ? "arn:aws:s3:::${var.s3_config_bucket_name}/${local.filters_config_key}" : null

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

  bucket = var.s3_config_bucket_name
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
  count = local.enable_custom_log_config && local.has_custom_parsers && anytrue([for p in var.log_config_parsers : p.filter != null]) ? 1 : 0

  bucket       = data.aws_s3_bucket.config[0].id
  key          = local.filters_config_key
  content      = local.filters_config_content
  content_type = var.log_config_file_format == "yaml" ? "application/x-yaml" : "text/plain"
  etag         = md5(local.filters_config_content)
}
