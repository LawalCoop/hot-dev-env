#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   HOTOSM Development Environment - HTTPS Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CERTS_DIR="$ROOT_DIR/certs"

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    echo -e "${YELLOW}⚠  mkcert not found. Installing...${NC}"
    echo ""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            echo "Installing mkcert via Homebrew..."
            brew install mkcert
            brew install nss # for Firefox
        else
            echo -e "${RED}✗ Homebrew not found. Please install Homebrew first:${NC}"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Installing mkcert on Linux..."

        # Check if libnss3-tools is installed (needed for Firefox)
        if ! dpkg -l | grep -q libnss3-tools; then
            echo "Installing libnss3-tools..."
            sudo apt-get update
            sudo apt-get install -y libnss3-tools
        fi

        # Download mkcert
        MKCERT_VERSION="v1.4.4"
        MKCERT_BINARY="mkcert-${MKCERT_VERSION}-linux-amd64"

        echo "Downloading mkcert ${MKCERT_VERSION}..."
        wget -O /tmp/mkcert "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/${MKCERT_BINARY}"
        chmod +x /tmp/mkcert
        sudo mv /tmp/mkcert /usr/local/bin/mkcert

        echo -e "${GREEN}✓ mkcert installed${NC}"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows (Git Bash, MSYS2, Cygwin)
        echo "Detected Windows environment"
        echo ""
        echo "Choose installation method:"
        echo "  1) Chocolatey (recommended if installed)"
        echo "  2) Scoop"
        echo "  3) Manual download"
        echo ""
        read -p "Enter choice (1/2/3): " -n 1 -r INSTALL_METHOD
        echo ""
        echo ""

        case $INSTALL_METHOD in
            1)
                # Check if choco is available
                if command -v choco &> /dev/null; then
                    echo "Installing mkcert via Chocolatey..."
                    choco install mkcert -y
                    echo -e "${GREEN}✓ mkcert installed${NC}"
                else
                    echo -e "${RED}✗ Chocolatey not found${NC}"
                    echo ""
                    echo "Install Chocolatey first:"
                    echo "  https://chocolatey.org/install"
                    echo ""
                    echo "Or choose another method (run 'make setup-https' again)"
                    exit 1
                fi
                ;;
            2)
                # Check if scoop is available
                if command -v scoop &> /dev/null; then
                    echo "Installing mkcert via Scoop..."
                    scoop bucket add extras
                    scoop install mkcert
                    echo -e "${GREEN}✓ mkcert installed${NC}"
                else
                    echo -e "${RED}✗ Scoop not found${NC}"
                    echo ""
                    echo "Install Scoop first:"
                    echo "  https://scoop.sh/"
                    echo ""
                    echo "Or choose another method (run 'make setup-https' again)"
                    exit 1
                fi
                ;;
            3)
                echo "Manual installation steps:"
                echo ""
                echo "1. Download mkcert for Windows:"
                echo "   https://github.com/FiloSottile/mkcert/releases/latest"
                echo "   Download: mkcert-v*-windows-amd64.exe"
                echo ""
                echo "2. Rename it to 'mkcert.exe'"
                echo ""
                echo "3. Move it to a directory in your PATH, for example:"
                echo "   C:\\Windows\\System32\\"
                echo "   Or add its location to your PATH"
                echo ""
                echo "4. Run 'make setup-https' again after installation"
                echo ""
                exit 1
                ;;
            *)
                echo -e "${RED}✗ Invalid choice${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${RED}✗ Unsupported OS: $OSTYPE${NC}"
        echo "Please install mkcert manually: https://github.com/FiloSottile/mkcert#installation"
        exit 1
    fi
else
    echo -e "${GREEN}✓ mkcert is installed ($(mkcert -version | head -1))${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Step 1: Install Local Certificate Authority${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if CA is already installed
CAROOT=$(mkcert -CAROOT)
if [ -f "$CAROOT/rootCA.pem" ]; then
    echo -e "${YELLOW}ℹ  Local CA already exists at: $CAROOT${NC}"
    echo ""
    read -p "Reinstall local CA? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkcert -uninstall
        mkcert -install
        echo -e "${GREEN}✓ Local CA reinstalled${NC}"
    else
        echo -e "${GREEN}✓ Using existing local CA${NC}"
    fi
else
    echo "Installing local CA..."
    mkcert -install
    echo -e "${GREEN}✓ Local CA installed${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Step 2: Generate SSL Certificates${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Create certs directory
