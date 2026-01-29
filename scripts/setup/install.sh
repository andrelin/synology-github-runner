#!/bin/bash
# GitHub Self-Hosted Runner - Automated Installation Script
# Compatible with Synology DSM 7.0+

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/volume1/docker/github-runner"
SCRIPTS_DIR="/volume1/scripts"

# Print functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  GitHub Self-Hosted Runner - Installation Script              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running on Synology
check_synology() {
    if [ ! -f /etc/synoinfo.conf ]; then
        print_warning "This script is designed for Synology NAS but can work on other Linux systems"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Running on Synology DSM"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        print_warning "Please install Container Manager from DSM Package Center"
        exit 1
    fi
    print_success "Docker is installed"

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"

    # Check permissions
    if ! docker ps &> /dev/null; then
        print_error "Cannot access Docker (permission denied)"
        print_warning "Run this script with sudo or add your user to docker group"
        exit 1
    fi
    print_success "Docker access verified"

    echo ""
}

# Create directory structure
create_directories() {
    print_step "Creating directory structure..."

    mkdir -p "$INSTALL_DIR"/{data/{workspace,cache},config,logs}
    mkdir -p "$SCRIPTS_DIR"

    print_success "Directories created at $INSTALL_DIR"
    echo ""
}

# Copy configuration files
setup_configuration() {
    print_step "Setting up configuration..."

    # Copy docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml "$INSTALL_DIR/"
        print_success "Copied docker-compose.yml"
    else
        print_error "docker-compose.yml not found in current directory"
        exit 1
    fi

    # Copy .env.example
    if [ -f ".env.example" ]; then
        if [ -f "$INSTALL_DIR/.env" ]; then
            print_warning ".env already exists, creating .env.example"
            cp .env.example "$INSTALL_DIR/.env.example"
        else
            cp .env.example "$INSTALL_DIR/.env"
            print_warning "Created .env file - YOU MUST EDIT THIS BEFORE STARTING"
        fi
    fi

    echo ""
}

# Install monitoring scripts
install_monitoring() {
    print_step "Installing monitoring scripts..."

    if [ -f "scripts/monitoring/runner-health-check.sh" ]; then
        cp scripts/monitoring/runner-health-check.sh "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/runner-health-check.sh"
        print_success "Installed runner-health-check.sh"
    fi

    if [ -f "scripts/monitoring/runner-dashboard.sh" ]; then
        cp scripts/monitoring/runner-dashboard.sh "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/runner-dashboard.sh"
        print_success "Installed runner-dashboard.sh"
    fi

    echo ""
}

# Configure .env file interactively
configure_env() {
    print_step "Configuring environment variables..."

    if [ ! -f "$INSTALL_DIR/.env" ]; then
        print_error ".env file not found"
        return 1
    fi

    echo ""
    read -p "Would you like to configure .env now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        # Get repository URL
        read -p "GitHub repository URL (https://github.com/owner/repo): " REPO_URL
        sed -i.bak "s|REPO_URL=.*|REPO_URL=$REPO_URL|" "$INSTALL_DIR/.env"

        # Get GitHub PAT
        echo ""
        print_warning "You need a GitHub Personal Access Token with 'repo' and 'workflow' scopes"
        echo "Generate at: https://github.com/settings/tokens"
        read -sp "GitHub PAT (will be hidden): " GITHUB_PAT
        echo ""
        sed -i.bak "s|GITHUB_PAT=.*|GITHUB_PAT=$GITHUB_PAT|" "$INSTALL_DIR/.env"

        # Get runner name
        read -p "Runner name (default: synology-runner): " RUNNER_NAME
        RUNNER_NAME=${RUNNER_NAME:-synology-runner}
        sed -i.bak "s|RUNNER_NAME=.*|RUNNER_NAME=$RUNNER_NAME|" "$INSTALL_DIR/.env"

        # Clean up backup files
        rm -f "$INSTALL_DIR/.env.bak"

        print_success "Configuration saved"
    else
        print_warning "You must manually edit $INSTALL_DIR/.env before starting the runner"
    fi

    echo ""
}

# Test configuration
test_configuration() {
    print_step "Testing configuration..."

    cd "$INSTALL_DIR"

    # Test docker-compose config
    if docker-compose config > /dev/null 2>&1 || docker compose config > /dev/null 2>&1; then
        print_success "Docker Compose configuration is valid"
    else
        print_error "Docker Compose configuration is invalid"
        return 1
    fi

    echo ""
}

# Start runner
start_runner() {
    print_step "Starting GitHub runner..."

    cd "$INSTALL_DIR"

    if docker-compose up -d 2>/dev/null || docker compose up -d 2>/dev/null; then
        print_success "Runner container started"

        echo ""
        print_step "Checking runner status..."
        sleep 5

        if docker ps | grep -q github-runner; then
            print_success "Runner is running!"
            echo ""
            echo "View logs: docker logs -f github-runner"
            echo "View status: $SCRIPTS_DIR/runner-dashboard.sh"
        else
            print_error "Runner failed to start"
            echo "Check logs: docker logs github-runner"
            return 1
        fi
    else
        print_error "Failed to start runner"
        return 1
    fi

    echo ""
}

# Setup monitoring schedule
setup_monitoring_schedule() {
    print_step "Setting up monitoring schedule..."

    echo ""
    print_warning "To complete monitoring setup:"
    echo "1. Open DSM Control Panel → Task Scheduler"
    echo "2. Create → Scheduled Task → User-defined script"
    echo "3. Run as: root"
    echo "4. Schedule: Every 5 minutes"
    echo "5. Script: $SCRIPTS_DIR/runner-health-check.sh"
    echo ""
    echo "See docs/04-MONITORING.md for detailed instructions"
    echo ""
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Installation Complete!                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📍 Installation directory: $INSTALL_DIR"
    echo "📍 Scripts directory: $SCRIPTS_DIR"
    echo ""
    echo "🎯 Next Steps:"
    echo "  1. Verify runner registered: https://github.com/YOUR_REPO/settings/actions/runners"
    echo "  2. View runner status: $SCRIPTS_DIR/runner-dashboard.sh"
    echo "  3. Set up monitoring (see above)"
    echo "  4. Test with a workflow"
    echo ""
    echo "📚 Documentation: See README.md and docs/"
    echo ""
    echo "🐛 Issues? Check docs/05-TROUBLESHOOTING.md"
    echo ""
}

# Main installation flow
main() {
    print_header

    # Check if already installed
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_warning "Runner appears to be already installed at $INSTALL_DIR"
        read -p "Reinstall? This will preserve your .env file (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    check_synology
    check_prerequisites
    create_directories
    setup_configuration
    install_monitoring
    configure_env
    test_configuration

    echo ""
    read -p "Start runner now? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        start_runner
    else
        print_warning "Runner not started. To start manually:"
        echo "  cd $INSTALL_DIR"
        echo "  docker-compose up -d"
    fi

    setup_monitoring_schedule
    print_summary
}

# Run installation
main "$@"
