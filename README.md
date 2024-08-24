# SSH Checker

This script performs a series of checks to ensure that SSH is properly configured and running on your system. 

## Main Checks

1. **Check if SSH is installed.**
2. **Check if SSH service is running.**
3. **Check if SSH port (22) is open.**
4. **Check firewall rules to ensure SSH traffic is allowed.**
5. **Check SSH configuration file for errors.**
6. **Check permissions on SSH files (.ssh directory and authorized_keys file).**
7. **Check SSH host keys for presence, permissions, and ownership; generate missing keys if needed.**
8. **Check for SSH-related errors in \`/var/log/messages\` or use \`journalctl\` if the log file is absent.**

## Usage

1. Clone the repository:

   \`\`\`
   git clone https://github.com/mhassan-69/ssh-checker.git
   \`\`\`

2. Navigate to the directory:

   \`\`\`
   cd ssh-checker
   \`\`\`

3. Make the script executable:

   \`\`\`
   chmod +x ssh-check.sh
   \`\`\`

4. Run the script:

   \`\`\`
   sudo ./ssh-check.sh
   \`\`\`

## Notes

- Ensure you run the script with \`sudo\` or as root to perform all checks.
- Follow the script's suggestions to resolve any issues found.
