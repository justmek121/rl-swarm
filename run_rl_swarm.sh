#!/bin/bash

ROOT=$PWD

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export TUNNEL_TYPE=""
export CPU_ONLY=true  # Luôn chạy ở chế độ CPU

DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v apt &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] Debian/Ubuntu detected. Installing build-essential, gcc, g++...${NC}"
    sudo apt update > /dev/null 2>&1
    sudo apt install -y build-essential gcc g++ > /dev/null 2>&1

  elif command -v yum &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] RHEL/CentOS detected. Installing Development Tools...${NC}"
    sudo yum groupinstall -y "Development Tools" > /dev/null 2>&1
    sudo yum install -y gcc gcc-c++ > /dev/null 2>&1

  elif command -v pacman &>/dev/null; then
    echo -e "${CYAN}${BOLD}[✓] Arch Linux detected. Installing base-devel...${NC}"
    sudo pacman -Sy --noconfirm base-devel gcc > /dev/null 2>&1

  else
    echo -e "${RED}${BOLD}[✗] Linux detected but unsupported package manager.${NC}"
    exit 1
  fi

elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${CYAN}${BOLD}[✓] macOS detected. Installing Xcode Command Line Tools...${NC}"
  xcode-select --install > /dev/null 2>&1

else
  echo -e "${RED}${BOLD}[✗] Unsupported OS: $OSTYPE${NC}"
  exit 1
fi

if command -v gcc &>/dev/null; then
  export CC=$(command -v gcc)
  echo -e "${CYAN}${BOLD}[✓] Exported CC=$CC${NC}"
else
  echo -e "${RED}${BOLD}[✗] gcc not found. Please install it manually.${NC}"
fi

# Bỏ qua toàn bộ phần kiểm tra CUDA/GPU vì chạy CPU-only
echo -e "\n${YELLOW}${BOLD}[✓] Running in CPU-only mode${NC}"

USE_BIG_SWARM=false

if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi

PARAM_B= 0.5