mkdir -p "$CERTS_DIR"

# Check if certificates already exist
if [ -f "$CERTS_DIR/localhost.crt" ] && [ -f "$CERTS_DIR/localhost.key" ]; then
    echo -e "${YELLOW}ℹ  Certificates already exist${NC}"
    echo ""
    read -p "Regenerate certificates? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Using existing certificates${NC}"
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}   ✓ HTTPS Setup Complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "You can now start the development environment:"
        echo -e "  ${BLUE}make dev${NC}"
        echo ""
        echo "And access services via HTTPS:"
        echo -e "  ${GREEN}https://portal.hotosm.test${NC}"
        echo -e "  ${GREEN}https://login.hotosm.test${NC}"
        echo -e "  ${GREEN}https://dronetm.hotosm.test${NC}"
        echo -e "  ${GREEN}https://fair.hotosm.test${NC}"
        echo -e "  ${GREEN}https://openaerialmap.hotosm.test${NC}"
        echo ""
        exit 0
    fi
fi

# Generate certificates
echo "Generating wildcard certificate for *.localhost and *.hotosm.test..."
cd "$ROOT_DIR"

mkcert -cert-file "$CERTS_DIR/localhost.crt" -key-file "$CERTS_DIR/localhost.key" \
  "*.localhost" "localhost" "*.hotosm.test" "hotosm.test" 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Certificates generated${NC}"
    echo ""
    echo "Certificate covers:"
    echo "  • *.localhost (portal.localhost, login.localhost, etc.)"
    echo "  • localhost"
    echo "  • *.hotosm.test (portal.hotosm.test, login.hotosm.test, etc.)"
    echo "  • hotosm.test"
else
    echo -e "${RED}✗ Failed to generate certificates${NC}"
    exit 1
fi

# Set proper permissions
chmod 644 "$CERTS_DIR/localhost.crt"
chmod 600 "$CERTS_DIR/localhost.key"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   Step 3: Configure /etc/hosts (Optional)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "The *.localhost domains resolve automatically (RFC 6761)."
echo "But if you want to use *.hotosm.test, you need to add entries to /etc/hosts."
echo ""
read -p "Configure /etc/hosts for *.hotosm.test domains? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if script exists
    if [ -f "$ROOT_DIR/add-local-domains.sh" ]; then
        "$ROOT_DIR/add-local-domains.sh"
    else
        echo ""
        echo -e "${YELLOW}ℹ  add-local-domains.sh not found. Adding domains manually...${NC}"

        DOMAINS=(
            "portal.hotosm.test"
            "login.hotosm.test"
            "dronetm.hotosm.test"
            "fair.hotosm.test"
            "openaerialmap.hotosm.test"
            "minio.hotosm.test"
            "traefik.hotosm.test"
        )

        echo ""
        echo "Add these lines to /etc/hosts:"
        echo ""
        for domain in "${DOMAINS[@]}"; do
            echo "127.0.0.1 $domain"
        done
        echo ""
        echo "Run this command:"
        echo -e "${BLUE}sudo nano /etc/hosts${NC}"
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   ✓ HTTPS Setup Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Start the development environment:"
echo -e "   ${BLUE}make dev${NC}"
echo ""
echo "2. Access services via HTTPS:"
echo ""
echo "   Main services (.hotosm.test):"
echo -e "   ${GREEN}https://portal.hotosm.test${NC}            - Portal application"
echo -e "   ${GREEN}https://login.hotosm.test${NC}             - Login & authentication"
echo -e "   ${GREEN}https://dronetm.hotosm.test${NC}           - Drone Tasking Manager"
echo -e "   ${GREEN}https://fair.hotosm.test${NC}              - fAIr (AI-assisted mapping)"
echo -e "   ${GREEN}https://openaerialmap.hotosm.test${NC}     - OpenAerialMap"
echo ""
echo "   Infrastructure (.hotosm.test):"
echo -e "   ${GREEN}https://minio.hotosm.test${NC}        - S3 storage console"
echo -e "   ${GREEN}https://traefik.hotosm.test${NC}      - Traefik dashboard"
echo ""
echo "   ${YELLOW}Note: *.hotosm.test requires /etc/hosts configuration${NC}"
echo "   ${YELLOW}      (Should be configured if you ran 'make setup' first)${NC}"
echo ""
echo "Your browser should show a valid certificate (no warnings)."
echo ""
echo -e "${YELLOW}📚 For more details, see: docs/HTTPS_SETUP.md${NC}"
echo ""
