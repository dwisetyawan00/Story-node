#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Version variables
GO_VERSION="1.22.0"
STORY_GETH_VERSION="v0.10.0"
STORY_CLIENT_VERSION="v0.12.0"

# Function to display the logo
print_logo() {
    echo -e '\e[40m\e[95m'
    echo -e '                                                                     '
    echo -e '     █████╗ ██╗   ██╗ █████╗ ██╗  ██╗                              '
    echo -e '    ██╔══██╗██║   ██║██╔══██╗██║  ██║                              '
    echo -e '    ███████║██║   ██║███████║███████║                              '
    echo -e '    ██╔══██║██║   ██║██╔══██║██╔══██║                              '
    echo -e '    ██║  ██║╚██████╔╝██║  ██║██║  ██║                              '
    echo -e '    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝                              '
    echo -e '                                                                     '
    echo -e '       Community ahh.. ahh.. ahh..                                   '
    echo -e '                                                                     '
    echo -e '\e[0m'
}

# Function to check system requirements
check_system() {
    echo -e "${BLUE}Checking system requirements...${NC}"
    
    # Check CPU cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 4 ]; then
        echo -e "${YELLOW}Warning: Recommended minimum 4 CPU cores, found $cpu_cores${NC}"
    fi
    
    # Check RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 8 ]; then
        echo -e "${YELLOW}Warning: Recommended minimum 8GB RAM, found ${total_ram}GB${NC}"
    fi
    
    # Check disk space
    free_disk=$(df -h / | awk '/^\//{print $4}' | sed 's/G//')
    if [ "${free_disk%.*}" -lt 100 ]; then
        echo -e "${YELLOW}Warning: Recommended minimum 100GB free disk space${NC}"
    fi
}

# Function to install dependencies
install_dependencies() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 pv chrony -y
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install dependencies${NC}"
        exit 1
    fi
}

# Function to install Go
install_go() {
    echo -e "${BLUE}Installing Go ${GO_VERSION}...${NC}"
    
    # Check if Go is already installed
    if command -v go &> /dev/null; then
        current_go_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$current_go_version" = "$GO_VERSION" ]; then
            echo -e "${GREEN}Go ${GO_VERSION} is already installed${NC}"
            return
        fi
    fi
    
    cd $HOME
    wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Update PATH only if it's not already set
    if ! grep -q "/usr/local/go/bin" ~/.bash_profile; then
        echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bash_profile
    fi
    source ~/.bash_profile
    
    # Verify installation
    if ! command -v go &> /dev/null; then
        echo -e "${RED}Failed to install Go${NC}"
        exit 1
    fi
}

# Function to install binaries
install_binaries() {
    echo -e "${BLUE}Installing Story-Geth and Story Client...${NC}"
    
    # Create necessary directories
    mkdir -p $HOME/go/bin
    
    # Story-Geth
    cd $HOME
    wget "https://github.com/piplabs/story-geth/releases/download/${STORY_GETH_VERSION}/geth-linux-amd64"
    chmod +x geth-linux-amd64
    mv $HOME/geth-linux-amd64 $HOME/go/bin/story-geth
    
    # Story Client
    wget "https://github.com/piplabs/story/releases/download/${STORY_CLIENT_VERSION}/story-linux-amd64"
    chmod +x story-linux-amd64
    mv $HOME/story-linux-amd64 $HOME/go/bin/story
    
    source ~/.bash_profile
    
    # Verify installations
    if ! command -v story-geth &> /dev/null || ! command -v story &> /dev/null; then
        echo -e "${RED}Failed to install binaries${NC}"
        exit 1
    fi
}

# Function to initialize node
initialize_node() {
    local moniker=$1
    echo -e "${BLUE}Initializing node with moniker: $moniker${NC}"
    story init --network odyssey --moniker "$moniker"
    
    # Backup priv_validator_key.json
    cp $HOME/.story/story/config/priv_validator_key.json $HOME/.story/priv_validator_key.json.backup
    
    # Configure peers
    configure_peers
    
    # Save node info
    save_node_info "$moniker"
}

