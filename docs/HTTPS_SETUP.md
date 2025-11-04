# HTTPS Setup for Local Development

This guide explains how to set up HTTPS for local development using `mkcert` to generate trusted SSL certificates.

## Why HTTPS Locally?

Modern web features require HTTPS:
- **Service Workers** - Required for PWA features
- **Secure Cookies** - Cross-origin authentication
- **WebAuthn/Passkeys** - Hanko authentication requires secure context
- **Geolocation** - Browser APIs require HTTPS
- **Camera/Microphone** - Media device access
- **Cross-origin requests** - CORS policies work better with HTTPS

## Quick Setup (5 minutes)

### 1. Install mkcert

```bash
# Ubuntu/Debian
sudo apt install libnss3-tools
wget -O mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
chmod +x mkcert
sudo mv mkcert /usr/local/bin/

# macOS
brew install mkcert
brew install nss # for Firefox

# Verify installation
mkcert -version
```

### 2. Install Local CA

This creates a local Certificate Authority that your browser will trust:

```bash
mkcert -install
```

Output:
```
Created a new local CA
The local CA is now installed in the system trust store!
```

### 3. Generate Certificates for *.localhost

```bash
cd /home/willaru/dev/HOT/hot-dev-env

# Generate wildcard certificate
mkcert -cert-file certs/localhost.crt -key-file certs/localhost.key \
  "*.localhost" "localhost" "*.hotosm.test" "hotosm.test"
```

This creates:
- `certs/localhost.crt` - SSL certificate
- `certs/localhost.key` - Private key

The certificate covers:
- `*.localhost` - All subdomains (portal.localhost, login.localhost, etc.)
- `localhost` - Root domain
- `*.hotosm.test` - Alternative TLD for testing
- `hotosm.test` - Alternative root domain

### 4. Configure Traefik

The `traefik-tls.yml` file is already configured to use these certificates:

```yaml
tls:
  certificates:
    - certFile: /certs/localhost.crt
      keyFile: /certs/localhost.key
  stores:
    default:
      defaultCertificate:
        certFile: /certs/localhost.crt
        keyFile: /certs/localhost.key
```

### 5. Update /etc/hosts (if using .test domains)

```bash
sudo nano /etc/hosts
```

Add:
```
127.0.0.1 portal.hotosm.test
127.0.0.1 login.hotosm.test
127.0.0.1 dronetm.hotosm.test
127.0.0.1 minio.hotosm.test
127.0.0.1 traefik.hotosm.test
```

Or use the provided script:
```bash
./add-local-domains.sh
```

### 6. Start Services

```bash
make dev
```

### 7. Access with HTTPS

Open in your browser:
- https://portal.localhost (or https://portal.hotosm.test)
- https://login.localhost
- https://dronetm.localhost
- https://minio.localhost
- https://traefik.localhost

You should see a **valid certificate** (no browser warnings).

## How It Works

### mkcert Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. mkcert -install                                          │
│    Creates local CA and installs to system trust store     │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│ 2. mkcert -cert-file ... -key-file ... "*.localhost"       │
│    Signs certificate with local CA                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────┐
│ 3. Traefik mounts certs/ and uses certificates             │
│    Serves all *.localhost with valid HTTPS                  │
└─────────────────────────────────────────────────────────────┘
```

### Certificate Chain

```
[Browser Trust Store]
        │
        ├─ mkcert local CA (installed by mkcert -install)
        │
        └─ localhost.crt (signed by local CA)
                │
                └─ *.localhost domains
