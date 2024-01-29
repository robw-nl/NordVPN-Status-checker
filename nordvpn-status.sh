#!/bin/bash

# This scripts checks the status of your NordVPn connection and,
# additionally, also checks your internet connection. This does
# require that the (official repos) package 'speedtest-cli' is installed

# Initialize variables
required_command=""
vpn_status=""
public_ip=""
waiting_dialog_pid=""
speedtest_result=""
notification_command=""

# Function to check for dependencies
check_dependencies() {
    for required_command in nordvpn curl speedtest-cli; do
        if ! command -v $required_command &> /dev/null; then
            printf "Error: %s is not installed.\n" "$required_command"
            exit 1
        fi
    done

    # Check for notification command
    if command -v notify-send &> /dev/null; then
        notification_command="notify-send -i"
    elif command -v kdialog &> /dev/null; then
        notification_command="kdialog --title"
    else
        printf "Error: Neither notify-send nor kdialog is installed.\n"
        exit 1
    fi
}

# Function to send notification
send_notification() {
    if [ "$notification_command" = "notify-send -i" ]; then
        notify-send -i "$1" -t 5000 "$2" "$3"
    elif [ "$notification_command" = "kdialog --title" ]; then
        kdialog --title "$2" --passivepopup "$3" 5
    fi
}

# Function to check NordVPN connection status
check_vpn_status() {
    vpn_status=$(nordvpn status | grep "Status:" | cut -d ":" -f2 | xargs) || { send_notification dialog-error "Error getting NordVPN status"; exit 1; }
}

# Function to get public IP address
get_public_ip() {
    public_ip=$(curl -s https://ipinfo.io/ip) || { send_notification dialog-error "Error getting public IP"; exit 1; }
}

# Function to run speedtest
run_speedtest() {
    # Display a kdialog message box with the 'waiting' message and current IP address
    kdialog --title "Speedtest" --msgbox "Waiting for speedtest...\nPublic IP is: $public_ip" &
    
    # Save the PID of the kdialog process
    waiting_dialog_pid=$!

    # Run the speedtest and save the output to the variable
    speedtest_result=$(speedtest-cli --simple) || { send_notification dialog-error "Error running speedtest"; kill "$waiting_dialog_pid"; exit 1; }

    # Kill the kdialog message box
    kill "$waiting_dialog_pid"

    # Display a new kdialog passive popup with the speedtest output
    kdialog --title "Speedtest" --passivepopup "$speedtest_result" 6
}

# Main script
check_dependencies
check_vpn_status

# Check if connection is connected
if [[ "$vpn_status" != "Connected" ]]; then
    # Connection is dropped, display warning
    send_notification dialog-warning "NordVPN Status" "Your NordVPN connection has been dropped. Please reconnect to maintain your privacy.\nPublic IP: $public_ip"
else
    # Connection is active, display confirmation
    get_public_ip
    run_speedtest
fi
