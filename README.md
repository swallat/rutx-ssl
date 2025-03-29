# Teltonika RUTX SSL
Script to use ACME.sh on Teltonika (OpenWRT) devices to get valid ssl certificates for example with ZeroSSL or Letsencrypt.<br>

## Installation

Place this script in **Custom Scripts** within the Teltonika GUI (`/etc/rc.local`).

### Automatic Installation

You can automatically download and execute the `install.sh` script using the following command:

```sh
curl -s https://raw.githubusercontent.com/swallat/rutx-ssl/refs/heads/main/install.sh | sh
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

