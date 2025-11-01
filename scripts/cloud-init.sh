#!/bin/bash
# cloud-init: install nginx and a simple health page
apt-get update
apt-get -y install nginx
cat > /var/www/html/index.html <<'EOF'
<html><body><h1>Hello from $(hostname)</h1></body></html>
EOF

# health endpoint
mkdir -p /var/www/html/health
cat > /var/www/html/healthz <<'EOF'
OK
EOF
# ensure nginx listens
systemctl restart nginx
