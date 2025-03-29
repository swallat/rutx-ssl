#!/bin/sh

# User prompts for domains, email address, certificate authority, and DNS service
read -p "Please enter your domains (separated by spaces): " DOMAINS
read -p "Please enter your email address: " MAIL
read -p "Please enter the certificate authority (e.g., letsencrypt): " CA

# DNS service selection
echo "Please select your DNS service:"
options=("Hetzner" "Cloudflare")
select opt in "${options[@]}"
do
  case $REPLY in
    1)
      SERVICE="dns_hetzner"
      read -p "Please enter your HETZNER_Token: " HETZNER_TOKEN
      break
      ;;
    2)
      SERVICE="dns_cf"
      read -p "Please enter your Cloudflare_Token: " CF_TOKEN
      read -p "Please enter your Cloudflare_Account_ID: " CF_ACCOUNT_ID
      break
      ;;
    *)
      echo "Invalid option $REPLY"
      ;;
  esac
done

# SSL script creation
echo "Creating ssl.sh script..."
cat > /root/ssl.sh << EOF
#!/bin/sh

# Domains and email configuration
# Wildcard domains are supported, e.g., *.example.com
DOMAINS="$DOMAINS"
MAIL="$MAIL"

# DNS service for ACME
SERVICE="$SERVICE"
SERVICE_TOKEN="HETZNER_Token"
if [ "\$SERVICE" = "dns_cf" ]; then
  SERVICE_TOKEN="CF_Token"
fi

# Certificate authority
CA="$CA"

# Install ACME client if not already installed
if [ ! -f /root/.acme.sh/acme.sh ]; then
  curl -s https://get.acme.sh | sh -s email=\$MAIL
fi

# Request and import certificates
for DOMAIN in \$DOMAINS; do
  /root/.acme.sh/acme.sh --force --issue --dns \$SERVICE --server \$CA -d \$DOMAIN \
    --fullchainpath /etc/uhttpd.crt --keypath /etc/uhttpd.key \
    --reloadcmd "/etc/init.d/uhttpd restart" --log
done
EOF

chmod a+x /root/ssl.sh

# Update rc.local
echo "Updating rc.local..."
if ! grep -q '/root/ssl.sh' /etc/rc.local; then
  sed -i '/^exit 0/i /root/ssl.sh >/dev/null 2>&1 &' /etc/rc.local
fi

# Update .profile
echo "Updating .profile..."
if [ ! -f /root/.profile ]; then
  echo "Creating .profile..."
  touch /root/.profile
fi

# Add HETZNER_Token if Hetzner is selected
if [ "$SERVICE" = "dns_hetzner" ]; then
  if ! grep -q '^export HETZNER_Token=' /root/.profile; then
    echo "Adding HETZNER_Token to .profile..."
    echo "export HETZNER_Token=\"$HETZNER_TOKEN\"" >> /root/.profile
  fi
fi

# Add CF_Token and CF_Account_ID if Cloudflare is selected
if [ "$SERVICE" = "dns_cf" ]; then
  if ! grep -q '^export CF_Token=' /root/.profile; then
    echo "Adding CF_Token to .profile..."
    echo "export CF_Token=\"$CF_TOKEN\"" >> /root/.profile
  fi
  if ! grep -q '^export CF_Account_ID=' /root/.profile; then
    echo "Adding CF_Account_ID to .profile..."
    echo "export CF_Account_ID=\"$CF_ACCOUNT_ID\"" >> /root/.profile
  fi
fi

echo "Installation completed."

