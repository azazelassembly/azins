#!/usr/bin/bash

# AZINS 
# v2.0 with DE/WM selection

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art
function show_banner() {
    clear
    echo -e "${BLUE}"
    echo -e "${NC}"
    echo -e "${YELLOW}AZ Installer (AZINS v2.0)${NC}"
    echo -e "${CYAN}With DE/WM Selection${NC}"
    echo "============================="
    echo
}

# Check internet
function check_internet() {
    echo -e "${YELLOW}[!] Checking internet connection...${NC}"
    if ! ping -c 3 archlinux.org &> /dev/null; then
        echo -e "${RED}[ERROR] No internet connection!${NC}"
        echo "Connect to wifi:"
        echo "1) wifi-menu (for legacy)"
        echo "2) iwctl (for newer ISO)"
        exit 1
    fi
    echo -e "${GREEN}[✓] Internet connected.${NC}"
}

# Disk selection
function select_disk() {
    show_banner
    echo -e "${GREEN}Available storage devices:${NC}"
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -v 'rom\|loop\|part'
    echo
    read -p "Enter disk to install to (e.g., sda/nvme0n1): " DISK
    DISK="/dev/$DISK"
    
    if [ ! -b "$DISK" ]; then
        echo -e "${RED}[ERROR] Disk $DISK not found!${NC}"
        exit 1
    fi
}

# Partitioning
function partition_disk() {
    show_banner
    echo -e "${GREEN}Partitioning $DISK:${NC}"
    echo "1) Auto-partition (UEFI/GPT)"
    echo "2) Manual partitioning"
    echo "3) View current layout"
    echo -e "${RED}4) Cancel installation${NC}"
    
    read -p "Select option (1-4): " PART_OPTION
    
    case $PART_OPTION in
        1)
            echo -e "\n${YELLOW}[!] This will ERASE ALL DATA on $DISK!${NC}"
            echo "Proposed layout:"
            echo "- ${DISK}1: 512MB EFI System"
            echo "- ${DISK}2: 4GB Linux swap"
            echo "- ${DISK}3: Remainder for root (ext4)"
            read -p "Continue? (y/N): " CONFIRM
            
            if [[ "$CONFIRM" =~ [yY] ]]; then
                echo -e "\n${YELLOW}[!] Partitioning $DISK...${NC}"
                parted -s "$DISK" mklabel gpt
                parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
                parted -s "$DISK" set 1 esp on
                parted -s "$DISK" mkpart primary linux-swap 513MiB 4609MiB
                parted -s "$DISK" mkpart primary ext4 4609MiB 100%
                
                echo -e "${YELLOW}[!] Formatting...${NC}"
                mkfs.fat -F32 "${DISK}1"
                mkswap "${DISK}2"
                swapon "${DISK}2"
                mkfs.ext4 -F "${DISK}3"
                
                echo -e "${YELLOW}[!] Mounting...${NC}"
                mount "${DISK}3" /mnt
                mkdir -p /mnt/boot/efi
                mount "${DISK}1" /mnt/boot/efi
            else
                echo "Partitioning cancelled."
                exit 0
            fi
            ;;
        2)
            echo -e "\n${GREEN}Current partitions:${NC}"
            lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$DISK"
            echo
            
            read -p "Enter root partition number (e.g., 3): " ROOT_PART
            ROOT_PART="${DISK}${ROOT_PART}"
            
            read -p "Format $ROOT_PART? (y/N): " FORMAT_ROOT
            if [[ "$FORMAT_ROOT" =~ [yY] ]]; then
                echo -e "${YELLOW}[!] Formatting $ROOT_PART...${NC}"
                mkfs.ext4 -F "$ROOT_PART"
            fi
            
            mount "$ROOT_PART" /mnt
            
            read -p "Separate EFI partition? (y/N): " HAS_EFI
            if [[ "$HAS_EFI" =~ [yY] ]]; then
                read -p "Enter EFI partition number (e.g., 1): " EFI_PART
                EFI_PART="${DISK}${EFI_PART}"
                mkdir -p /mnt/boot/efi
                mount "$EFI_PART" /mnt/boot/efi
            fi
            ;;
        3)
            echo -e "\n${GREEN}Current partition table:${NC}"
            fdisk -l "$DISK"
            read -p "Press Enter to continue..."
            partition_disk
            ;;
        4)
            echo -e "${RED}Installation cancelled.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            partition_disk
            ;;
    esac
}

