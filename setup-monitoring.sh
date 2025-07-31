#!/bin/bash
# setup-monitoring.sh - Script to create monitoring configuration files

# Create directory structure
mkdir -p monitoring/{prometheus,grafana/{provisioning/{datasources,dashboards},dashboards},loki,promtail}

# Create Prometheus configuration
cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  # Node Exporter - System metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'lizmap-server'

  # PostgreSQL metrics
  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Nginx metrics
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  # Container metrics
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Lizmap application metrics (if you add custom metrics endpoint)
  - job_name: 'lizmap'
    static_configs:
      - targets: ['app:9200']  # Adjust if you add metrics endpoint
    honor_labels: true
EOF

# Create Grafana datasource configuration
cat > monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF

# Create Grafana dashboard provisioning
cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Lizmap Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create Loki configuration
cat > monitoring/loki/loki-config.yaml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

# Create Promtail configuration
cat > monitoring/promtail/promtail-config.yaml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log
    
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))\|(?P<image_name>(?:[^|]*))
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
          image_name:
      - output:
          source: output
EOF

# Create nginx configuration update for metrics
cat > monitoring/nginx-metrics.conf << 'EOF'
# Add this to your nginx configuration to enable metrics
# Place in /etc/nginx/conf.d/ or include in your main nginx.conf

server {
    listen 8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 172.16.0.0/12;  # Docker network
        allow 127.0.0.1;
        deny all;
    }
}
EOF

# Create docker-compose override file for existing services
cat > docker-compose.monitoring.override.yml << 'EOF'
# Override file to add monitoring capabilities to existing services
version: '3.8'

services:
  web:
    # Add nginx status endpoint
    volumes:
      - ./monitoring/nginx-metrics.conf:/etc/nginx/conf.d/metrics.conf:ro
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=8080"
      - "prometheus.io/path=/nginx_status"

  app:
    labels:
      - "prometheus.io/scrape=true"
      - "prometheus.io/port=9000"
    environment:
      # Enable PHP-FPM status page
      - PHP_FPM_STATUS_ENABLE=1

  db:
    labels:
      - "prometheus.io/scrape=true"
    # Ensure postgres exporter can connect
    environment:
      - POSTGRES_DB=lizmap
      - POSTGRES_USER=lizmap
      - POSTGRES_PASSWORD=lizmap1234!
EOF

# Create Lizmap Performance Dashboard JSON
cat > monitoring/grafana/dashboards/lizmap-performance.json << 'EOF'
{
  "dashboard": {
    "title": "Lizmap Performance Monitoring",
    "panels": [
      {
        "title": "Response Time",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "targets": [
          {
            "expr": "rate(nginx_http_requests_total[5m])",
            "legendFormat": "Requests/sec"
          }
        ]
      },
      {
        "title": "CPU Usage",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU %"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "type": "graph",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory %"
          }
        ]
      },
      {
        "title": "PostgreSQL Connections",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends{datname=\"lizmap\"}",
            "legendFormat": "Active Connections"
          }
        ]
      }
    ],
    "schemaVersion": 16,
    "version": 0
  }
}
EOF

echo "Monitoring configuration files created successfully!"
echo ""
echo "To start the monitoring stack:"
echo "1. Run this script: ./setup-monitoring.sh"
echo "2. Start the monitoring services: docker-compose -f docker-compose.yml -f docker-compose-monitoring.yml up -d"
echo "3. Access Grafana at http://localhost:3000 (admin/admin)"
echo "4. Access Prometheus at http://localhost:9090"
echo ""
echo "To integrate with existing Lizmap stack:"
echo "docker-compose -f docker-compose.yml -f docker-compose.monitoring.override.yml -f docker-compose-monitoring.yml up -d"