# Function to configure peers
configure_peers() {
    echo -e "${BLUE}Configuring peers...${NC}"
    PEERS=$(curl -sS https://story-cosmos-rpc.spidernode.net/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)
    if [ ! -z "$PEERS" ]; then
        sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml
        echo -e "${GREEN}Peers configured successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Could not fetch peers${NC}"
    fi
}

# Function to create service files
create_service_files() {
    echo -e "${BLUE}Creating service files...${NC}"
    
    # Story-geth service
    sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story-geth --odyssey --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    # Story Client Service
    sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
}

# Function to start services
start_services() {
    echo -e "${BLUE}Starting services...${NC}"
    sudo systemctl daemon-reload
    
    echo -e "${BLUE}Starting Story-Geth...${NC}"
    sudo systemctl enable story-geth
    sudo systemctl start story-geth
    sleep 5
    
    echo -e "${BLUE}Starting Story Client...${NC}"
    sudo systemctl enable story
    sudo systemctl start story
    sleep 5
    
    # Check service status
    if ! systemctl is-active --quiet story-geth; then
        echo -e "${RED}Story-Geth service failed to start${NC}"
        sudo journalctl -u story-geth -n 50 --no-pager
    fi
    
    if ! systemctl is-active --quiet story; then
        echo -e "${RED}Story service failed to start${NC}"
        sudo journalctl -u story -n 50 --no-pager
    fi
}

# Function to apply snapshot
apply_snapshot() {
    echo -e "${BLUE}Applying snapshot...${NC}"
    
    # Create backup of priv_validator_state.json if exists
    if [ -f "$HOME/.story/story/data/priv_validator_state.json" ]; then
        cp $HOME/.story/story/data/priv_validator_state.json $HOME/.story/priv_validator_state.json.backup
    fi
    
    # Stop services if they're running
    sudo systemctl stop story
    sudo systemctl stop story-geth
    
    # Download snapshots
    cd $HOME
    echo -e "${GREEN}Downloading Geth snapshot...${NC}"
    aria2c -x 16 -s 16 https://snapshot.spidernode.net/Geth_snapshot.lz4
    
    echo -e "${GREEN}Downloading Story snapshot...${NC}"
    aria2c -x 16 -s 16 https://snapshot.spidernode.net/Story_snapshot.lz4
    
    # Remove old data
    rm -rf ~/.story/story/data
    rm -rf ~/.story/geth/odyssey/geth/chaindata
    
    # Extract snapshots with progress indicator
    sudo mkdir -p /root/.story/story/data
    echo -e "${GREEN}Extracting Story snapshot...${NC}"
    echo -e "${YELLOW}This may take a while. Please wait...${NC}"
    lz4 -d Story_snapshot.lz4 | pv -pterb | sudo tar x -C /root/.story/story/ 2>/dev/null
    echo -e "${GREEN}Story snapshot extraction completed!${NC}"
    
    sudo mkdir -p /root/.story/geth/odyssey/geth/chaindata
    echo -e "${GREEN}Extracting Geth snapshot...${NC}"
    echo -e "${YELLOW}This may take a while. Please wait...${NC}"
    lz4 -d Geth_snapshot.lz4 | pv -pterb | sudo tar x -C /root/.story/geth/odyssey/geth/ 2>/dev/null
    echo -e "${GREEN}Geth snapshot extraction completed!${NC}"
    
    # Clean up snapshot files
    rm -f Story_snapshot.lz4 Geth_snapshot.lz4
    
    # Restore priv_validator_state.json if backup exists
    if [ -f "$HOME/.story/priv_validator_state.json.backup" ]; then
        mv $HOME/.story/priv_validator_state.json.backup $HOME/.story/story/data/priv_validator_state.json
    fi
    
    # Restart services
    echo -e "${GREEN}Starting services...${NC}"
    sudo systemctl start story-geth
    sudo systemctl start story
}

# Function to save node info
save_node_info() {
    local node_name=$1
    local info_file="$HOME/.story/node_info.txt"
    
    echo -e "${BLUE}Saving node information...${NC}"
    
    # Create node info file
    cat > "$info_file" <<EOF
==============================================
Story Node Information
==============================================
Installation Date: $(date)
Node Name: $node_name
EOF

    # Add validator key info
    echo -e "\n=== Validator Keys ===" >> "$info_file"
    echo "Validator Key Backup: $HOME/.story/priv_validator_key.json.backup" >> "$info_file"
    
    # Export and save validator info
    echo -e "\n=== Validator Export Info ===" >> "$info_file"
    story validator export >> "$info_file" 2>&1
    
    # Export and save EVM key
    echo -e "\n=== EVM Key Info ===" >> "$info_file"
    story validator export --export-evm-key >> "$info_file" 2>&1
    
    # Save important paths
    echo -e "\n=== Important Paths ===" >> "$info_file"
    echo "Config Directory: $HOME/.story/story/config/" >> "$info_file"
    echo "Data Directory: $HOME/.story/story/data/" >> "$info_file"
    echo "Geth Data Directory: $HOME/.story/geth/odyssey/geth/chaindata" >> "$info_file"
    
    # Set secure permissions
    chmod 600 "$info_file"
    
    echo -e "${GREEN}Node information saved to: $info_file${NC}"
    echo -e "${YELLOW}Please backup this file securely!${NC}"
}

# Function to show saved node info
show_saved_node_info() {
    local info_file="$HOME/.story/node_info.txt"
    
    if [ -f "$info_file" ]; then
        echo -e "${BLUE}=== Saved Node Information ===${NC}"
        cat "$info_file"
    else
        echo -e "${RED}No saved node information found${NC}"
    fi
}

# Function to check sync status
check_sync_status() {
    echo -e "${BLUE}Checking sync status...${NC}"
    curl -s localhost:26657/status | jq '.result.sync_info'
}

# Function to create validator
create_validator() {
    echo -e "${PURPLE}=== Create Validator ===${NC}"
    echo -e "1) Restore old key from Iliad network"
    echo -e "2) Create new validator"
    read -p "Choose option (1-2): " validator_option
    
    case $validator_option in
        1)
            echo -e "${BLUE}Please paste your old priv_validator_key.json content:${NC}"
            sudo nano ~/.story/story/config/priv_validator_key.json
            story validator export
            story validator export --export-evm-key
            # Update saved info
            save_node_info "$(story query validator self | jq -r '.moniker')"
            ;;
        2)
            story validator export
            story validator export --export-evm-key
            read -p "Enter your node name: " node_name
            read -p "Enter your private key: " private_key
            story validator create --stake 1024000000000000000000 --moniker "$node_name" --private-key "$private_key"
            # Update saved info
            save_node_info "$node_name"
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
}

