#!/usr/bin/env bash
# run-tests.sh - Convenient script to run setver tests

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 Setver Test Runner"
echo "===================="
echo ""

# Check if bats is installed
if ! command -v bats &> /dev/null; then
  echo -e "${RED}❌ bats-core is not installed${NC}"
  echo ""
  echo "To install bats-core, run:"
  echo "  $SCRIPT_DIR/install-bats.sh"
  echo ""
  echo "Or install manually:"
  echo "  macOS:  brew install bats-core"
  echo "  Linux:  sudo apt-get install bats"
  exit 1
fi

echo -e "${GREEN}✅ bats-core found: $(bats --version)${NC}"
echo ""

# Parse arguments
FILTER=""
VERBOSE=0
TIMING=0
TAP=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--filter)
      FILTER="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=1
      shift
      ;;
    -t|--timing)
      TIMING=1
      shift
      ;;
    --tap)
      TAP=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -f, --filter TEXT    Run only tests matching TEXT"
      echo "  -v, --verbose        Show verbose output"
      echo "  -t, --timing         Show timing information"
      echo "  --tap                Output in TAP format"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                          # Run all tests"
      echo "  $0 --filter \"bump major\"    # Run only major bump tests"
      echo "  $0 --verbose                # Run with verbose output"
      echo "  $0 --timing                 # Show test timing"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Build bats command
BATS_CMD="bats"

if [[ -n "$FILTER" ]]; then
  BATS_CMD="$BATS_CMD --filter \"$FILTER\""
  echo -e "${YELLOW}📝 Running tests matching: $FILTER${NC}"
  echo ""
fi

if [[ $TIMING -eq 1 ]]; then
  BATS_CMD="$BATS_CMD --timing"
fi

if [[ $TAP -eq 1 ]]; then
  BATS_CMD="$BATS_CMD --tap"
fi

if [[ $VERBOSE -eq 1 ]]; then
  BATS_CMD="$BATS_CMD --trace"
fi

BATS_CMD="$BATS_CMD \"$SCRIPT_DIR/setver.bats\""

# Run tests
echo "🚀 Running tests..."
echo ""

# Change to project root to ensure correct paths
cd "$PROJECT_ROOT"

# Execute
eval $BATS_CMD
TEST_RESULT=$?

echo ""

# Report results
if [[ $TEST_RESULT -eq 0 ]]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
else
  echo -e "${RED}❌ Some tests failed${NC}"
fi

exit $TEST_RESULT