# DE/WM selection
function select_de_wm() {
    show_banner
    echo -e "${GREEN}Desktop Environment/Window Manager Selection${NC}"
    echo "1) GNOME (Desktop)"
    echo "2) KDE Plasma (Desktop)"
    echo "3) XFCE (Lightweight Desktop)"
    echo "4) i3 (Tiling WM)"
    echo "5) Sway (Wayland Tiling WM)"
    echo "6) None (CLI only)"
    echo "7) Custom selection"
    
    read -p "Choose option (1-7): " DE_OPTION
    
    case $DE_OPTION in
        1)
            DE_PACKAGES="gnome gnome-extra gdm"
            DM="gdm"
            ;;
        2)
            DE_PACKAGES="plasma-desktop sddm konsole dolphin"
            DM="sddm"
            ;;
        3)
            DE_PACKAGES="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
            DM="lightdm"
            ;;
        4)
            DE_PACKAGES="i3-wm i3status i3blocks dmenu rofi lightdm lightdm-gtk-greeter"
            DM="lightdm"
            ;;
        5)
            DE_PACKAGES="sway waybar rofi wofi foot lightdm lightdm-gtk-greeter"
            DM="lightdm"
            ;;
        6)
            DE_PACKAGES=""
            DM=""
            ;;
        7)
            echo -e "\n${YELLOW}Enter packages (space separated):${NC}"
            echo "Example: xfce4 xfce4-goodies lightdm"
            read -p "Packages: " DE_PACKAGES
            read -p "Display Manager (leave empty for none): " DM
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            select_de_wm
            ;;
    esac
}

# User configuration
function user_config() {
    show_banner
    echo -e "${GREEN}System Configuration${NC}"
    
    read -p "Enter hostname: " HOSTNAME
    read -p "Enter timezone (e.g., Europe/London): " TIMEZONE
    
    echo -e "\n${GREEN}User Setup${NC}"
    read -p "Enter username: " USERNAME
    read -sp "Enter user password: " USER_PASS
    echo
    read -sp "Enter root password: " ROOT_PASS
    echo
    
    # Base packages
    BASE_PACKAGES="base base-devel linux linux-firmware grub efibootmgr networkmanager sudo nano"
}

# Installation
function install_system() {
    show_banner
    echo -e "${GREEN}Starting installation...${NC}"
    
    # Update mirrors
    echo -e "${YELLOW}[!] Updating mirrors...${NC}"
    reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    
    # Install packages
    echo -e "${YELLOW}[!] Installing system...${NC}"
    pacstrap /mnt $BASE_PACKAGES $DE_PACKAGES
    
    # Generate fstab
    echo -e "${YELLOW}[!] Generating fstab...${NC}"
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Chroot configuration
    echo -e "${YELLOW}[!] Configuring system...${NC}"
    arch-chroot /mnt /bin/bash <<EOF
    # Timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    
    # Localization
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    
    # Network
    echo "$HOSTNAME" > /etc/hostname
    cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT
    
    # Users
    echo "root:$ROOT_PASS" | chpasswd
    useradd -m -G wheel $USERNAME
    echo "$USERNAME:$USER_PASS" | chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    
    # Bootloader
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    
    # Services
    systemctl enable NetworkManager
    
    # Display Manager
    if [ -n "$DM" ]; then
        systemctl enable $DM
    fi
    
    # Additional configurations
    if [[ "$DE_OPTION" == "1" || "$DE_OPTION" == "2" ]]; then
        systemctl enable bluetooth
    fi
EOF
    
    # Complete
    echo -e "\n${GREEN}[✓] Installation complete!${NC}"
    echo -e "You can now reboot with:"
    echo -e "${YELLOW}umount -R /mnt && reboot${NC}"
    echo
    echo -e "${CYAN}After reboot:${NC}"
    echo -e "- Log in as ${YELLOW}$USERNAME${NC}"
    if [ -n "$DM" ]; then
        echo -e "- Your desktop environment should start automatically"
    else
        echo -e "- Start your DE/WM manually"
    fi
}

# Main flow
check_internet
select_disk
partition_disk
user_config
select_de_wm
install_system