cleanup() {
    echo -e "${YELLOW}${BOLD}[✓] Shutting down processes...${NC}"
    kill $SERVER_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT

echo -e "\033[38;5;45m\033[1m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███ 
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████ 
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██ 
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██ 
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██ 
    
          
           JOIN THE COMMUNITY : https://t.me/Nexgenexplore
                                                                
EOF
echo -e "\033[0m"

sleep 2

if [ -f "modal-login/temp-data/userData.json" ]; then
    cd modal-login

    echo -e "\n${CYAN}${BOLD}[✓] Installing dependencies with npm. This may take a few minutes, depending on your internet speed...${NC}"
    npm install --legacy-peer-deps
    
    echo -e "\n${CYAN}${BOLD}[✓] Starting the development server...${NC}"
    if ! command -v ss &>/dev/null; then
      echo -e "${YELLOW}[!] 'ss' not found. Attempting to install 'iproute2'...${NC}"
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y iproute2
      elif command -v yum &>/dev/null; then
        sudo yum install -y iproute
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy iproute2
      else
        echo -e "${RED}[✗] Could not install 'ss'. Package manager not found.${NC}"
        exit 1
      fi
    fi
    
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo -e "${YELLOW}[!] Port 3000 is in use. Killing process: $PID${NC}"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=30  
    
    for ((i = 0; i < MAX_WAIT; i++)); do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}${BOLD}[✓] Server is running successfully on port $PORT.${NC}"
                break
            fi
        fi
        sleep 1
    done
    
    if [ $i -eq $MAX_WAIT ]; then
        echo -e "${RED}${BOLD}[✗] Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    
    # Open localhost in the default browser
    echo -e "\n${CYAN}${BOLD}[✓] Opening http://localhost:$PORT in your default browser...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open http://localhost:$PORT 2>/dev/null
    else
        xdg-open http://localhost:$PORT 2>/dev/null
    fi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${BOLD}[✓] Successfully opened http://localhost:$PORT in your default browser.${NC}"
    else
        echo -e "${RED}${BOLD}[✗] Failed to open http://localhost:$PORT. Please open it manually in your browser.${NC}"
    fi

    cd ..

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "\n${CYAN}${BOLD}[✓] ORG_ID has been set to: ${BOLD}$ORG_ID\n${NC}"
else
    cd modal-login

    echo -e "\n${CYAN}${BOLD}[✓] Installing dependencies with npm. This may take a few minutes, depending on your internet speed...${NC}"
    npm install --legacy-peer-deps
    
    echo -e "\n${CYAN}${BOLD}[✓] Starting the development server...${NC}"
    if ! command -v ss &>/dev/null; then
      echo -e "${YELLOW}[!] 'ss' not found. Attempting to install 'iproute2'...${NC}"
      if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y iproute2
      elif command -v yum &>/dev/null; then
        sudo yum install -y iproute
      elif command -v pacman &>/dev/null; then
        sudo pacman -Sy iproute2
      else
        echo -e "${RED}[✗] Could not install 'ss'. Package manager not found.${NC}"
        exit 1
      fi
    fi
    
    PORT_LINE=$(ss -ltnp | grep ":3000 ")
    if [ -n "$PORT_LINE" ]; then
      PID=$(echo "$PORT_LINE" | grep -oP 'pid=\K[0-9]+')
      if [ -n "$PID" ]; then
        echo -e "${YELLOW}[!] Port 3000 is in use. Killing process: $PID${NC}"
        kill -9 $PID
        sleep 2
      fi
    fi
    
    npm run dev > server.log 2>&1 &
    SERVER_PID=$!
    MAX_WAIT=30  
    
    for ((i = 0; i < MAX_WAIT; i++)); do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}${BOLD}[✓] Server is running successfully on port $PORT.${NC}"
                break
            fi
        fi
        sleep 1
    done
    
    if [ $i -eq $MAX_WAIT ]; then
        echo -e "${RED}${BOLD}[✗] Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi

    # Open localhost in the default browser
    echo -e "\n${CYAN}${BOLD}[✓] Opening http://localhost:$PORT in your default browser...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open http://localhost:$PORT 2>/dev/null
    else
        xdg-open http://localhost:$PORT 2>/dev/null
    fi
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${BOLD}[✓] Successfully opened http://localhost:$PORT in your default browser.${NC}"
    else
        echo -e "${RED}${BOLD}[✗] Failed to open http://localhost:$PORT. Please open it manually in your browser.${NC}"
    fi

    cd ..

    echo -e "\n${CYAN}${BOLD}[↻] Waiting for you to complete the login process...${NC}"
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 3
    done
    
    echo -e "${GREEN}${BOLD}[✓] Success! The userData.json file has been created. Proceeding with remaining setups...${NC}"
    rm -f server.log

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo -e "\n${CYAN}${BOLD}[✓] ORG_ID has been set to: $ORG_ID\n${NC}"

    echo -e "${CYAN}${BOLD}[✓] Waiting for API key to become activated...${NC}"
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo -e "${GREEN}${BOLD}[✓] Success! API key is activated! Proceeding...\n${NC}"
            break
        else
            echo "[↻] Waiting for API key to be activated..."
            sleep 5
        fi
    done

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        # Linux version
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi
fi

echo -e "${CYAN}${BOLD}[✓] Setting up Python virtual environment...${NC}"
python3 -m venv .venv && . .venv/bin/activate && \
echo -e "${GREEN}${BOLD}[✓] Python virtual environment set up successfully.${NC}" || \
echo -e "${RED}${BOLD}[✗] Failed to set up virtual environment.${NC}"

# Luôn sử dụng config CPU và cài đặt requirements-cpu.txt
echo -e "${YELLOW}${BOLD}[✓] Using CPU configuration${NC}"
pip install -r "$ROOT"/requirements-cpu.txt
CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
GAME="gsm8k"
echo -e "${CYAN}${BOLD}[✓] Config file : ${BOLD}$CONFIG_PATH\n${NC}"

HUGGINGFACE_ACCESS_TOKEN="None"

echo -e "\n${GREEN}${BOLD}[✓] Good luck in the swarm! Your training session is about to begin.\n${NC}"
[ "$(uname)" = "Darwin" ] && sed -i '' -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)") || sed -i -E 's/(startup_timeout: *float *= *)[0-9.]+/\1120/' $(python3 -c "import hivemind.p2p.p2p_daemon as m; print(m.__file__)")
[ "$(uname)" = "Darwin" ] && sed -i '' -e '/bootstrap_timeout: Optional\[float\] = None/s//bootstrap_timeout: float = 120/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)') || sed -i -e '/bootstrap_timeout: Optional\[float\] = None/s//bootstrap_timeout: float = 120/' $(python3 -c 'import hivemind.dht.node as m; print(m.__file__)')
if [ -n "$ORG_ID" ]; then
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --contract_address "$SWARM_CONTRACT" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
else
    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS" \
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH" \
        --game "$GAME"
fi

wait