```

Because the browser trusts the local CA, it automatically trusts all certificates signed by it.

## Troubleshooting

### Browser shows "Not Secure" warning

1. **Check mkcert is installed:**
   ```bash
   mkcert -version
   ```

2. **Reinstall local CA:**
   ```bash
   mkcert -uninstall
   mkcert -install
   ```

3. **Regenerate certificates:**
   ```bash
   cd /home/willaru/dev/HOT/hot-dev-env
   rm -rf certs/*
   mkcert -cert-file certs/localhost.crt -key-file certs/localhost.key \
     "*.localhost" "localhost" "*.hotosm.test" "hotosm.test"
   ```

4. **Restart services:**
   ```bash
   make restart
   ```

5. **Clear browser cache** and reload (Ctrl+Shift+R)

### Firefox still shows warnings

Firefox uses its own certificate store:

```bash
# macOS
brew install nss

# Ubuntu/Debian
sudo apt install libnss3-tools

# Reinstall CA
mkcert -install
```

### Certificate expired

mkcert certificates are valid for 2+ years. To renew:

```bash
cd /home/willaru/dev/HOT/hot-dev-env
rm certs/*
mkcert -cert-file certs/localhost.crt -key-file certs/localhost.key \
  "*.localhost" "localhost" "*.hotosm.test" "hotosm.test"
make restart
```

### Traefik not picking up certificates

1. **Check certificates exist:**
   ```bash
   ls -la certs/
   # Should show localhost.crt and localhost.key
   ```

2. **Check Traefik config:**
   ```bash
   cat traefik-tls.yml
   # Verify paths match certificate locations
   ```

3. **Check Traefik logs:**
   ```bash
   docker compose logs traefik | grep -i tls
   ```

4. **Check volume mount:**
   ```bash
   docker compose config | grep -A 5 "traefik:" | grep -i volume
   # Should mount ./certs:/certs
   ```

### HTTP still works, HTTPS doesn't

This is expected! Traefik redirects HTTP → HTTPS automatically. If you access `http://portal.localhost`, it should redirect to `https://portal.localhost`.

If it doesn't redirect:
1. Check `docker-compose.yml` has the redirect middleware configured
2. Check Traefik dashboard: https://traefik.localhost

## Alternative: Using .test TLD

The `.localhost` TLD always resolves to 127.0.0.1 by RFC 6761. But you can also use `.test`:

1. Generate certificate with `.test` domains (already included above)
2. Add to /etc/hosts:
   ```
   127.0.0.1 portal.hotosm.test
   127.0.0.1 login.hotosm.test
   # etc.
   ```

3. Access: https://portal.hotosm.test

Advantage: `.test` is reserved for testing and won't conflict with real domains.

## Security Notes

### Is mkcert safe for development?

**Yes**, mkcert is designed specifically for local development:

- The local CA is **only trusted on your machine**
- Certificates signed by your local CA **won't be trusted** on other machines
- The CA private key is stored in your OS keychain with restricted permissions
- mkcert follows security best practices from the Chromium and Firefox teams

### Can I use these certificates in production?

**No!** These certificates should **never** be used in production:

- They're self-signed by a local CA
- No public CA will trust them
- The private key is on your development machine

For production, use Let's Encrypt (automatically configured in Traefik for deployment).

## Uninstalling

To remove mkcert and clean up:

```bash
# Uninstall local CA
mkcert -uninstall

# Remove certificates
cd /home/willaru/dev/HOT/hot-dev-env
rm -rf certs/*

# Remove mkcert binary (optional)
sudo rm /usr/local/bin/mkcert
```

## Advanced Configuration

### Custom Domains

To add more domains to the certificate:

```bash
mkcert -cert-file certs/localhost.crt -key-file certs/localhost.key \
  "*.localhost" "localhost" \
  "*.hotosm.test" "hotosm.test" \
  "myapp.local" "*.myapp.local"
```

### Separate Certificates per Service

Instead of a wildcard, you can create individual certificates:

```bash
mkcert -cert-file certs/portal.crt -key-file certs/portal.key portal.localhost
mkcert -cert-file certs/login.crt -key-file certs/login.key login.localhost
```

Then configure Traefik to use specific certificates per router.

### Location of mkcert CA

```bash
# View CA location
mkcert -CAROOT

# Typical locations:
# Linux: ~/.local/share/mkcert
# macOS: ~/Library/Application Support/mkcert
# Windows: %LOCALAPPDATA%\mkcert
```

**Important**: Keep the CA private key (`rootCA-key.pem`) secure! Anyone with this key can create certificates that your browser will trust.

## References

- [mkcert GitHub](https://github.com/FiloSottile/mkcert)
- [RFC 6761 - .localhost TLD](https://tools.ietf.org/html/rfc6761)
- [Traefik TLS Configuration](https://doc.traefik.io/traefik/https/tls/)
- [MDN: Secure Contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts)
