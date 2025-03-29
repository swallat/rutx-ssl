# Teltonika RUTX SSL
Script to use ACME.sh on Teltonika (OpenWRT) devices to get valid ssl certificates for example with ZeroSSL or Letsencrypt.<br>

## Installation

Place this script in **Custom Scripts** within the Teltonika GUI (`/etc/rc.local`).

### Automatic Installation

You can automatically download and execute the `install.sh` script using the following command:

```sh
curl -s -o install_acme.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install_acme.sh
```

### Test Installation

To perform a test installation, run the following command:

```sh
curl -s -o install_acme.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install_acme.sh --test
```

### Uninstallation

To uninstall the SSL setup, run the following command:

```sh
curl -s -o install_acme.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install_acme.sh uninstall
```

## Configuration

After installation, the following environment variables need to be configured in `/root/.profile`:

| Variable | Description |
|----------|-------------|
| `HETZNER_Token` | API token for Hetzner DNS |
| `CF_Token` | API token for Cloudflare |
| `CF_Account_ID` | Account ID for Cloudflare |
| `DOMAINS` | Comma-separated list of domains (e.g., `example.com,*.example.com`) |
| `MAIL` | Your email address for certificate notifications |

## Usage

After configuration, the script will run automatically on system startup and handle certificate renewal.

### Manual Execution

```sh
/usr/local/bin/ssl-setup.sh
```

### Additional Options

- `--dry-run`: Simulates execution without making actual changes
- `--verbose`: Enables detailed logging
- `update`: Updates the script to the latest version

## Supported DNS Services

- Hetzner
- Cloudflare

## Supported Features

- Multiple Domains
- Wildcard Domains (e.g., `*.example.com`)

## Tested Devices

| Device  | Firmware Version          |
|---------|---------------------------|
| RUTX50  | RUTX_R_00.07.06.3         |
| RUTX11  | RUTX_R_00.07.12           |

## Troubleshooting

The script creates logs at `/var/log/ssl-setup.log`. These logs can provide valuable information when troubleshooting.

If certificate issuance fails, please check:
- The correctness of your API tokens
- The DNS configuration for your domains
- The accessibility of the ACME server

## Changelog

- **Added support for Cloudflare DNS service**.
- **Support for multiple domains**.
- **Support for wildcard domains**.
- **Added support for Cloudflare Account ID**.
- **Added uninstall option**.
- **Added update option**.
- **Added test installation option**.
- **Added dry-run mode**.
- **Added command line parameter parser**.
- **Check for acme client before download**.