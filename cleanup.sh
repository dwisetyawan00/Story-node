#!/bin/bash

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Warning: This will completely remove your Story node installation${NC}"
echo -e "${RED}This includes all data, configurations, and keys!${NC}"
read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${BLUE}Operation cancelled${NC}"
    exit 0
fi

echo -e "${BLUE}Stopping Story services...${NC}"
sudo systemctl stop story-geth
sudo systemctl stop story
sudo systemctl disable story-geth
sudo systemctl disable story

echo -e "${BLUE}Removing service files...${NC}"
sudo rm -f /etc/systemd/system/story-geth.service
sudo rm -f /etc/systemd/system/story.service
sudo systemctl daemon-reload

echo -e "${BLUE}Removing Story directories and files...${NC}"
rm -rf ~/.story
rm -rf ~/go/bin/story
rm -rf ~/go/bin/story-geth
rm -f ~/node_info.txt

echo -e "${BLUE}Cleaning up any remaining processes...${NC}"
killall -9 story 2>/dev/null
killall -9 story-geth 2>/dev/null

# Optional: Remove Go installation
read -p "Do you want to remove Go installation as well? (y/N): " remove_go
if [[ "$remove_go" == "y" || "$remove_go" == "Y" ]]; then
    echo -e "${BLUE}Removing Go installation...${NC}"
    sudo rm -rf /usr/local/go
    # Remove Go path from .bash_profile
    sed -i '/\/usr\/local\/go\/bin/d' ~/.bash_profile
    sed -i '/\$HOME\/go\/bin/d' ~/.bash_profile
fi

echo -e "${GREEN}Cleanup completed! You can now perform a fresh installation${NC}"
echo -e "${YELLOW}Note: If you want to keep your validator keys, make sure you have backed them up before installing again${NC}"
