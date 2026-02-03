#!/bin/bash
#
# reset-ralph-state.sh
#
# Resets Ralph autonomous workflow state to a clean starting point.
# This is useful for:
# - Starting fresh with the template
# - Clearing old test data
# - Recovering from corrupted state
#
# Usage:
#   ./scripts/reset-ralph-state.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Change to project root
cd "$PROJECT_ROOT"

print_header "Ralph State Reset"

echo "This script will reset Ralph autonomous workflow state:"
echo "  1. Clear .ralph/active/ (active issue logs)"
echo "  2. Clear .ralph/archived/ (archived issue logs)"
echo "  3. Reset .ralph/state/ files to clean initial values"
echo ""
print_warning "This will delete all Ralph workflow history and state!"
echo ""
echo -e "${YELLOW}Are you sure you want to continue? [y/N]${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_error "Aborted by user"
    exit 1
fi

# Step 1: Clear active directory
print_header "Step 1: Clearing active issue logs"

if [ -d ".ralph/active" ]; then
    if [ "$(ls -A .ralph/active/)" ]; then
        echo "Removing files from .ralph/active/..."
        rm -rf .ralph/active/*
        print_success "Active directory cleared"
    else
        print_warning "Active directory already empty"
    fi
else
    print_error ".ralph/active/ directory not found"
fi

# Step 2: Clear archived directory
print_header "Step 2: Clearing archived issue logs"

if [ -d ".ralph/archived" ]; then
    if [ "$(ls -A .ralph/archived/)" ]; then
        echo "Removing files from .ralph/archived/..."
        rm -rf .ralph/archived/*
        print_success "Archived directory cleared"
    else
        print_warning "Archived directory already empty"
    fi
else
    print_error ".ralph/archived/ directory not found"
fi

# Step 3: Reset state files
print_header "Step 3: Resetting state files"

if [ -d ".ralph/state" ]; then
    # Reset circuit_breaker.json
    echo "Resetting circuit_breaker.json..."
    cat > .ralph/state/circuit_breaker.json <<'EOF'
{
  "state": "CLOSED",
  "consecutive_no_progress": 0,
  "consecutive_same_error": 0,
  "consecutive_validation_fails": 0,
  "last_error": null,
  "last_transition": null,
  "files_changed_history": []
}
EOF
    print_success "Circuit breaker reset to CLOSED"

    # Reset counters.json
    echo "Resetting counters.json..."
    cat > .ralph/state/counters.json <<'EOF'
{
  "iteration": 0,
  "successful_issues": 0,
  "failed_issues": 0,
  "blocked_issues": 0,
  "total_api_calls": 0
}
EOF
    print_success "Counters reset to zero"

    # Reset history.json
    echo "Resetting history.json..."
    echo "[]" > .ralph/state/history.json
    print_success "History cleared"

    # Reset rate_limit.json
    echo "Resetting rate_limit.json..."
    cat > .ralph/state/rate_limit.json <<'EOF'
{
  "calls": 0,
  "window_start": null,
  "limit": 100
}
EOF
    print_success "Rate limit reset"

    # Remove session.json (will be recreated on next run)
    if [ -f ".ralph/state/session.json" ]; then
        echo "Removing session.json..."
        rm .ralph/state/session.json
        print_success "Session file removed (will be recreated on next run)"
    fi
else
    print_error ".ralph/state/ directory not found"
    exit 1
fi

# Summary
print_header "Reset Complete!"

echo ""
echo "Summary of actions:"
echo "  ✓ .ralph/active/ cleared"
echo "  ✓ .ralph/archived/ cleared"
echo "  ✓ Circuit breaker reset to CLOSED"
echo "  ✓ All counters reset to 0"
echo "  ✓ History cleared"
echo "  ✓ Rate limit reset"
echo "  ✓ Session file removed"
echo ""
print_success "Ralph state is now clean and ready for fresh start!"
