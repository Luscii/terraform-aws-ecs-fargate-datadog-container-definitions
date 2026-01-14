# Custom Logging Example

This example demonstrates advanced FluentBit log processing with custom parsers and filters.

## Overview

This example shows how to:
- Configure custom FluentBit parsers for JSON and regex-based log parsing
- Add custom filters for log enrichment, exclusion, and transformation
- Store FluentBit configuration files in S3
- Use the AWS for Fluent Bit init process for multi-config support
- Automatically prefix the FluentBit image tag with `init-` for custom configurations

## Custom Configuration Features

### Parsers

The example configures two parsers:

1. **JSON Parser** (`json_parser`):
   - Automatically extracts fields from JSON logs
   - Preserves timestamp with custom format
   - Applied to all Docker container logs via filter

2. **Custom Format Parser** (`custom_format`):
   - Uses regex to parse custom log format: `timestamp level message`
   - Applied to application-specific logs

### Filters

The example configures three filters:

1. **Modify Filter**:
   - Adds environment metadata to all logs (environment, service, region)
   - Enriches logs with deployment context

2. **Grep Filter**:
   - Excludes health check logs to reduce noise
   - Uses regex pattern matching on Docker logs

3. **Nest Filter**:
   - Groups Kubernetes metadata fields under a single `kubernetes` object
   - Removes `kubernetes_` prefix from nested fields
   - Creates cleaner log structure

## Configuration Files

When you apply this example, the module will:

1. Generate two YAML configuration files (or .conf if using FluentBit v2.x):
   - `parsers.yaml` - Contains parser definitions
   - `filters.yaml` - Contains filter pipeline configuration

2. Upload them to S3 with namespaced keys:
   - `s3://{bucket}/{module-path-id}/parsers.yaml`
   - `s3://{bucket}/{module-path-id}/filters.yaml`

3. Configure the FluentBit container to download and load these files on startup using environment variables:
   - `aws_fluent_bit_init_s3_1` - S3 ARN for parsers config
   - `aws_fluent_bit_init_s3_2` - S3 ARN for filters config

## Prerequisites

Before using this example, you must have:

1. **ECS Task Execution Role** with the following permissions:
   - AWS managed policy: `AmazonECSTaskExecutionRolePolicy`
   - Permission to access the Datadog API key secret (use module's `task_execution_role_policy_json` output)

2. **ECS Task Role** with permissions for Datadog agent and S3 access (use module's `task_role_policy_json` output):
   - The module automatically includes S3 `GetObject` permissions for the config bucket
   - Datadog ECS metadata access permissions

3. **Datadog API Key Secret** in AWS Secrets Manager:
   ```bash
   aws secretsmanager create-secret \
     --name datadog-api-key \
     --secret-string "your-datadog-api-key"
   ```

## Usage

1. Create a `terraform.tfvars` file with your configuration:
   ```hcl
   datadog_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog-api-key-abc123"
   execution_role_arn         = "arn:aws:iam::123456789012:role/ecsTaskExecutionRole"
   task_role_arn              = "arn:aws:iam::123456789012:role/ecsTaskRole"
   service_name               = "my-service"
   environment                = "dev"
   app_image                  = "my-app:latest"
   config_bucket_name         = "my-unique-fluentbit-config"
   ```

2. Run Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What This Example Demonstrates

### Log Processing Pipeline

```
Container Logs → FluentBit → Parser Filters → Custom Filters → Datadog
                     ↓              ↓              ↓
                 S3 Config    JSON/Regex    Modify/Grep/Nest
```

1. **Parser Filters**: Extract structured data from raw logs
2. **Custom Filters**: Enrich, filter, and transform log data
3. **Datadog Output**: Send processed logs to Datadog

### YAML Configuration (Generated)

**parsers.yaml**:
```yaml
parsers:
  - name: json_parser
    format: json
    time_key: timestamp
    time_format: "%Y-%m-%dT%H:%M:%S.%L"
    time_keep: "on"

  - name: custom_format
    format: regex
    regex: "^(?<time>[^ ]+) (?<level>[^ ]+) (?<message>.*)$"
```

**filters.yaml**:
```yaml
pipeline:
  filters:
    - name: parser
      parser: json_parser
      match: "docker.*"
      key_name: log
      reserve_data: "on"

    - name: parser
      parser: custom_format
      match: "app.*"
      key_name: log
      reserve_data: "on"

    - name: modify
      environment: dev
      service: my-service
      region: us-east-1

    - name: grep
      match: "docker.*"
      exclude: health

    - name: nest
      operation: nest
      wildcard:
        - "kubernetes_*"
      nest_under: kubernetes
      remove_prefix: "kubernetes_"
```

## FluentBit Version

This example uses FluentBit v3.2.0 (default) which supports YAML configuration files. The module automatically:
- Uses the `init-3.2.0` image tag when custom configs are defined
- Downloads configuration files from S3 on container startup
- Loads multiple configuration files in sequence

For FluentBit v2.x compatibility, set `log_config_file_format = "conf"` to generate classic .conf files.

## Customization

You can extend this example by adding:

- **Additional Parsers**: logfmt, ltsv, or custom regex patterns
- **More Filters**:
  - `kubernetes`: Enrich with K8s metadata
  - `record_modifier`: Add/remove fields dynamically
  - `throttle`: Rate limit log output
  - `rewrite_tag`: Re-route logs based on content
- **Parser Options**: time zone handling, type casting, field decoding

## Outputs

After applying, you can inspect the generated configuration:

```bash
# View parsers configuration
terraform output -raw parsers_config_s3_key
aws s3 cp s3://$(terraform output -raw config_bucket_name)/$(terraform output -raw parsers_config_s3_key) -

# View filters configuration
terraform output -raw filters_config_s3_key
aws s3 cp s3://$(terraform output -raw config_bucket_name)/$(terraform output -raw filters_config_s3_key) -
```

## References

- [FluentBit Parsers Documentation](https://docs.fluentbit.io/manual/data-pipeline/parsers/configuring-parser)
- [FluentBit Filters Documentation](https://docs.fluentbit.io/manual/pipeline/filters)
- [AWS for Fluent Bit Init Process](https://github.com/aws/aws-for-fluent-bit/blob/mainline/troubleshooting/debugging.md#using-init-tag-for-debug)
- [FluentBit Parser Filter](https://docs.fluentbit.io/manual/pipeline/filters/parser)
- [FluentBit Modify Filter](https://docs.fluentbit.io/manual/pipeline/filters/modify)
- [FluentBit Grep Filter](https://docs.fluentbit.io/manual/pipeline/filters/grep)
- [FluentBit Nest Filter](https://docs.fluentbit.io/manual/pipeline/filters/nest)
