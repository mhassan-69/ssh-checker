#!/bin/bash
# Function to print the section header
print_header() {
    echo
    echo "==============================="
    echo "$1"
    echo "==============================="
    echo
}

# Function to print status with color
print_status() {
    if [ "$1" -eq 0 ]; then
        echo -e "\e[32m$2\e[0m"  # Green for success
    else
        echo -e "\e[31m$2\e[0m"  # Red for failure
    fi
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_status 1 "Please run as root or with sudo privileges"
    exit 1
fi

# Initialize a variable to track overall script success
overall_success=0

# 1. Check if SSH is installed
print_header "Checking if SSH is installed"
if command -v ssh >/dev/null 2>&1; then
    print_status 0 "SSH is installed"
else
    print_status 1 "SSH is not installed. Install it using 'sudo yum install openssh-server'"
    overall_success=1
fi

# 2. Check if SSH service is running
print_header "Checking if SSH service is running"
if systemctl is-active --quiet sshd; then
    print_status 0 "SSHD is running"
else
    echo "SSHD is not running. Starting SSHD service..."
    if systemctl start sshd && systemctl is-active --quiet sshd; then
        print_status 0 "SSHD started successfully"
    else
        print_status 1 "Failed to start SSHD. Check the service logs using 'sudo journalctl -u sshd'"
        overall_success=1
    fi
fi

# 3. Check SSH port (default is 22)
print_header "Checking if SSH port is open"
PORT=22
if ss -tuln | grep ":$PORT" >/dev/null 2>&1; then
    print_status 0 "SSH port $PORT is open"
else
    print_status 1 "SSH port $PORT is closed. Check your SSHD configuration and firewall rules."
    overall_success=1
fi

# 4. Check firewall rules
print_header "Checking firewall rules"
if firewall-cmd --state >/dev/null 2>&1; then
    FIREWALLD_ACTIVE=$(firewall-cmd --state)
    if [ "$FIREWALLD_ACTIVE" = "running" ]; then
        if firewall-cmd --list-all | grep "ports:.*$PORT/tcp" >/dev/null 2>&1; then
            print_status 0 "Firewall is allowing SSH on port $PORT"
        else
            print_status 1 "Firewall is not allowing SSH on port $PORT. Run 'sudo firewall-cmd --permanent --add-port=$PORT/tcp' and 'sudo firewall-cmd --reload'"
            overall_success=1
        fi
    else
        print_status 1 "FirewallD is not running."
        overall_success=1
    fi
else
    print_status 1 "FirewallD is not installed."
    if command -v iptables >/dev/null 2>&1; then
        if sudo iptables -L -n | grep ":$PORT" >/dev/null 2>&1; then
            print_status 0 "iptables is allowing SSH on port $PORT"
        else
            print_status 1 "iptables is not allowing SSH on port $PORT. Run 'sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT'"
            overall_success=1
        fi
    else
        print_status 1 "iptables is also not installed."
        overall_success=1
    fi
fi

# 5. Check SSH config file for errors
print_header "Checking SSH config file"
CONFIG_FILE="/etc/ssh/sshd_config"
if sshd -t -f "$CONFIG_FILE"; then
    print_status 0 "No errors found in SSH configuration file"
else
    print_status 1 "Errors found in SSH configuration file. Check $CONFIG_FILE for syntax issues"
    overall_success=1
fi

# 6. Check for correct permissions on SSH files
print_header "Checking permissions on SSH files"
SSH_DIR="$HOME/.ssh"
if [ -d "$SSH_DIR" ]; then
    if [ $(stat -c "%a" "$SSH_DIR") -eq 700 ]; then
        print_status 0 "Correct permissions on .ssh directory"
    else
        print_status 1 "Incorrect permissions on .ssh directory. Run 'chmod 700 $SSH_DIR'"
        overall_success=1
    fi
    if [ -f "$SSH_DIR/authorized_keys" ]; then
        if [ $(stat -c "%a" "$SSH_DIR/authorized_keys") -eq 600 ]; then
            print_status 0 "Correct permissions on authorized_keys file"
        else
            print_status 1 "Incorrect permissions on authorized_keys file. Run 'chmod 600 $SSH_DIR/authorized_keys'"
            overall_success=1
        fi
    else
        print_status 1 "authorized_keys file not found. Ensure you have the correct public key added"
        overall_success=1
    fi
else
    print_status 1 ".ssh directory not found. Ensure it exists and has the correct permissions"
    overall_success=1
fi

# 7. Check for SSH host keys in /etc/ssh
print_header "Checking SSH host keys"
HOST_KEYS=("ssh_host_rsa_key" "ssh_host_ecdsa_key" "ssh_host_ed25519_key")
MISSING_KEYS=0
for key in "${HOST_KEYS[@]}"; do
    if [ -f "/etc/ssh/${key}" ]; then
        PERMISSIONS=$(stat -c "%a" "/etc/ssh/${key}")
        OWNER=$(stat -c "%U" "/etc/ssh/${key}")
        if [[ "$PERMISSIONS" -eq 600 && "$OWNER" == "root" ]]; then
            print_status 0 "Host key /etc/ssh/${key} is present with correct permissions and owner."
        else
            print_status 1 "Host key /etc/ssh/${key} has incorrect permissions or owner."
            print_status 1 "Ensure it has 600 permissions and is owned by root."
            overall_success=1
        fi
    else
        print_status 1 "Host key /etc/ssh/${key} is missing."
        print_status 1 "Generating new host key /etc/ssh/${key}..."
        ssh-keygen -t $(echo $key | sed 's/ssh_host_\(.*\)_key/\1/') -f "/etc/ssh/${key}" -N ""
        if [ -f "/etc/ssh/${key}" ]; then
            print_status 0 "New host key /etc/ssh/${key} generated successfully."
			if systemctl start sshd && systemctl is-active --quiet sshd; then
				print_status 0 "SSHD started successfully"
			else
				print_status 1 "Failed to start SSHD. Check the service logs using 'sudo journalctl -u sshd'"
            overall_success=1
        fi
        else
            print_status 1 "Failed to generate host key /etc/ssh/${key}. Check logs for more details."
            overall_success=1
        fi
    fi
done

# 8. Check for SSH-related errors on Amazon Linux
print_header "Checking for SSH-related errors on Amazon Linux"
if [ -f /var/log/messages ]; then
    grep -i "error\|fail\|warning" /var/log/messages | grep -i ssh -B 2 -A 2
else
    echo -e "\e[33m/var/log/messages does not exist. Checking journalctl instead...\e[0m"
    journalctl -u sshd | grep -i "error\|fail\|warning" -B 2 -A 2
fi

# Final message
print_header "Basic checks completed"
if [ "$overall_success" -eq 0 ]; then
    print_status 0 "All checks passed successfully. If you need additional assistance, please contact your Systems Administrator or AWS Support"
else
    print_status 1 "Some checks failed. If you need additional assistance, please contact your Systems Administrator or AWS Support."
fi
