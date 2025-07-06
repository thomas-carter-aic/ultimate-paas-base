#!/bin/bash

# AI-Native PaaS Platform Setup Script
# This script sets up the development environment for the platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PYTHON_VERSION="3.9"
NODE_VERSION="18"
PLATFORM_NAME="AI-Native PaaS Platform"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Python version
check_python_version() {
    if command_exists python3; then
        PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        if [[ "$PYTHON_VER" == "$PYTHON_VERSION"* ]]; then
            print_success "Python $PYTHON_VER is installed"
            return 0
        else
            print_warning "Python $PYTHON_VER found, but $PYTHON_VERSION is recommended"
            return 1
        fi
    else
        print_error "Python 3 is not installed"
        return 1
    fi
}

# Function to check Node.js version
check_node_version() {
    if command_exists node; then
        NODE_VER=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VER" -ge "$NODE_VERSION" ]]; then
            print_success "Node.js v$(node --version | cut -d'v' -f2) is installed"
            return 0
        else
            print_warning "Node.js v$(node --version | cut -d'v' -f2) found, but v$NODE_VERSION+ is recommended"
            return 1
        fi
    else
        print_error "Node.js is not installed"
        return 1
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    print_status "Installing system dependencies..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt-get; then
            # Ubuntu/Debian
            sudo apt-get update
            sudo apt-get install -y \
                python3 python3-pip python3-venv \
                nodejs npm \
                postgresql-client \
                redis-tools \
                docker.io docker-compose \
                git curl wget \
                build-essential \
                libpq-dev \
                libssl-dev \
                libffi-dev
        elif command_exists yum; then
            # CentOS/RHEL
            sudo yum update -y
            sudo yum install -y \
                python3 python3-pip \
                nodejs npm \
                postgresql \
                redis \
                docker docker-compose \
                git curl wget \
                gcc gcc-c++ make \
                postgresql-devel \
                openssl-devel \
                libffi-devel
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            brew update
            brew install \
                python@3.9 \
                node \
                postgresql \
                redis \
                docker \
                git curl wget
        else
            print_error "Homebrew is not installed. Please install it first: https://brew.sh/"
            exit 1
        fi
    fi
    
    print_success "System dependencies installed"
}

# Function to setup Python virtual environment
setup_python_env() {
    print_status "Setting up Python virtual environment..."
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_status "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    print_status "Installing Python dependencies..."
    pip install -r requirements.txt
    pip install -r requirements-dev.txt
    
    print_success "Python environment setup complete"
}

# Function to setup Node.js environment
setup_node_env() {
    print_status "Setting up Node.js environment..."
    
    # Install AWS CDK globally
    npm install -g aws-cdk
    
    # Install CDK dependencies
    if [ -d "deployments/aws-cdk" ]; then
        cd deployments/aws-cdk
        npm install
        cd ../..
        print_success "CDK dependencies installed"
    fi
    
    print_success "Node.js environment setup complete"
}

# Function to setup AWS CLI
setup_aws_cli() {
    print_status "Setting up AWS CLI..."
    
    if ! command_exists aws; then
        # Install AWS CLI
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm AWSCLIV2.pkg
        fi
    fi
    
    # Check if AWS is configured
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "AWS CLI is configured"
    else
        print_warning "AWS CLI is not configured. Run 'aws configure' to set up your credentials"
    fi
}

# Function to setup Docker
setup_docker() {
    print_status "Setting up Docker..."
    
    if command_exists docker; then
        # Start Docker service
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo systemctl start docker
            sudo systemctl enable docker
            # Add user to docker group
            sudo usermod -aG docker $USER
        fi
        
        # Test Docker
        if docker --version >/dev/null 2>&1; then
            print_success "Docker is installed and running"
        else
            print_warning "Docker is installed but may not be running"
        fi
    else
        print_error "Docker is not installed"
    fi
}

# Function to setup local services
setup_local_services() {
    print_status "Setting up local services..."
    
    # Create docker-compose.yml if it doesn't exist
    if [ ! -f "docker-compose.yml" ]; then
        cat > docker-compose.yml << EOF
version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: paas_dev
      POSTGRES_USER: paas_user
      POSTGRES_PASSWORD: paas_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    
  redis:
    image: redis:6-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    
  localstack:
    image: localstack/localstack:latest
    environment:
      SERVICES: s3,dynamodb,sqs,sns,lambda,ecs,sagemaker
      DEBUG: 1
      DATA_DIR: /tmp/localstack/data
    ports:
      - "4566:4566"
    volumes:
      - localstack_data:/tmp/localstack
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  postgres_data:
  redis_data:
  localstack_data:
EOF
        print_success "docker-compose.yml created"
    fi
    
    # Start local services
    docker-compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 10
    
    print_success "Local services started"
}

