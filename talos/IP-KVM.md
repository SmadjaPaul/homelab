# IP KVM Access Configuration

## Overview

IP KVM (Keyboard, Video, Mouse over IP) provides out-of-band management for the AOOSTAR WTR MAX 8845 server. This allows remote access to the server console even when the operating system is down.

## Hardware Information

- **Device**: [To be configured when hardware is available]
- **IP Address**: [To be configured]
- **Port**: [To be configured - typically 80/443 for web interface, 5900 for VNC]
- **Model**: [To be documented when hardware is available]

## Access Procedure

### Initial Setup (When Hardware Arrives)

1. **Physical Connection**
   - Connect IP KVM device to server (if external device)
   - Connect IP KVM to network
   - Power on IP KVM device

2. **Network Configuration**
   - Access IP KVM web interface (default IP or via DHCP)
   - Configure static IP address on management network
   - Configure network settings (gateway, DNS)

3. **Authentication Setup**
   - Change default credentials
   - Configure user accounts
   - Set up access controls
   - Store credentials securely (password manager, not in Git)

### Accessing IP KVM

1. **Web Interface**
   - Navigate to: `https://[IP-KVM-IP]` or `http://[IP-KVM-IP]`
   - Login with configured credentials
   - Access remote console from web interface

2. **VNC Client (if supported)**
   - Connect to: `[IP-KVM-IP]:5900` (or configured port)
   - Use VNC client with authentication

3. **Serial Console (if available)**
   - Connect via SSH or telnet to serial console port
   - Access server console directly

## Usage Scenarios

### Initial Installation

1. Access IP KVM console
2. Boot from Talos Linux ISO (via IP KVM virtual media or physical USB)
3. Monitor installation process
4. Access BIOS/UEFI settings if needed

### Troubleshooting

1. **Server Not Booting**
   - Access IP KVM console
   - Check boot logs
   - Access BIOS/UEFI to verify boot order
   - Check hardware status

2. **Network Issues**
   - Access IP KVM console
   - Check network configuration
   - Verify network interface status
   - Test connectivity

3. **OS Crashes**
   - Access IP KVM console
   - View kernel panic messages
   - Access recovery mode if available
   - Perform system recovery

### Remote Management

1. **Power Control**
   - Power on/off server remotely
   - Hard reset if needed
   - View power status

2. **BIOS/UEFI Access**
   - Access BIOS settings remotely
   - Configure hardware settings
   - Update firmware if needed

3. **Installation Media**
   - Mount ISO images remotely (if supported)
   - Boot from virtual media
   - Install operating systems remotely

## Security Considerations

### Credential Management

- **Never commit credentials to Git**
- Store credentials in password manager
- Use strong, unique passwords
- Enable two-factor authentication if available
- Rotate credentials regularly

### Network Security

- **Isolate IP KVM on management network** (recommended)
- Use VPN for remote access
- Enable HTTPS for web interface
- Restrict access by IP address if possible
- Monitor access logs

### Access Control

- Use least privilege principle
- Create separate accounts for different users
- Log all access attempts
- Review access logs regularly

## Configuration Template

When hardware is available, document the following:

```yaml
ip_kvm:
  device_model: "[Model]"
  ip_address: "[IP Address]"
  web_port: "[Port]"
  vnc_port: "[Port]"
  serial_port: "[Port]"
  access_url: "https://[IP]:[Port]"
  credentials_location: "password-manager://homelab/ip-kvm"
  network:
    vlan: "[VLAN ID if applicable]"
    gateway: "[Gateway]"
    dns: "[DNS Servers]"
  features:
    virtual_media: true/false
    power_control: true/false
    serial_console: true/false
    vnc: true/false
```

## Troubleshooting

### Cannot Access IP KVM

1. Verify network connectivity
2. Check IP address configuration
3. Verify firewall rules allow access
4. Check IP KVM device status (power, network link)

### Console Not Displaying

1. Verify server is powered on
2. Check video cable connections (if applicable)
3. Verify console settings in IP KVM
4. Try different console options (VNC, serial, etc.)

### Authentication Issues

1. Verify credentials are correct
2. Check for account lockouts
3. Reset credentials if needed
4. Verify access permissions

## Integration with Talos Linux

### Initial Installation

1. Use IP KVM to boot from Talos Linux ISO
2. Monitor installation process via console
3. Access Talos API after installation via network

### Ongoing Management

- IP KVM provides fallback access when Talos API is unavailable
- Use for hardware-level troubleshooting
- Access BIOS/UEFI for hardware configuration
- Monitor boot process

## References

- [Story 1.1](../_bmad-output/implementation-artifacts/1-1-install-and-configure-talos-linux-base-system.md)
- [Story 11.1](../_bmad-output/implementation-artifacts/11-1-configure-ip-kvm-access.md)
- [Talos Linux Documentation](https://www.talos.dev/)

## Next Steps

When hardware is available:

1. Document actual IP KVM device model and specifications
2. Configure network settings
3. Set up authentication
4. Test all access methods
5. Document actual IP addresses and ports
6. Store credentials securely
7. Update this document with actual configuration
