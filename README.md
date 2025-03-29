# Teltonika RUTX SSL
Script to use ACME.sh on Teltonika (OpenWRT) devices to get valid ssl certificates for example with ZeroSSL or Letsencrypt.<br>

## Installation

Place this script in **Custom Scripts** within the Teltonika GUI (`/etc/rc.local`).

### Automatic Installation

You can automatically download and execute the `install.sh` script using the following command:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh
```

### Test Installation

To perform a test installation, run the following command:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh --test
```

### Update

To update the SSL setup script to the latest version, run the following command:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh update
```

### Uninstallation

To uninstall the SSL setup, run the following command:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh uninstall
```

### Multiple Parameters

You can pass multiple parameters to the script at once. For example, to update and then perform a test installation, run:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh update --test
```

### Dry-Run Mode

To see the commands that would be executed without actually running them, use the `-d` or `--dry-run` flag:

```sh
curl -s -o install.sh https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh && sh install.sh --dry-run
```

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

## Changelog

- **Check for acme client before download**.
- **Added support for Cloudflare DNS service**.
- **Support for multiple domains**.
- **Support for wildcard domains**.
- **Added support for Cloudflare Account ID**.
- **Added uninstall option**.
- **Added update option**.
- **Added test installation option**.
- **Added dry-run mode**.
- **Added command line parameter parser**.