# Function to setup database
setup_database() {
    print_status "Setting up database..."
    
    # Wait for PostgreSQL to be ready
    until docker-compose exec postgres pg_isready -U paas_user -d paas_dev; do
        print_status "Waiting for PostgreSQL to be ready..."
        sleep 2
    done
    
    # Run database migrations (if they exist)
    if [ -f "alembic.ini" ]; then
        source venv/bin/activate
        alembic upgrade head
        print_success "Database migrations applied"
    fi
    
    print_success "Database setup complete"
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p data
    mkdir -p plugins
    mkdir -p temp
    mkdir -p backups
    
    print_success "Directories created"
}

# Function to setup environment variables
setup_environment() {
    print_status "Setting up environment variables..."
    
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# AI-Native PaaS Platform Environment Variables

# Environment
PAAS_ENVIRONMENT=development
PAAS_DEBUG=true
PAAS_LOG_LEVEL=DEBUG

# Database
DATABASE_URL=postgresql://paas_user:paas_password@localhost:5432/paas_dev

# Redis
REDIS_URL=redis://localhost:6379/0

# AWS (for local development with LocalStack)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_ENDPOINT_URL=http://localhost:4566

# Security
JWT_SECRET_KEY=dev-secret-key-change-in-production

# AI/ML
SAGEMAKER_ENDPOINT_SCALING=paas-dev-scaling-predictor
SAGEMAKER_ENDPOINT_ANOMALY=paas-dev-anomaly-detector

# Plugin System
PLUGIN_SANDBOX_ENABLED=true
PLUGIN_MAX_MEMORY_MB=256

# API
API_HOST=0.0.0.0
API_PORT=8000
EOF
        print_success ".env file created"
    else
        print_status ".env file already exists"
    fi
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    source venv/bin/activate
    
    # Run unit tests
    python -m pytest tests/unit/ -v
    
    # Run integration tests (if services are running)
    if docker-compose ps | grep -q "Up"; then
        python -m pytest tests/integration/ -v
    else
        print_warning "Skipping integration tests - local services not running"
    fi
    
    print_success "Tests completed"
}

# Function to setup pre-commit hooks
setup_pre_commit() {
    print_status "Setting up pre-commit hooks..."
    
    source venv/bin/activate
    
    if command_exists pre-commit; then
        pre-commit install
        print_success "Pre-commit hooks installed"
    else
        print_warning "pre-commit not found, skipping hook setup"
    fi
}

# Function to display final instructions
display_instructions() {
    print_success "Setup completed successfully!"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Activate the virtual environment: source venv/bin/activate"
    echo "2. Configure AWS credentials: aws configure"
    echo "3. Start the platform: python -m src.main"
    echo "4. Access the API at: http://localhost:8000"
    echo "5. View API documentation at: http://localhost:8000/docs"
    echo
    echo -e "${BLUE}Useful commands:${NC}"
    echo "- Run tests: pytest"
    echo "- Start local services: docker-compose up -d"
    echo "- Stop local services: docker-compose down"
    echo "- View logs: docker-compose logs -f"
    echo "- Deploy infrastructure: cd deployments/aws-cdk && cdk deploy"
    echo
    echo -e "${GREEN}Happy coding! 🚀${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $PLATFORM_NAME Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    
    # Install system dependencies if needed
    if ! check_python_version || ! check_node_version; then
        print_status "Installing missing dependencies..."
        install_system_dependencies
    fi
    
    # Setup environments
    setup_python_env
    setup_node_env
    setup_aws_cli
    setup_docker
    
    # Setup project
    create_directories
    setup_environment
    setup_local_services
    setup_database
    setup_pre_commit
    
    # Run tests to verify setup
    run_tests
    
    # Display final instructions
    display_instructions
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --skip-tests   Skip running tests during setup"
        echo "  --no-services  Skip starting local services"
        echo
        exit 0
        ;;
    --skip-tests)
        SKIP_TESTS=true
        ;;
    --no-services)
        NO_SERVICES=true
        ;;
esac

# Run main setup
main

exit 0