# Function to show node info
show_node_info() {
    echo -e "${BLUE}=== Current Node Information ===${NC}"
    echo -e "Story-Geth Version: $(story-geth version)"
    echo -e "Story Client Version: $(story version)"
    echo -e "Go Version: $(go version)"
    echo -e "\nSync Status:"
    check_sync_status
    echo -e "\nServices Status:"
    echo -e "Story-Geth: $(systemctl is-active story-geth)"
    echo -e "Story Client: $(systemctl is-active story)"
    
    echo -e "\n"
    show_saved_node_info
}

# Main menu
while true; do
    clear
    print_logo
    echo -e "${PURPLE}=== Story Node Installation Menu ===${NC}"
    echo -e "1) Install Story Node"
    echo -e "2) Install Snapshot saja"
    echo -e "3) Create Validator (Butuh sync dan fee)"
    echo -e "4) Show Node Info"
    echo -e "5) Backup Node Info"
    echo -e "6) Exit"
    
    read -p "Choose an option (1-6): " choice
    
    case $choice in
        1)
            read -p "Do you want to install with snapshot? (y/n): " use_snapshot
            read -p "Enter your node name: " node_name
            
            check_system
            install_dependencies
            install_go
            install_binaries
            initialize_node "$node_name"
            create_service_files
            
            if [[ "$use_snapshot" == "y" ]]; then
                apply_snapshot
            fi
            
            start_services
            show_node_info
            echo -e "${GREEN}Node installation completed!${NC}"
            ;;
        2)
            apply_snapshot
            show_node_info
            echo -e "${GREEN}Snapshot application completed!${NC}"
            ;;
        3)
            create_validator
            ;;
        4)
            show_node_info
            ;;
        5)
            save_node_info "$(story query validator self | jq -r '.moniker')"
            ;;
        6)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            ;;
    esac
    
    read -p "Press Enter to continue..."
done
