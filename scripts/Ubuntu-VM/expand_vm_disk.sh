#!/bin/bash

# VM Disk Expansion Script
# This script automates the process of expanding a VM's disk space
# WARNING: This script modifies disk partitions - use with caution!

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check if device exists
check_device() {
    local device=$1
    if [[ ! -b "$device" ]]; then
        print_error "Device $device does not exist"
        exit 1
    fi
}

# Function to get confirmation
get_confirmation() {
    local message=$1
    echo -e "${YELLOW}$message${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled by user"
        exit 0
    fi
}

# Function to check for free space
check_free_space() {
    local disk=$1
    print_status "Checking for available free space on $disk..."

    # Get free space information using parted
    local free_space=$(parted "$disk" print free 2>/dev/null | grep "Free Space" | tail -1 | awk '{print $3}')

    if [[ -z "$free_space" ]]; then
        # Alternative method using fdisk to check if partition can be extended
        local disk_size=$(fdisk -l "$disk" 2>/dev/null | grep "Disk $disk:" | awk '{print $3}')
        local last_partition_end=$(fdisk -l "$disk" 2>/dev/null | grep "${disk}3" | awk '{print $3}')

        if [[ -n "$disk_size" && -n "$last_partition_end" ]]; then
            # Convert to sectors for comparison (rough check)
            print_status "Disk size: ${disk_size} GB, Last partition ends at sector: $last_partition_end"
        fi

        # Try to get free space with a different approach
        free_space=$(parted "$disk" unit GB print free 2>/dev/null | grep -E "^ +[0-9]+\.[0-9]+GB +[0-9]+\.[0-9]+GB +[0-9]+\.[0-9]+GB +Free Space" | tail -1 | awk '{print $3}')
    fi

    if [[ -n "$free_space" ]]; then
        # Remove 'GB' suffix and convert to number for comparison
        local free_space_num=$(echo "$free_space" | sed 's/[^0-9.]//g')

        # Check if free space is less than 0.1 GB (100MB)
        if (( $(echo "$free_space_num < 0.1" | bc -l 2>/dev/null || echo "0") )); then
            print_warning "No significant free space available (${free_space})"
            print_warning "Current disk layout:"
            parted "$disk" print free 2>/dev/null || true
            echo
            print_error "Cannot proceed - no free space to expand into"
            exit 0
        else
            print_status "Free space available: $free_space"
            return 0
        fi
    else
        # If we can't determine free space, show warning but allow user to decide
        print_warning "Could not automatically determine free space"
        print_warning "Please verify manually that there is free space available:"
        parted "$disk" print free 2>/dev/null || fdisk -l "$disk"
        echo
        get_confirmation "Do you want to continue anyway? Make sure you have verified free space exists."
    fi
}

# Main function
main() {
    print_status "Starting VM disk expansion process..."

    # Configuration
    DISK="/dev/sda"
    PARTITION="/dev/sda3"
    PARTITION_NUM=3
    VG_NAME="ubuntu-vg"
    LV_NAME="ubuntu-lv"
    LV_PATH="/dev/$VG_NAME/$LV_NAME"
    MAPPER_PATH="/dev/mapper/ubuntu--vg-ubuntu--lv"

    # Check if running as root
    check_root

    # Check if devices exist
    check_device "$DISK"
    check_device "$PARTITION"

    # Show current disk usage
    print_status "Current disk usage:"
    df -h "$MAPPER_PATH" || true
    echo

    # Show current partition layout
    print_status "Current partition layout:"
    parted "$DISK" print || true
    echo

    # Check for free space before proceeding
    check_free_space "$DISK"

    # Get confirmation before proceeding
    get_confirmation "This will resize partition $PARTITION and extend the logical volume."

    # Step 1: Resize the partition to use all available space
    print_status "Step 1: Resizing partition $PARTITION..."

    # Use parted to resize the partition to 100%
    parted "$DISK" resizepart "$PARTITION_NUM" 100% || {
        print_error "Failed to resize partition"
        exit 1
    }

    # Inform kernel of partition table changes
    partprobe "$DISK" || {
        print_warning "partprobe failed, trying alternative method..."
        echo 1 > /sys/class/block/sda/device/rescan || true
    }

    print_status "Partition resized successfully"

    # Step 2: Resize the physical volume
    print_status "Step 2: Resizing physical volume $PARTITION..."

    pvresize "$PARTITION" || {
        print_error "Failed to resize physical volume"
        exit 1
    }

    print_status "Physical volume resized successfully"

    # Step 3: Extend the logical volume
    print_status "Step 3: Extending logical volume $LV_PATH..."

    lvextend -l+100%FREE "$LV_PATH" || {
        print_error "Failed to extend logical volume"
        exit 1
    }

    print_status "Logical volume extended successfully"

    # Step 4: Resize the filesystem
    print_status "Step 4: Resizing filesystem $MAPPER_PATH..."

    resize2fs "$MAPPER_PATH" || {
        print_error "Failed to resize filesystem"
        exit 1
    }

    print_status "Filesystem resized successfully"

    # Show final disk usage
    echo
    print_status "Final disk usage:"
    df -h "$MAPPER_PATH"

    echo
    print_status "VM disk expansion completed successfully!"
    print_warning "It's recommended to reboot the system to ensure all changes are properly recognized."
}

# Run main function
main "$@"