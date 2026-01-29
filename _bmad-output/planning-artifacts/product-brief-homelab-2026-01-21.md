---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments: []
date: 2026-01-21
author: Paul
completed: 2026-01-21
---

# Product Brief: homelab

## Executive Summary

The homelab project is a self-hosted, Infrastructure-as-Code (IaC) managed home server solution designed to provide independence from GAFAM services while offering centralized storage, media streaming, gaming capabilities, and extensible local services. Built on a powerful AOOSTAR WTR MAX 8845 system (64GB RAM, 1TB SSD, 2x 20TB HDD), this solution uses a **hybrid architecture** combining local homelab infrastructure with Oracle Cloud VPS (Always Free tier) to minimize home network exposure while maintaining high availability for Internet-exposed services. The solution addresses the needs of a freelance developer and graphic designer couple, with future expansion to family members for storage needs.

The core value proposition centers on **AI-assisted maintainability**, achieved through Infrastructure as Code (IaC) as the enabling mechanism. Unlike traditional homelab setups requiring manual configuration and complex maintenance, this solution provides a declarative, version-controlled approach that makes infrastructure as manageable as code. The fundamental goal is not IaC for its own sake, but rather enabling developers to manage their homelab with the same tools and workflows they use for code—versioning, testing, and AI assistance—without requiring deep system administration expertise.

Key capabilities include: centralized NAS with flexible uptime (Wake-on-LAN enabled), media server stack (arr* suite), Windows/Steam OS virtualization for gaming on TV and remote devices (Mac, Steam Deck), extensible local services starting with Pi-hole, Nextcloud (replacing Google Drive), Jellyfin (replacing Netflix), and Immich (photo server), and hybrid cloud architecture with Oracle Cloud VPS for Internet-exposed services and high-uptime requirements (monitoring, public websites, Nextcloud entry point for non-technical users).

---

## Core Vision

### Problem Statement

Currently, the users lack centralized storage and rely on ad-hoc solutions like Syncthing for phone-to-MacBook backups. Gaming is limited by platform constraints - Steam Deck and Mac have restricted game compatibility, and there's no Windows system available at home. The couple wants to break free from GAFAM dependencies (Google Drive, Netflix) while maintaining control over their data and having the ability to easily add new self-hosted services.

The fundamental challenge is creating a homelab that doesn't require traditional manual configuration complexity. As a freelance developer, the primary user wants to leverage Infrastructure as Code principles to enable AI-assisted configuration and maintenance, making the homelab as manageable as code rather than requiring deep system administration expertise.

### Problem Impact

Without a centralized solution:
- **Data fragmentation**: Files scattered across devices with no unified storage
- **Platform limitations**: Gaming restricted by Mac/Steam OS compatibility constraints
- **GAFAM dependency**: Data and services locked into external platforms
- **Service limitations**: No easy way to add self-hosted services like Pi-hole, photo management, or media streaming
- **Maintenance complexity**: Traditional homelab setups require ongoing manual system administration

The impact extends beyond the primary users - family members (approximately 5 people) need storage solutions but currently lack access to a centralized, family-friendly option.

### Why Existing Solutions Fall Short

Traditional homelab solutions (TrueNAS, Proxmox, Synology) provide powerful capabilities but suffer from:

- **Manual configuration complexity**: Require deep system administration knowledge
- **Non-declarative management**: Changes require manual intervention rather than code-driven updates
- **AI-unfriendly**: Difficult to configure or maintain with AI assistance due to lack of IaC approach
- **Maintenance overhead**: Ongoing manual system administration required
- **Limited extensibility**: Adding new services often requires manual configuration rather than declarative definitions

Cloud solutions (Google Drive, Netflix, etc.) solve convenience but create:
- **Vendor lock-in**: Data and services controlled by external providers
- **Privacy concerns**: Data stored on external servers
- **Ongoing costs**: Subscription fees that accumulate over time
- **Limited customization**: Can't add custom services or modify behavior

### Proposed Solution

A self-hosted homelab infrastructure designed from first principles to achieve AI-assisted maintainability through declarative infrastructure management:

**Core Principles → Solution Components:**

1. **Maintainability + AI Assistance → Declarative Infrastructure**: All infrastructure defined in code (Terraform, Ansible, Docker Compose, Kubernetes manifests, etc.) enabling version control, reproducibility, and AI-assisted configuration. IaC is the means to achieve maintainability, not the end goal itself.

2. **Control + Independence → Strategic Self-Hosting**: Self-hosted services prioritized for data control and GAFAM independence, with cloud fallback considered when strategically appropriate. Self-hosting is a strategic choice, not a dogmatic requirement.

3. **Gaming Accessibility → Targeted Virtualization**: Windows and Steam OS VMs specifically for gaming access from Mac/Steam Deck/TV. Virtualization is a technical solution for gaming needs, not an architectural requirement for all services.

4. **Energy Efficiency + Remote Access → Smart Uptime Management**: Wake-on-LAN and flexible scheduling to balance performance needs with energy consumption while maintaining remote accessibility.

5. **Versioning + Reproducibility → Code as Source of Truth**: Infrastructure changes tracked in version control, enabling rollback, testing, and collaboration—not adding unnecessary complexity.

6. **Extensibility → Modular Architecture**: Services designed as independent, modular components that can be added through declarative IaC definitions without requiring system-wide refactoring.

**Solution Components:**

- **Centralized Storage**: NAS functionality with flexible uptime and Wake-on-LAN for remote activation
- **Media Server Stack**: Complete arr* suite (Radarr, Sonarr, Prowlarr, etc.) for media management and streaming via Jellyfin
- **Gaming Virtualization**: Windows and Steam OS VMs for gaming on TV and remote access from Mac/Steam Deck
- **Extensible Services**: Modular architecture enabling easy addition of self-hosted services (Pi-hole, Nextcloud, Immich, and future additions) through IaC
- **GAFAM Replacement**: Replace Google Drive (Nextcloud), Netflix (Jellyfin + arr*), and add photo management (Immich)
- **Backup & Disaster Recovery**: Automated backup strategy with selective critical backup to cloud (Hetzner), encrypted backups with user-provided keys, optimized compression and deduplication, and rapid restoration capabilities
- **Monitoring & Alerting**: Proactive system monitoring with automated alerts for issues, performance, and security, including push notifications to mobile phone for critical incidents
- **Security Infrastructure**: Firewall, VPN access, automated security updates, Docker image security scanning before deployment, and access control management
- **IP KVM Access**: Remote server management via IP KVM (using KVM dongle/IP KVM device) for out-of-band management and troubleshooting
- **Hybrid Cloud Architecture**: Oracle Cloud VPS (Always Free tier) for Internet-exposed services and high-uptime requirements, minimizing exposure of home network
- **User Experience Layer**: Simplified interfaces for non-technical users, mobile access, and multi-platform compatibility

The solution leverages the powerful hardware (64GB RAM, 1TB SSD, 2x 20TB HDD) to provide enterprise-grade capabilities in a home environment, managed with developer-friendly principles that prioritize maintainability, extensibility, and user experience.

### Key Differentiators

1. **AI-Assisted Maintainability**: The fundamental differentiator is making infrastructure as maintainable as code through IaC, enabling AI tools to assist with setup, maintenance, and troubleshooting. IaC is the mechanism, not the goal.

2. **Modular Architecture by Design**: Services are designed as independent, modular components that can be extended without system-wide refactoring, enabling true extensibility through declarative IaC definitions.

3. **Strategic Self-Hosting**: Self-hosting is prioritized for control and independence (data sovereignty, GAFAM independence), but approached strategically rather than dogmatically—cloud fallback considered when appropriate.

4. **Targeted Virtualization**: Virtualization is used specifically for gaming needs (Windows/Steam OS VMs), not as an architectural requirement for all services, avoiding unnecessary overhead.

5. **Energy-Efficient Operation**: Smart uptime management (Wake-on-LAN, flexible scheduling) balances performance needs with energy consumption while maintaining remote accessibility—addressing both environmental and practical concerns.

6. **Code as Source of Truth**: Infrastructure changes are version-controlled, enabling rollback, testing, and collaboration—providing the same developer workflows for infrastructure as for application code.

7. **Complete GAFAM Replacement Ecosystem**: Not just storage, but a comprehensive ecosystem replacing major cloud services (Google Drive → Nextcloud, Netflix → Jellyfin + arr*, photo management → Immich) with self-hosted alternatives that maintain user control.

8. **Hybrid Cloud Architecture**: Strategic use of Oracle Cloud VPS (Always Free) for Internet-exposed services and high-uptime requirements, minimizing home network exposure while maintaining cost efficiency. This hybrid approach provides the best of both worlds: powerful local resources for storage and media, and reliable VPS for public-facing services.

---

### User Experience Requirements

Based on persona validation, the solution must address the needs of three distinct user groups: the developer (primary administrator), the graphic designer (non-technical power user), and family members (casual users). The following requirements ensure the solution is accessible and effective for all users:

#### For Non-Technical Users (Graphic Designer & Family)

1. **Simplified User Interfaces**: 
   - Intuitive web interfaces for Nextcloud, Immich, and Jellyfin requiring no technical knowledge
   - Mobile applications or responsive web design for access from smartphones and tablets
   - Clear, visual navigation without technical jargon

2. **Seamless Multi-Platform Access**:
   - Native or web-based clients for Windows, Mac, Android, and iOS
   - Consistent experience across all platforms
   - Offline access with sync when connection is restored

3. **Performance for Large Files**:
   - Optimized transfer speeds for large design files (PSD, AI, video files)
   - Efficient streaming for media content
   - Background sync to avoid blocking user workflows

4. **External Sharing Capabilities**:
   - Secure sharing links for clients and external contacts (graphic designer use case)
   - Access control and expiration for shared links
   - Simple sharing workflow without technical complexity

5. **Automatic Backup & Sync**:
   - Transparent automatic backup of user files
   - Version history for file recovery
   - Clear indication of backup status

6. **Availability Strategy**:
   - Clear communication about server uptime/downtime
   - Local caching or cloud sync fallback for critical files when server is off
   - Graceful degradation when services are unavailable

#### For Technical Administrator (Developer)

1. **Backup & Disaster Recovery**:
   - Automated backup of infrastructure configuration (IaC) and data
   - **Selective Critical Backup**: Ability to tag folders/files as "critical" for priority cloud backup
   - **Cloud Backup Integration**: Automated backup to Hetzner Storage (or compatible cloud storage) for critical data
   - **Encrypted Backups**: All backups encrypted with user-provided encryption key
   - **Optimized Backup Strategy**: Compression and deduplication to minimize storage costs and transfer volume
   - **Scheduled Backups**: Regular automated backups at configurable intervals
   - Rapid restoration procedures documented and tested
   - Version-controlled backup strategy

2. **Monitoring & Alerting**:
   - Proactive monitoring of system health, performance, and security
   - Automated alerts for critical issues (disk space, service failures, security events)
   - **Mobile Push Notifications**: Real-time push notifications to mobile phone for critical incidents
     - **Critical Alerts**: Disk failure detection, service down during active hours, suspicious connections, security incidents
     - **Notification Channels**: Gotify, Ntfy, Apprise, Telegram bot, or similar push notification service
     - **Alert Prioritization**: Critical alerts sent immediately, warnings sent in digest format
   - Dashboard for at-a-glance system status

3. **Security Infrastructure**:
   - Firewall configuration and management
   - VPN access for secure remote connections
   - Automated security updates and patch management
   - Access control and user management

4. **Documentation & Support**:
   - Comprehensive documentation for infrastructure setup and maintenance
   - User guides for non-technical users
   - Troubleshooting guides and recovery procedures

#### For Family Users (Storage-Focused)

1. **Zero-Configuration Access**:
   - Simple account setup process
   - Pre-configured access without technical setup
   - Clear instructions for first-time use

2. **Quota Management**:
   - Individual storage quotas to prevent resource exhaustion
   - Clear visibility into storage usage
   - Automated notifications when approaching limits

3. **Privacy & Security**:
   - Clear privacy controls and data protection
   - Family-friendly security settings
   - Protection of family data from external access

4. **Support & Help**:
   - Simple documentation for common tasks
   - Clear escalation path for technical issues
   - User-friendly error messages and recovery guidance

#### Cross-Cutting Requirements

1. **Accessibility**: All interfaces must be accessible and usable by users with varying technical expertise
2. **Performance**: System must handle concurrent use by multiple users without degradation
3. **Reliability**: Services must be stable and predictable, with clear communication about maintenance windows
4. **Scalability**: Architecture must support adding family members and services without major refactoring
5. **Security**: All user data must be protected with appropriate security measures while maintaining usability

---

### Risk Mitigation & Operational Excellence

Based on pre-mortem analysis, the following critical risks have been identified along with comprehensive mitigation strategies to ensure long-term success and reliability of the homelab solution.

#### Critical Risk 1: Data Loss (Criticality: HIGH)

**Risk Scenario**: Hardware failure, backup failures, or configuration errors result in permanent data loss affecting work files, family photos, and critical infrastructure configurations.

**Mitigation Strategy - Backup & Disaster Recovery (3-2-1 Rule)**:

1. **3 Copies**: Primary data, local backup, off-site backup
2. **2 Different Media**: SSD primary, HDD backup, cloud/remote backup
3. **1 Off-Site**: Remote backup location (cloud or separate physical location)

**Implementation**:
- **Selective Critical Backup System**:
  - Tag-based system to mark folders/files as "critical" (metadata or configuration file)
  - Critical data automatically backed up to cloud storage (Hetzner Storage or compatible)
  - Non-critical data backed up locally only (cost optimization)
- **Encrypted Cloud Backups**:
  - All cloud backups encrypted with user-provided encryption key (stored securely)
  - Encryption before upload to cloud (client-side encryption)
  - Support for multiple encryption methods (AES-256, etc.)
- **Optimized Backup Strategy**:
  - Compression (gzip, zstd, or similar) to reduce backup size
  - Deduplication to avoid storing duplicate data
  - Incremental backups (only changes since last backup)
  - Bandwidth optimization for cloud uploads
- **Automated Backup Schedule**:
  - Daily backups of critical data to cloud
  - Weekly backups of all user data locally
  - Weekly backups of infrastructure configuration (IaC)
  - Configurable backup intervals per data type
- **Backup Management**:
  - Monthly backup restoration tests to verify integrity
  - Monitoring and alerting for backup failures
  - Backup retention policies (keep X days/weeks/months)
  - Rapid restoration procedures documented and tested
  - Version-controlled backup strategy in Git

#### Critical Risk 2: Security Compromise (Criticality: HIGH)

**Risk Scenario**: Unpatched vulnerabilities, misconfigured services, or weak access controls lead to unauthorized access, data breach, or ransomware attack.

**Mitigation Strategy - Defense in Depth**:

1. **Automated Security Updates**: 
   - Automated patch management with testing before production
   - **Automatic Updates**: Updates deployed automatically when new versions are available
   - **Update Strategy**: Immediate updates for security patches, scheduled updates for feature releases
   - Security update monitoring and alerting
   - Rollback capability for problematic updates
   - **Docker Image Updates**: Automatic pull and deployment of updated Docker images

2. **Network Security**:
   - Firewall configuration (fail2ban, iptables/ufw)
   - Reverse proxy with authentication (Traefik/Nginx)
   - VPN mandatory for remote access
   - Network segmentation (services isolated)

3. **Access Control**:
   - Strong authentication (2FA) for critical services
   - Role-based access control (RBAC)
   - Regular access review and cleanup
   - Secure password management

4. **Security Monitoring**:
   - Intrusion detection and prevention
   - Security log monitoring and analysis
   - Automated alerts for suspicious activity
   - **Mobile Push Notifications**: Immediate push notifications to phone for security incidents (suspicious connections, intrusion attempts, security anomalies)
   - Regular security audits

#### Critical Risk 3: Service Unavailability (Criticality: MEDIUM)

**Risk Scenario**: Resource exhaustion, hardware failure, or configuration errors cause service degradation or complete unavailability, impacting all users.

**Mitigation Strategy - Proactive Monitoring & Capacity Planning**:

1. **Resource Monitoring**:
   - Real-time monitoring of CPU, RAM, disk, and network usage
   - Automated alerts at 80% disk, 90% RAM thresholds
   - Performance metrics tracking and trending

2. **Capacity Management**:
   - User quotas to prevent resource exhaustion
   - Automated notifications when approaching limits
   - Capacity planning with growth projections
   - Resource prioritization (QoS) for critical services

3. **High Availability**:
   - Service health checks and automatic restart
   - Load balancing where applicable
   - Graceful degradation strategies
   - Maintenance windows with user notification

#### Critical Risk 4: Infrastructure Complexity (Criticality: MEDIUM)

**Risk Scenario**: Infrastructure becomes too complex to maintain, changes break services, rollback fails, and AI assistance becomes ineffective.

**Mitigation Strategy - Simplicity & Testing**:

1. **Documentation**:
   - Comprehensive architecture documentation (versioned)
   - Setup and maintenance procedures
   - Troubleshooting guides
   - User documentation for non-technical users

2. **Testing & Validation**:
   - IaC changes tested before production deployment
   - Staging/test environment for validation
   - Automated rollback on deployment failure
   - Regular infrastructure health checks

3. **Architecture Principles**:
   - Modular, simple architecture by design
   - Clear separation of concerns
   - Version-controlled architecture decisions
   - Regular architecture reviews

#### Critical Risk 5: User Adoption Failure (Criticality: MEDIUM)

**Risk Scenario**: Non-technical users (graphic designer, family) find the system too complex, unreliable, or unintuitive, leading to abandonment and return to GAFAM services.

**Mitigation Strategy - User-Centric Design & Support**:

1. **User Experience**:
   - Simplified, intuitive interfaces tested with real users
   - Mobile-first design for accessibility
   - Clear error messages and recovery guidance
   - Consistent experience across platforms

2. **Training & Support**:
   - Initial user training and onboarding
   - Comprehensive user documentation (non-technical)
   - FAQ and troubleshooting guides
   - Feedback collection and continuous improvement

3. **Reliability & Performance**:
   - Performance optimization for user workflows
   - Reliability monitoring and quick issue resolution
   - Clear communication about maintenance and downtime
   - Proactive issue prevention

#### Operational Excellence Framework

**Continuous Improvement**:
- Regular review of risks and mitigation strategies
- Monthly operational reviews
- User feedback integration
- Performance metrics tracking
- Security posture assessment

**Incident Response**:
- Documented incident response procedures
- Post-incident reviews and improvements
- Communication plans for service disruptions
- Escalation paths for critical issues

**Change Management**:
- Version-controlled infrastructure changes
- Change testing and validation
- Rollback procedures for all changes
- Change documentation and communication

**Critical Alerting & Mobile Notifications**:
- **Push Notification System**: Mobile push notifications for critical incidents
  - **Notification Service**: Gotify, Ntfy, Apprise, Telegram bot, or similar
  - **Mobile App**: Native mobile app or web-based push notifications
  - **Alert Routing**: Alertmanager (Prometheus) or similar alert routing system
- **Critical Alert Categories** (trigger immediate push notifications):
  1. **Disk Failure Detection**:
     - SMART errors and disk health warnings
     - Disk space critical (< 10% free)
     - Disk I/O errors or performance degradation
     - RAID array degradation (if applicable)
  2. **Service Downtime During Active Hours**:
     - Service down during configured active hours (e.g., 8 AM - 11 PM)
     - Critical services (Nextcloud, monitoring) down at any time
     - Multiple services down simultaneously
     - Service restart failures
  3. **Suspicious Connections & Security Events**:
     - Unauthorized access attempts
     - Multiple failed login attempts
     - Unusual network activity (port scans, connection attempts from unknown IPs)
     - Intrusion detection system (IDS) alerts
     - Firewall blocks of suspicious traffic
     - VPN connection from unusual location
  4. **Security Incidents**:
     - Critical vulnerability detections
     - Security update failures
     - Certificate expiration warnings
     - Docker image security scan failures
     - Unauthorized configuration changes
  5. **System Health Critical**:
     - Backup failures
     - High resource usage (CPU > 90%, RAM > 95%)
     - Network connectivity issues
     - Critical service health check failures
- **Alert Prioritization**:
  - **Critical**: Immediate push notification (disk failure, security incidents, service down during active hours)
  - **Warning**: Digest notification or non-urgent push (high resource usage, non-critical service down)
  - **Info**: Logged only, no push notification
- **Alert Acknowledgment**:
  - Ability to acknowledge alerts from mobile app
  - Alert escalation if not acknowledged within timeframe
  - Alert history and tracking
- **Success Indicator**: Critical incidents detected and notified within minutes, enabling rapid response

**Automated Update Management**:
- **Automatic Updates**: System automatically updates services and Docker images when new versions are available
- **Update Strategy**:
  - **Security Updates**: Immediate automatic deployment when available
  - **Feature Updates**: Scheduled automatic deployment (configurable schedule)
  - **Docker Images**: Automatic pull and deployment of updated images (Watchtower or similar)
  - **System Updates**: Automated system package updates with testing
- **Update Process**:
  - Pre-update backup of configurations
  - Health checks after updates
  - Automatic rollback on update failure
  - Update notifications and logging
- **Update Monitoring**:
  - Track update frequency and success rate
  - Monitor for update-related issues
  - Alert on update failures
- **Success Indicator**: System stays current with latest versions while maintaining stability

---

### Architecture Decision Records (ADRs)

This section documents key architectural decisions made through structured debate among multiple architect personas, ensuring well-reasoned choices with explicit trade-offs documented.

#### ADR-001: Hypervisor/Base OS Selection

**Status**: Accepted  
**Date**: 2026-01-21  
**Decision Makers**: Architecture Team (Simplicity First, Enterprise, DevOps, Performance personas)

**Context**: Need to select the base operating system and virtualization approach for the homelab, balancing IaC-friendliness, gaming VM support, and operational simplicity.

**Options Considered**:

1. **Proxmox VE**: Full hypervisor with web interface, built-in snapshots and backups
2. **TrueNAS Scale**: NAS-first approach with integrated virtualization
3. **Ubuntu Server + Docker + QEMU/KVM**: Minimal OS with container orchestration and native virtualization

**Decision**: **Ubuntu Server + Docker + QEMU/KVM**

**Rationale**:
- Maximum IaC-friendliness: Docker Compose files are declarative, version-controlled, and AI-assistable
- Simplicity: No separate hypervisor management layer, everything defined as code
- Flexibility: Docker Compose for services, QEMU/KVM for gaming VMs (Windows/Steam OS)
- AI Assistance: Docker Compose is well-understood by AI tools, making configuration and troubleshooting easier
- Alignment with core value proposition: AI-assisted maintainability through code

**Trade-offs**:
- ✅ Pros: IaC-first, simple, AI-assistable, no web UI overhead
- ❌ Cons: No built-in web interface (can add Portainer), VMs require manual QEMU/KVM setup
- ⚠️ Mitigation: Use Portainer for Docker management UI, automate QEMU/KVM setup via Ansible

**Alternatives Rejected**:
- **Proxmox**: Requires manual configuration, less IaC-friendly, adds complexity
- **TrueNAS Scale**: Less flexible for services, virtualization capabilities limited

---

#### ADR-002: Service Orchestration Platform

**Status**: Accepted  
**Date**: 2026-01-21  
**Decision Makers**: Architecture Team

**Context**: Need to select how services (Nextcloud, Jellyfin, Immich, etc.) will be orchestrated and managed.

**Options Considered**:

1. **Docker Compose**: Simple, declarative, single-file orchestration
2. **Kubernetes (K3s/K8s)**: Enterprise-grade, scalable, high availability
3. **Docker Swarm**: Middle ground between Compose and Kubernetes

**Decision**: **Docker Compose**

**Rationale**:
- Perfect for IaC: Single YAML file version-controlled, easily understood by AI tools
- Simplicity: No cluster management, no control plane overhead
- Resource efficiency: Minimal overhead compared to Kubernetes
- Sufficient for homelab: Single-node deployment doesn't require Kubernetes complexity
- AI-friendly: Docker Compose syntax is well-supported by AI assistance tools

**Trade-offs**:
- ✅ Pros: Simple, IaC-friendly, lightweight, AI-assistable, perfect for single-node
- ❌ Cons: No built-in high availability, single-node limitation
- ⚠️ Mitigation: High availability not required for homelab, can migrate to Kubernetes later if needed

**Alternatives Rejected**:
- **Kubernetes**: Overkill for single-node homelab, adds significant complexity and resource overhead
- **Docker Swarm**: Less commonly used, intermediate complexity without clear benefits

---

#### ADR-003: Storage Filesystem Selection

**Status**: Accepted  
**Date**: 2026-01-21  
**Decision Makers**: Architecture Team

**Context**: Need to select filesystem for managing 2x 20TB HDD storage with data integrity, snapshots, and backup capabilities.

**Options Considered**:

1. **ZFS (ZFS on Linux)**: Enterprise-grade with snapshots, compression, data integrity, deduplication
2. **Btrfs**: Linux-native with snapshots and checksumming
3. **ext4 + LVM**: Traditional, simple, performant

**Decision**: **ZFS (ZFS on Linux)**

**Rationale**:
- Data integrity: Built-in checksumming prevents silent data corruption
- Snapshots: Essential for 3-2-1 backup strategy, rapid recovery
- Compression: Saves storage space, improves performance for compressible data
- Mature and proven: Industry standard for NAS and data storage
- Backup integration: ZFS send/receive enables efficient incremental backups
- Alignment with risk mitigation: Critical for preventing data loss (Critical Risk 1)

**Trade-offs**:
- ✅ Pros: Data integrity, snapshots, compression, mature, backup-friendly
- ❌ Cons: Higher RAM requirements, steeper learning curve, more complex setup
- ⚠️ Mitigation: 64GB RAM is sufficient, documentation and IaC automation reduce complexity

**Alternatives Rejected**:
- **Btrfs**: Less mature, sometimes performance issues, less proven for large storage
- **ext4 + LVM**: No native snapshots, no data integrity checks, doesn't support backup strategy

---

#### ADR-004: Reverse Proxy and Routing

**Status**: Accepted  
**Date**: 2026-01-21  
**Decision Makers**: Architecture Team

**Context**: Need reverse proxy for routing external traffic to internal services with automatic HTTPS and service discovery.

**Options Considered**:

1. **Traefik**: Auto-discovery, automatic Let's Encrypt, Docker label-based configuration
2. **Nginx**: Robust, highly configurable, industry standard
3. **Caddy**: Simple, automatic HTTPS, minimal configuration

**Decision**: **Traefik**

**Rationale**:
- Docker integration: Auto-discovery via Docker labels, perfect for Docker Compose
- IaC-friendly: Configuration via Docker Compose labels, version-controlled
- Automatic HTTPS: Let's Encrypt integration with automatic certificate renewal
- Simplicity: Minimal configuration required, labels define routing
- AI-assistable: Label-based configuration is easy for AI tools to understand and modify

**Trade-offs**:
- ✅ Pros: Auto-discovery, automatic HTTPS, IaC-friendly, Docker-native, simple
- ❌ Cons: Less fine-grained control than Nginx, can be "magical" (less transparent)
- ⚠️ Mitigation: Documentation of label-based configuration, fallback to Nginx if needed

**Alternatives Rejected**:
- **Nginx**: Requires manual configuration, more complex, less integrated with Docker
- **Caddy**: Fewer features, less commonly used, less Docker integration

---

#### ADR Summary

**Key Architectural Decisions**:

1. **Base Platform**: Ubuntu Server + Docker + QEMU/KVM
   - Docker Compose for services orchestration
   - QEMU/KVM for gaming VMs (Windows/Steam OS)

2. **Orchestration**: Docker Compose
   - Single YAML file, version-controlled, AI-assistable

3. **Storage**: ZFS (ZFS on Linux)
   - Data integrity, snapshots, compression, backup-friendly

4. **Reverse Proxy**: Traefik
   - Auto-discovery, automatic HTTPS, Docker-native

**Design Principles Applied**:
- **IaC-First**: All decisions prioritize Infrastructure as Code compatibility
- **AI-Assistable**: Choices that work well with AI tools for configuration and troubleshooting
- **Simplicity**: Avoiding unnecessary complexity while maintaining capabilities
- **Risk Mitigation**: Decisions align with identified critical risks (data loss, security, availability)

**Future Considerations**:
- Migration path to Kubernetes if multi-node deployment becomes necessary
- Consideration of additional storage solutions if ZFS proves too complex
- Evaluation of alternative reverse proxies if Traefik limitations are encountered

---

## Target Users

### Primary Users

#### Persona 1: Paul - The Developer Administrator

**Name & Context:**
- **Name**: Paul
- **Role**: Freelance Developer
- **Technical Level**: Intermediate to Advanced
- **Environment**: Works from home, manages multiple client projects
- **Motivation**: Wants to manage infrastructure like code, leverage AI assistance, maintain independence from GAFAM services
- **Goals**: 
  - Centralized storage for work files and projects
  - Self-hosted services (Pi-hole, Nextcloud, media server)
  - Gaming virtualization for Windows/Steam OS access
  - Infrastructure managed through IaC for easy maintenance

**Problem Experience:**
- Currently uses ad-hoc solutions (Syncthing for phone-to-MacBook backups)
- No centralized storage, files scattered across devices
- Limited gaming options (Mac/Steam Deck compatibility constraints)
- Wants to break free from GAFAM dependencies but needs simple maintenance

**Success Vision:**
- Can add new services in minutes through IaC
- Infrastructure changes tracked in version control
- AI can help troubleshoot and configure services
- Complete control over data and services
- Gaming accessible from any device (Mac, Steam Deck, TV)

**User Journey:**

1. **Discovery**: Already aware of homelab concept, researching IaC-managed solutions
2. **Onboarding**: 
   - Initial setup using IaC (Docker Compose, Ansible)
   - Configuration of base services (Nextcloud, Pi-hole, Jellyfin)
   - Testing backup and disaster recovery procedures
3. **Core Usage**:
   - Daily: Access to centralized storage, Pi-hole filtering
   - Weekly: Add new services via IaC, review monitoring dashboards
   - Monthly: Backup verification, infrastructure updates
4. **Success Moment**: First time adding a new service (e.g., Immich) in 5 minutes via Docker Compose, with AI assistance
5. **Long-term**: Infrastructure becomes a reliable, maintainable foundation that grows with needs

**Key Interactions:**
- Infrastructure configuration via IaC files
- Service management through Docker Compose
- Monitoring dashboards for system health
- AI-assisted troubleshooting and configuration
- Version control for infrastructure changes

---

#### Persona 2: The Graphic Designer - Non-Technical Power User

**Name & Context:**
- **Name**: (Paul's partner)
- **Role**: Graphic Designer (Fashion Industry)
- **Technical Level**: Non-Technical (comfortable with apps, not systems)
- **Environment**: Works from home, creates large design files (PSD, AI, video)
- **Motivation**: Needs reliable storage, easy file sharing with clients, photo organization
- **Goals**:
  - Replace Google Drive with self-hosted solution
  - Access files from any device (Mac, phone, tablet)
  - Share files securely with clients
  - Organize and access photos easily

**Problem Experience:**
- Currently uses Google Drive (vendor lock-in, privacy concerns)
- Files scattered across devices
- Limited control over data
- Needs to share large design files with clients

**Success Vision:**
- Simple, intuitive interface (like Google Drive but self-hosted)
- Access files from Mac, phone, tablet seamlessly
- Share files with clients easily and securely
- Automatic backup without thinking about it
- Photo organization and sharing (Immich)

**User Journey:**

1. **Discovery**: Paul introduces the system, shows Nextcloud interface
2. **Onboarding**:
   - Account creation by Paul (pre-configured)
   - First login and interface tour
   - First file upload (design file)
   - Mobile app installation and setup
3. **Core Usage**:
   - Daily: Upload/download design files, access from mobile
   - Weekly: Share files with clients via secure links
   - Regularly: Organize photos in Immich, stream media via Jellyfin
4. **Success Moment**: First time accessing files from phone while away from home, or sharing a file with a client seamlessly
5. **Long-term**: System becomes as natural as Google Drive, but with complete control and privacy

**Key Interactions:**
- Nextcloud web interface for file management
- Nextcloud mobile app for on-the-go access
- Immich for photo organization and sharing
- Jellyfin for media streaming
- Secure file sharing with clients

**Pain Points to Address:**
- Interface must be intuitive (no technical jargon)
- Mobile access must be reliable
- Large file transfers must be fast
- Backup must be automatic and transparent
- Clear communication when server is down

---

### Secondary Users

#### Persona 3: Family Members - Casual Storage Users

**Name & Context:**
- **Role**: Family members (~5 people)
- **Technical Level**: Varying (mostly non-technical)
- **Environment**: Different locations, various devices (Windows, Mac, Android, iOS)
- **Motivation**: Need centralized storage for photos, documents, without subscription costs
- **Goals**:
  - Store family photos and documents
   - Access from any device
   - Share within family
   - No technical complexity

**Problem Experience:**
- Currently use various cloud services (Google Drive, iCloud, etc.)
- Pay for multiple subscriptions
- Data scattered across services
- No centralized family storage

**Success Vision:**
- Simple account setup (invitation from Paul)
- Access storage from any device
- Easy photo/document sharing within family
- No subscription costs
- Privacy and control over family data

**User Journey:**

1. **Discovery**: Invitation from Paul to join family storage
2. **Onboarding**:
   - Receive invitation link
   - Create account (simple form)
   - First login and quick tour
   - Mobile app installation (optional)
3. **Core Usage**:
   - Weekly/Monthly: Upload photos, access shared documents
   - Occasionally: Share photos with family members
4. **Success Moment**: First time accessing family photos from phone, or sharing a document with another family member
5. **Long-term**: Family storage becomes the go-to place for photos and documents

**Key Interactions:**
- Nextcloud web interface (simplified view)
- Nextcloud mobile app
- Photo sharing within family
- Document storage and access

**Pain Points to Address:**
- Zero-configuration setup (pre-configured by Paul)
- Simple, intuitive interface
- Clear storage quotas and usage visibility
- Reliable access from all devices
- Support documentation for common tasks

---

### User Journey Summary

**Common Journey Elements Across All Users:**

1. **Discovery Phase**:
   - Paul: Researches and plans homelab setup
   - Graphic Designer: Introduced by Paul
   - Family: Invited by Paul

2. **Onboarding Phase**:
   - Paul: Infrastructure setup via IaC
   - Graphic Designer: Account creation, interface tour, first upload
   - Family: Invitation, account creation, first access

3. **Core Usage Phase**:
   - Paul: Infrastructure management, service additions, monitoring
   - Graphic Designer: Daily file management, client sharing, media consumption
   - Family: Occasional storage access, photo sharing

4. **Success Moments**:
   - Paul: Adding new service via IaC in minutes
   - Graphic Designer: Accessing files from mobile, seamless client sharing
   - Family: Accessing family photos from any device

5. **Long-term Integration**:
   - All users: System becomes natural part of daily workflow
   - Reliable, trusted, and indispensable

**Critical Success Factors:**
- **For Paul**: IaC-first approach, AI-assistable, version-controlled
- **For Graphic Designer**: Simple interface, reliable mobile access, fast large file transfers
- **For Family**: Zero-configuration, intuitive interface, reliable access

---

## Success Metrics

### User Success Metrics

#### For Technical Administrator (Paul)

**Service Addition Efficiency:**
- **Metric**: Time to add a new service via IaC
- **Targets**: 
  - First-time service installation: < 2 hours (includes research, configuration, testing)
  - Recurrent service addition: < 15 minutes (using existing templates/patterns)
- **Measurement**: Track time from service selection to first successful access, distinguish first-time vs recurrent
- **Success Indicator**: Adding services becomes routine, not a project
- **Learning Curve Metric**: Track improvement in service addition time over first 10 services

**Operational Time Investment:**
- **Metric**: Active management time per week/month
- **Definition**: Time actively spent on infrastructure management including:
  - Configuration changes
  - Troubleshooting and debugging
  - Maintenance tasks (updates, backups verification)
  - Research and learning (documentation, tutorials)
  - Testing and validation
  - Excludes: Passive monitoring, waiting for processes
- **Target**: < 2 hours per week, < 8 hours per month (after initial setup period)
- **Measurement**: Track time using time-tracking tools or logs, distinguish active vs passive time
- **Success Indicator**: Infrastructure runs with minimal intervention
- **Additional Metric**: Total engagement time (active + passive monitoring) - target < 4 hours/week

**Incident Management:**
- **Metric**: Time system is unavailable due to incidents
- **Targets**: 
  - Total downtime: < 4 hours per month
  - Number of incidents: < 2 incidents per month
  - Critical service downtime: < 1 hour per month (services essential for daily operations)
- **Measurement**: 
  - Track unplanned service interruptions
  - Distinguish critical vs non-critical service downtime
  - Track "perceived downtime" (impact on actual users)
- **Success Indicator**: System is reliable with rare incidents
- **Additional Metrics**: 
  - Mean Time To Recovery (MTTR): < 30 minutes average
  - Incident frequency trend (should decrease over time)

**Auto-Healing Capability:**
- **Metric**: Percentage of issues resolved automatically
- **Definition**: Auto-healing = resolution without human intervention (beyond automated scripts/monitoring)
- **Issue Categories**:
  - Service crashes/restarts: Auto-restart via Docker/systemd
  - Disk space alerts: Auto-cleanup of temporary files, old logs
  - Memory pressure: Auto-restart of memory-intensive services
  - Network connectivity: Auto-reconnection, failover
- **Target**: > 70% of common issues resolved automatically
- **Measurement**: 
  - Track incidents that self-resolve vs require manual intervention
  - Categorize by issue type
  - Track average auto-healing resolution time
- **Success Indicator**: System maintains itself with minimal oversight
- **Additional Metric**: Average time for auto-healing resolution: < 5 minutes

#### For Non-Technical Users (Graphic Designer & Family)

**Storage Adoption:**
- **Metric**: Total volume of data stored
- **Target**: 
  - Graphic Designer: > 500GB within 3 months
  - Family: > 200GB total within 6 months
- **Measurement**: Track storage usage per user and total
- **Success Indicator**: Users migrate data from cloud services to self-hosted

**Usage Frequency:**
- **Metric**: Active usage days per month
- **Target**: 
  - Graphic Designer: > 20 days/month (daily usage)
  - Family: > 10 days/month (regular usage)
- **Measurement**: Track login/access frequency per user
- **Success Indicator**: System becomes part of daily/regular workflow

**User Satisfaction:**
- **Metric**: User-reported satisfaction and continued usage
- **Target**: > 80% of non-technical users report satisfaction and continue using system
- **Measurement**: Periodic user feedback surveys
- **Success Indicator**: Users prefer self-hosted solution over cloud alternatives

**User Experience Quality:**
- **Metric**: Task completion efficiency and user frustration
- **Targets**:
  - Task completion time: < 2x time compared to cloud alternatives
  - User abandonment rate: < 10% (users who stop using system)
  - Net Promoter Score (NPS): > 50 (users would recommend to others)
- **Measurement**: 
  - Track time to complete common tasks (upload file, share document, access photos)
  - Monitor user drop-off rates
  - Quarterly satisfaction surveys with NPS
- **Success Indicator**: Users find system as easy or easier than cloud alternatives

**User Value Perception:**
- **Metric**: Qualitative feedback on value and pain points
- **Target**: > 80% of users report system meets or exceeds expectations
- **Measurement**: 
  - Quarterly qualitative interviews
  - Feedback collection on pain points and improvements
  - Track workarounds users develop (indicates UX issues)
- **Success Indicator**: Users actively prefer self-hosted solution

### Technical Performance Metrics

**Upload/Download Speed:**
- **Metric**: File transfer speeds (upload and download)
- **Target**: 
  - Local network: > 100 MB/s for large files
  - Remote access: > 10 MB/s (limited by internet connection)
- **Measurement**: Track transfer speeds for typical file sizes (design files, media)
- **Success Indicator**: Fast enough for daily workflows without frustration

**System Availability:**
- **Metric**: Uptime percentage during active hours
- **Target**: > 99% uptime during defined active hours (not including scheduled maintenance)
- **Measurement**: Monitor service availability and track downtime
- **Success Indicator**: Services available when users need them

**Performance Under Load:**
- **Metric**: Response time and performance with multiple concurrent users
- **Target**: < 2s page load time, < 5s for large file operations
- **Measurement**: Monitor response times under typical usage patterns
- **Success Indicator**: System performs well with all users active

### Security Metrics

**Security is a critical requirement for the homelab, ensuring protection of personal and professional data, maintaining privacy, and preventing unauthorized access. All security metrics are mandatory for success.**

**Vulnerability Management:**
- **Metric**: Number and severity of unpatched vulnerabilities
- **Targets**:
  - Zero critical vulnerabilities
  - < 5 medium vulnerabilities
  - All vulnerabilities patched within SLA (7 days for critical, 30 days for others)
- **Measurement**: Automated vulnerability scanning (monthly), manual security reviews (quarterly)
- **Success Indicator**: System remains secure with minimal exposure to known vulnerabilities

**Security Incident Management:**
- **Metric**: Number and severity of security incidents
- **Targets**:
  - < 2 security incidents per year
  - Zero data breaches
  - < 1 hour to detect incidents
  - < 4 hours to contain incidents
- **Measurement**: Security event monitoring, incident logs, response time tracking
- **Success Indicator**: Proactive security with rapid incident response

**Security Compliance:**
- **Metric**: Adherence to security best practices checklist
- **Target**: 100% compliance with security standards
- **Security Standards Include**:
  - Firewall configured and active
  - VPN required for all remote access
  - All services behind reverse proxy with authentication
  - 2FA enabled for critical services
  - Regular automated security updates
  - Security event logging and monitoring
  - Encrypted backups (at rest and in transit)
  - Network segmentation
  - Strong password policies enforced
  - Access control and audit logs
- **Measurement**: Monthly compliance checklist review
- **Success Indicator**: Comprehensive security posture maintained

**Data Protection:**
- **Metric**: Encryption and access control for sensitive data
- **Targets**:
  - 100% of sensitive data encrypted at rest
  - 100% of data in transit encrypted (HTTPS/TLS)
  - 100% of backups encrypted
  - Access logs maintained for all sensitive data access
- **Measurement**: Encryption verification, access log audits
- **Success Indicator**: Data protected from unauthorized access

**Security Update Compliance:**
- **Metric**: Timeliness of security updates
- **Target**: 
  - 100% of critical security updates applied within 7 days
  - 100% of all security updates applied within 30 days
- **Measurement**: Track update deployment time, compliance monitoring
- **Success Indicator**: System stays current with security patches

**Security Monitoring:**
- **Metric**: Coverage and effectiveness of security monitoring
- **Target**: 
  - 100% of services monitored for security events
  - Automated alerts configured for security incidents
  - **Mobile Push Notifications**: Immediate push notifications to phone for security incidents
  - Security logs reviewed monthly
- **Critical Security Alerts** (trigger mobile push notifications):
  - **Suspicious Connections**: Unauthorized access attempts, failed login attempts, unusual network activity
  - **Intrusion Detection**: IDS/IPS alerts, firewall blocks, port scan detection
  - **Security Events**: Vulnerability detections, security update failures, certificate expiration
  - **Access Anomalies**: Login from unusual locations, multiple failed authentications
- **Measurement**: Monitoring coverage audit, alert testing, log review tracking, notification delivery success rate
- **Success Indicator**: Proactive security threat detection with immediate notification

**Docker Image Security Scanning:**
- **Metric**: Security inspection of Docker images before deployment
- **Target**: 
  - 100% of Docker images scanned for vulnerabilities before deployment
  - Zero critical vulnerabilities in deployed images
  - Automated scanning integrated into deployment pipeline
  - Block deployment if critical vulnerabilities detected
- **Implementation**:
  - Use security scanning tools (Trivy, Clair, Snyk, or similar)
  - Pre-deployment scanning in CI/CD or deployment process
  - Vulnerability database updates before scanning
  - Automated blocking of images with critical vulnerabilities
  - Reporting of vulnerabilities found (with severity levels)
- **Measurement**: 
  - Track scanning coverage (100% target)
  - Track vulnerabilities found and resolved
  - Track deployment blocks due to security issues
- **Success Indicator**: Only secure, verified Docker images deployed to production

### Business Objectives

#### Primary Objective: Cost Efficiency

**Cloud Service Cost Avoidance:**
- **Metric**: Estimated monthly cost if using equivalent cloud services
- **Calculation**: 
  - Google Drive (2TB): ~$10/month
  - Netflix: ~$15/month
  - iCloud/Photo storage: ~$10/month
  - Additional cloud services: ~$20/month
  - **Total Estimated**: ~$55/month = ~$660/year
- **Target**: Demonstrate cost savings of > $500/year vs cloud alternatives
- **Measurement**: Track equivalent cloud service costs for features used
- **Success Indicator**: Homelab provides equivalent or better services at lower cost

**Total Cost of Ownership:**
- **Metric**: Total cost (hardware + electricity + maintenance time)
- **Target**: Total cost < $1000/year including hardware amortization (after initial setup)
- **Calculation - Recurring Costs**:
  - Hardware (amortized over 5 years): ~$200/year
  - Electricity (measured, not estimated): ~$150/year (target: measure actual consumption)
  - Maintenance time (valued at $50/hour): ~$200/year (< 2 hours/week)
  - **Total Recurring**: ~$550/year
- **Initial Setup Costs** (one-time, first month):
  - Initial setup time (40+ hours): ~$2000 (one-time investment)
  - Learning and documentation: ~$500 (one-time)
  - **Total Initial**: ~$2500 (amortized over 5 years = $500/year for first 5 years)
- **Success Indicator**: Lower total cost than cloud subscriptions while providing more control
- **Cost Tracking**: Use actual electricity measurements, not estimates

#### Secondary Objective: Independence from GAFAM

**Service Replacement Rate:**
- **Metric**: Percentage of cloud services replaced by self-hosted alternatives
- **Target**: > 80% of identified cloud services replaced within 6 months
- **Measurement**: Track migration from Google Drive, Netflix, photo services to self-hosted
- **Success Indicator**: Minimal reliance on external cloud services

**Data Sovereignty:**
- **Metric**: Percentage of personal/professional data stored self-hosted
- **Target**: > 90% of critical data stored self-hosted within 6 months
- **Measurement**: Track data migration and storage location
- **Success Indicator**: Complete control over critical data

### Key Performance Indicators (KPIs)

**KPI 1: Service Addition Time**
- **Current**: N/A (baseline to be established)
- **Target**: < 15 minutes
- **Frequency**: Track per service addition
- **Owner**: Technical Administrator

**KPI 2: Weekly Operational Time**
- **Current**: N/A (baseline to be established)
- **Target**: < 2 hours/week
- **Frequency**: Weekly tracking
- **Owner**: Technical Administrator

**KPI 3: Monthly Downtime**
- **Current**: N/A (baseline to be established)
- **Target**: < 4 hours/month
- **Frequency**: Monthly tracking
- **Owner**: Technical Administrator

**KPI 4: Storage Adoption (Non-Technical Users)**
- **Current**: 0GB
- **Target**: > 700GB total (500GB designer + 200GB family) within 6 months
- **Frequency**: Monthly tracking
- **Owner**: All Users

**KPI 5: Usage Frequency (Non-Technical Users)**
- **Current**: 0 days/month
- **Target**: 
  - Graphic Designer: > 20 days/month
  - Family: > 10 days/month
- **Frequency**: Monthly tracking
- **Owner**: Individual Users

**KPI 6: Cost Avoidance**
- **Current**: $0 (no cloud services currently)
- **Target**: Demonstrate > $500/year savings vs equivalent cloud services
- **Frequency**: Quarterly calculation
- **Owner**: Technical Administrator

**KPI 7: File Transfer Speed**
- **Current**: N/A (baseline to be established)
- **Target**: 
  - Local: > 100 MB/s
  - Remote: > 10 MB/s
- **Frequency**: Periodic testing
- **Owner**: Technical Administrator

**KPI 8: Auto-Healing Rate**
- **Current**: 0% (baseline to be established)
- **Target**: > 70% of common issues resolved automatically
- **Frequency**: Monthly tracking
- **Owner**: System Monitoring

**KPI 9: Infrastructure Complexity**
- **Current**: 0 services (baseline)
- **Target**: Complexity growth rate < 20% per quarter (measured by number of services, dependencies, configuration complexity)
- **Frequency**: Quarterly tracking
- **Owner**: Technical Administrator
- **Purpose**: Track technical debt and maintainability over time

**KPI 10: Security Posture (Enhanced)**
- **Current**: N/A (baseline to be established)
- **Targets**: 
  - **Vulnerability Management**: Zero unpatched critical vulnerabilities, < 5 medium vulnerabilities
  - **Docker Image Security**: 100% of Docker images scanned before deployment, zero critical vulnerabilities in deployed images
  - **Security Incidents**: < 2 security incidents per year, zero data breaches
  - **Update Compliance**: 100% of critical security updates applied within 7 days, 100% of all updates within 30 days
  - **Access Control**: 100% of services behind authentication, 100% of external access via VPN
  - **Security Monitoring**: 100% of services monitored for security events, automated alerts configured
  - **Backup Security**: 100% of backups encrypted, tested restoration procedures
- **Frequency**: 
  - Pre-deployment: Docker image security scanning (for every image deployment)
  - Monthly: Vulnerability scans, security update compliance check
  - Quarterly: Security audit, access control review, penetration testing (optional)
  - Continuous: Security event monitoring and alerting
- **Owner**: Technical Administrator
- **Purpose**: Ensure comprehensive security across all aspects of the homelab

**KPI 21: Security Compliance Rate**
- **Current**: N/A (baseline to be established)
- **Target**: 100% compliance with security best practices checklist
- **Security Checklist Items**:
  - Firewall configured and active
  - VPN required for remote access
  - All services behind reverse proxy with authentication
  - 2FA enabled for critical services
  - Regular security updates automated
  - Logs monitored for security events
  - Backups encrypted and tested
  - Network segmentation implemented
  - Strong passwords enforced
  - Security documentation up to date
- **Frequency**: Monthly compliance check
- **Owner**: Technical Administrator
- **Purpose**: Measure adherence to security standards

**KPI 22: Security Incident Response Time**
- **Current**: N/A (baseline to be established)
- **Target**: < 1 hour to detect, < 4 hours to contain security incidents
- **Frequency**: Track per security incident
- **Owner**: Technical Administrator
- **Purpose**: Measure security incident response effectiveness

**KPI 23: Data Protection Compliance**
- **Current**: N/A (baseline to be established)
- **Target**: 
  - 100% of sensitive data encrypted at rest
  - 100% of data in transit encrypted (HTTPS/TLS)
  - 100% of backups encrypted
  - Access logs maintained for all sensitive data access
- **Frequency**: Monthly audit
- **Owner**: Technical Administrator
- **Purpose**: Ensure data protection and privacy compliance

**KPI 24: Critical Alert Notification Effectiveness**
- **Current**: N/A (baseline to be established)
- **Target**: 
  - 100% of critical alerts successfully delivered to mobile phone
  - < 2 minutes average time from incident to notification
  - < 5% false positive rate for critical alerts
  - 100% notification delivery success rate (no failed notifications)
- **Frequency**: Track per critical alert
- **Owner**: Technical Administrator
- **Purpose**: Ensure critical incidents are immediately communicated, enabling rapid response
- **Measurement**: 
  - Track notification delivery success/failure
  - Measure time from incident detection to notification
  - Monitor false positive rate
  - Alert on notification service failures

**KPI 11: User Satisfaction (NPS)**
- **Current**: N/A (baseline to be established)
- **Target**: Net Promoter Score > 50
- **Frequency**: Quarterly surveys
- **Owner**: All Users

**KPI 12: User Abandonment Rate**
- **Current**: 0% (baseline)
- **Target**: < 10% of users stop using system within 6 months
- **Frequency**: Monthly tracking
- **Owner**: All Users

**KPI 13: Scalability Metric**
- **Current**: 2 primary users (baseline)
- **Target**: Time to add new user < 15 minutes, time to add new service < 15 minutes (recurrent)
- **Frequency**: Track per addition
- **Owner**: Technical Administrator
- **Purpose**: Measure ease of scaling (users and services)

**KPI 14: Time to First Value (TTFV)**
- **Current**: N/A (baseline to be established)
- **Target**: < 1 week from infrastructure setup to first usable service
- **Frequency**: Track once at project start
- **Owner**: Technical Administrator
- **Purpose**: Measure how quickly the homelab delivers initial value - critical for early validation

**KPI 15: Service Deployment Rate**
- **Current**: 0 services/month (baseline)
- **Target**: Average > 2 services deployed per month over 6 months
- **Frequency**: Monthly tracking
- **Owner**: Technical Administrator
- **Purpose**: Measure progress toward functional completeness

**KPI 16: Service Deployment Success Rate**
- **Current**: N/A (baseline to be established)
- **Target**: > 90% of service deployments successful on first attempt
- **Frequency**: Track per deployment
- **Owner**: Technical Administrator
- **Purpose**: Measure deployment quality - failures increase operational time

**KPI 17: Operational Time Trend**
- **Current**: N/A (baseline to be established in month 1)
- **Target**: 20% reduction in operational time per quarter
- **Frequency**: Quarterly trend analysis
- **Owner**: Technical Administrator
- **Purpose**: Measure improvement in efficiency over time - system should become easier to maintain

**KPI 18: Manual Intervention Rate**
- **Current**: N/A (baseline to be established)
- **Target**: < 30% of incidents require manual intervention
- **Frequency**: Monthly tracking
- **Owner**: Technical Administrator
- **Purpose**: Directly measures "sans temps d'intervention majeur" - critical success factor

**KPI 19: Cost per Service**
- **Current**: N/A (baseline to be established)
- **Target**: < $100/service/year (amortized cost)
- **Frequency**: Quarterly calculation
- **Owner**: Technical Administrator
- **Purpose**: Measure cost efficiency per functionality - helps optimize spending

**KPI 20: ROI Timeline**
- **Current**: N/A (baseline to be established)
- **Target**: Positive ROI within 12 months (cost savings > total investment)
- **Frequency**: Quarterly calculation
- **Owner**: Technical Administrator
- **Purpose**: Validate "coût réduit" objective - when does investment pay off?

### Success Criteria (6-Month Horizon)

**Overall Success Definition:**
The homelab will be considered successful in 6 months if it meets all of the following criteria:

1. ✅ **Functional Completeness**: All identified needs are met (storage, media, gaming, services)
2. ✅ **Operational Efficiency**: < 2 hours/week active management, < 15 minutes to add services (recurrent), operational time trending downward
3. ✅ **Reliability**: < 4 hours/month downtime, > 70% auto-healing rate, < 30% manual intervention rate
4. ✅ **User Adoption**: Non-technical users actively using system (> 20 days/month for designer, > 10 days/month for family), TTFV < 1 week
5. ✅ **Cost Efficiency**: Total cost < $1000/year, demonstrating > $500/year savings vs cloud, positive ROI within 12 months
6. ✅ **Performance**: Fast file transfers (> 100 MB/s local, > 10 MB/s remote)
7. ✅ **Data Sovereignty**: > 90% of critical data stored self-hosted
8. ✅ **GAFAM Independence**: > 80% of cloud services replaced
9. ✅ **Security**: Zero critical vulnerabilities, < 2 security incidents/year, 100% security compliance, all data encrypted, comprehensive security monitoring
10. ✅ **Deployment Quality**: > 90% service deployment success rate, > 2 services/month deployment rate

**Measurement Framework:**
- **Weekly**: Operational time, service additions, incident tracking, security event monitoring
- **Monthly**: 
  - Downtime (total and critical), storage adoption, usage frequency, auto-healing rate
  - Infrastructure complexity, security posture, security compliance rate
  - Service deployment rate and success rate, manual intervention rate
  - Security vulnerability scans, update compliance
- **Quarterly**: 
  - Cost analysis (with actual measurements), ROI timeline, cost per service
  - User satisfaction surveys (NPS), user abandonment rate, scalability metrics
  - Operational time trend analysis, security audit
- **6-Month Review**: Comprehensive success criteria evaluation, lessons learned, metric refinement, security posture assessment

**Measurement Tools & Methods:**
- **Time Tracking**: Use time-tracking tools or detailed logs for operational time
- **Monitoring**: Automated monitoring for downtime, performance, auto-healing, security events
- **Alerting**: Alertmanager (Prometheus) or similar for alert routing, push notification services (Gotify, Ntfy, Apprise, Telegram) for mobile notifications
- **Cost Tracking**: Actual electricity measurements (smart plugs/meters), not estimates
- **User Feedback**: Structured surveys (NPS) + qualitative interviews
- **Security**: 
  - Automated vulnerability scanning (Trivy, Clair, or similar)
  - Security update tracking and compliance monitoring
  - Security event logging and alerting (SIEM-like monitoring)
  - Access control audit logs
  - Backup encryption verification
  - Network security monitoring (firewall logs, intrusion detection)
- **Complexity**: Version-controlled infrastructure metrics (service count, dependency graph)
- **Deployment Tracking**: Version control for infrastructure changes, deployment logs
- **ROI Calculation**: Track initial investment, recurring costs, and equivalent cloud service costs

---

### Metric Prioritization & Optimization Strategy

Based on comparative analysis, the **Balanced Approach (23 KPIs)** has been selected as optimal. To maximize value while minimizing effort, metrics are organized into priority tiers with automation recommendations.

#### Tier 1: Critical Metrics (10 KPIs) - Monthly Tracking

**These metrics directly measure core success criteria and should be tracked monthly with automated monitoring:**

1. **KPI 2: Weekly Operational Time** - Critical for "sans temps d'intervention majeur"
2. **KPI 3: Monthly Downtime** - Critical for reliability
3. **KPI 4: Storage Adoption** - Critical for user adoption
4. **KPI 6: Cost Avoidance** - Critical for "coût réduit"
5. **KPI 8: Auto-Healing Rate** - Critical for operational efficiency
6. **KPI 10: Security Posture** - Critical for security requirement
7. **KPI 14: Time to First Value (TTFV)** - Critical for early validation (track once)
8. **KPI 15: Service Deployment Rate** - Critical for functional completeness
9. **KPI 16: Service Deployment Success Rate** - Critical for quality
10. **KPI 18: Manual Intervention Rate** - Critical for "sans temps d'intervention majeur"

**Automation Priority**: HIGH - Automate 100% of these metrics
- Automated monitoring dashboards (Grafana/Prometheus)
- Automated alerts for threshold violations
- Automated reporting (monthly summaries)

#### Tier 2: Important Metrics (8 KPIs) - Quarterly Tracking

**These metrics provide valuable insights but don't require monthly tracking:**

1. **KPI 5: Usage Frequency** - Important for user adoption validation
2. **KPI 7: File Transfer Speed** - Important for performance validation
3. **KPI 9: Infrastructure Complexity** - Important for technical debt tracking
4. **KPI 11: User Satisfaction (NPS)** - Important for user experience
5. **KPI 12: User Abandonment Rate** - Important for adoption health
6. **KPI 17: Operational Time Trend** - Important for efficiency improvement
7. **KPI 19: Cost per Service** - Important for cost optimization
8. **KPI 20: ROI Timeline** - Important for cost validation

**Automation Priority**: MEDIUM - Automate 70% of these metrics
- Quarterly automated reports
- Trend analysis dashboards
- Manual collection for user surveys (NPS)

#### Tier 3: Supplementary Metrics (5 KPIs) - On-Demand Tracking

**These metrics provide additional insights but can be tracked as needed:**

1. **KPI 1: Service Addition Time** - Useful for optimization, track when adding services
2. **KPI 13: Scalability Metric** - Useful when scaling, track per addition
3. **KPI 21: Security Compliance Rate** - Useful for security audits, track monthly
4. **KPI 22: Security Incident Response Time** - Track per incident
5. **KPI 23: Data Protection Compliance** - Useful for audits, track monthly
6. **KPI 24: Critical Alert Notification Effectiveness** - Track per critical alert, measure notification delivery and response time

**Automation Priority**: LOW - Automate 50% of these metrics
- On-demand dashboards
- Manual tracking when relevant
- Automated alerts for security metrics

#### Automation Recommendations

**High-Priority Automation (Tier 1 Metrics):**

1. **Monitoring Stack**:
   - Prometheus for metrics collection
   - Grafana for visualization and dashboards
   - Alertmanager for automated alerts

2. **Automated Metrics Collection**:
   - Operational time: Time-tracking integration or log analysis
   - Downtime: Uptime monitoring (UptimeRobot, Pingdom, or self-hosted)
   - Storage adoption: Filesystem monitoring (automated scripts)
   - Auto-healing: Service health monitoring with restart tracking
   - Deployment metrics: CI/CD pipeline integration or deployment logs

3. **Automated Reporting**:
   - Monthly dashboard exports
   - Automated email summaries
   - Slack/notification alerts for threshold violations

**Medium-Priority Automation (Tier 2 Metrics):**

1. **Quarterly Analysis**:
   - Automated trend analysis scripts
   - Cost calculation automation
   - User survey automation (forms + analysis)

2. **Dashboards**:
   - Quarterly review dashboards
   - Historical trend visualizations

**Low-Priority Automation (Tier 3 Metrics):**

1. **On-Demand Tools**:
   - Security compliance checklists (automated verification)
   - Incident tracking templates
   - Manual data entry for service addition times

#### Metric Review & Refinement Plan

**Quarterly Review Process:**

1. **Review Metric Value** (Every Quarter):
   - Which metrics drove decisions this quarter?
   - Which metrics were not used or reviewed?
   - Which metrics provided unexpected insights?

2. **Evaluate Metric Quality**:
   - Are metrics still aligned with objectives?
   - Are targets still realistic and relevant?
   - Are measurement methods still accurate?

3. **Optimize Metric Set**:
   - Remove metrics that don't drive decisions (after 2 quarters of non-use)
   - Add metrics if gaps are identified
   - Adjust targets based on actual performance

4. **Review Automation**:
   - Identify metrics that could be better automated
   - Improve automation for high-effort metrics
   - Simplify measurement methods

**Annual Comprehensive Review:**

1. **Strategic Alignment**:
   - Do metrics still align with 6-month success criteria?
   - Are new success criteria needed?
   - Are objectives still relevant?

2. **Metric Framework Evolution**:
   - Update metric definitions if needed
   - Refine measurement methods
   - Update automation tools and processes

3. **Lessons Learned**:
   - Document what worked well
   - Document what didn't work
   - Share insights for future improvements

#### Implementation Roadmap

**Month 1-2: Setup & Baseline**
- Set up monitoring infrastructure (Prometheus, Grafana)
- Configure automated collection for Tier 1 metrics
- Establish baseline measurements for all metrics
- Create initial dashboards

**Month 3: Refinement**
- Review first month of data
- Adjust automation and measurement methods
- Add Tier 2 metric automation
- Refine dashboards

**Month 4-6: Optimization**
- Quarterly review of all metrics
- Remove non-actionable metrics
- Optimize automation
- Refine targets based on actual performance

**Ongoing: Continuous Improvement**
- Monthly review of Tier 1 metrics
- Quarterly review of all metrics
- Annual comprehensive review
- Continuous automation improvements

---

### Critical Alerting & Notification System

**Overview**: Mobile push notification system for immediate alerting on critical incidents, ensuring rapid response to problems even when away from the homelab.

#### Notification Service Architecture

**Service Options**:
- **Gotify**: Self-hosted push notification service (can be on VPS for reliability)
- **Ntfy**: Simple HTTP-based pub/sub notification service
- **Apprise**: Unified notification library supporting multiple backends
- **Telegram Bot**: Telegram bot for notifications (simple, reliable)
- **Pushover**: Commercial service with mobile apps

**Recommended**: Gotify or Ntfy (self-hosted, simple, reliable)

#### Critical Alert Categories

**1. Disk Failure Alerts**:
- **SMART Errors**: Disk health warnings, predictive failure alerts
- **Disk Space Critical**: < 10% free space on any disk
- **Disk I/O Errors**: Read/write errors, disk performance degradation
- **RAID Degradation**: Array degradation warnings (if applicable)
- **Priority**: CRITICAL - Immediate push notification

**2. Service Downtime During Active Hours**:
- **Active Hours Definition**: Configurable schedule (e.g., 8 AM - 11 PM)
- **Critical Services**: Nextcloud, monitoring services down at any time
- **Non-Critical Services**: Down during active hours only
- **Multiple Service Failures**: Multiple services down simultaneously
- **Service Restart Failures**: Service unable to restart after failure
- **Priority**: CRITICAL during active hours, WARNING during inactive hours

**3. Suspicious Connections & Security Events**:
- **Unauthorized Access Attempts**: Failed authentication, unauthorized connection attempts
- **Multiple Failed Logins**: Brute force attack detection (> 5 failed attempts)
- **Unusual Network Activity**: Port scans, connection attempts from unknown IPs
- **Intrusion Detection**: IDS/IPS alerts, firewall blocks of suspicious traffic
- **VPN Anomalies**: VPN connection from unusual location, multiple concurrent connections
- **Priority**: CRITICAL - Immediate push notification

**4. Security Incidents**:
- **Critical Vulnerability Detections**: High-severity vulnerabilities found
- **Security Update Failures**: Failed security patch deployments
- **Certificate Expiration**: SSL/TLS certificates expiring soon (< 7 days)
- **Docker Image Security Failures**: Critical vulnerabilities in images before deployment
- **Unauthorized Configuration Changes**: Unauthorized changes to security settings
- **Priority**: CRITICAL - Immediate push notification

**5. System Health Critical**:
- **Backup Failures**: Critical backup job failures
- **High Resource Usage**: CPU > 90% or RAM > 95% for extended period
- **Network Connectivity Issues**: Loss of Internet connectivity, VPN tunnel failures
- **Critical Service Health Failures**: Health checks failing for critical services
- **Priority**: CRITICAL for backup failures, WARNING for resource usage

#### Alert Routing & Prioritization

**Alert Routing**:
- **Prometheus Alertmanager**: Routes alerts based on severity and labels
- **Notification Channels**: 
  - Critical alerts → Mobile push notification (immediate)
  - Warnings → Digest notification or delayed push
  - Info → Logged only, no push
- **Alert Grouping**: Group related alerts to avoid notification spam
- **Alert Suppression**: Suppress alerts during maintenance windows

**Alert Acknowledgment**:
- Mobile app allows acknowledging alerts
- Alert escalation if not acknowledged within timeframe (e.g., 15 minutes)
- Alert history and tracking
- Alert resolution tracking

#### Notification Service Deployment

**Option 1: VPS Deployment (Recommended)**:
- Deploy notification service on Oracle Cloud VPS
- **Benefits**: Notifications work even if homelab is down
- **Architecture**: Homelab alerts → VPN tunnel → VPS notification service → Mobile phone

**Option 2: Homelab Deployment**:
- Deploy notification service on homelab
- **Benefits**: Simpler setup, no VPN dependency
- **Limitation**: Notifications may fail if homelab is down

**Recommended**: VPS deployment for maximum reliability

#### Mobile App Configuration

**Mobile App Setup**:
- Install mobile app for chosen notification service (Gotify app, Ntfy app, Telegram, etc.)
- Configure authentication and connection
- Test notification delivery
- Configure notification sounds and vibration for critical alerts
- Set up notification categories and priorities

**Notification Preferences**:
- Critical alerts: Sound + vibration + persistent notification
- Warnings: Sound only
- Info: Silent notification

#### Alert Rules Configuration

**Example Alert Rules** (Prometheus/Alertmanager):

```yaml
# Disk Failure Alert
- alert: DiskFailure
  expr: disk_smart_errors > 0
  for: 0m
  labels:
    severity: critical
  annotations:
    summary: "Disk failure detected"
    description: "SMART error on disk {{ $labels.device }}"

# Service Down During Active Hours
- alert: ServiceDownActiveHours
  expr: up == 0 AND hour() >= 8 AND hour() < 23
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Service down during active hours"
    description: "{{ $labels.job }} is down"

# Suspicious Connection
- alert: SuspiciousConnection
  expr: rate(failed_login_attempts[5m]) > 5
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Suspicious connection detected"
    description: "Multiple failed login attempts from {{ $labels.source_ip }}"
```

#### Success Metrics

**Notification Effectiveness**:
- **Delivery Success Rate**: 100% of critical alerts successfully delivered
- **Notification Latency**: < 2 minutes from incident to notification
- **False Positive Rate**: < 5% false positive notifications
- **Response Time**: Time from notification to acknowledgment/action

**Monitoring**:
- Track notification delivery success/failure
- Monitor notification service health
- Alert on notification service failures
- Review and tune alert rules to reduce false positives

---

## MVP Scope

### Core Features (MVP Phase 1 - Months 1-2)

**The MVP focuses on establishing the foundational infrastructure and delivering the first critical service (Nextcloud) to validate the approach and provide immediate value.**

#### Infrastructure Foundation

1. **Base Operating System & Orchestration**
   - Ubuntu Server installation and configuration
   - Docker and Docker Compose setup
   - QEMU/KVM installation (for future gaming VMs)
   - ZFS filesystem configuration for storage
   - Basic network configuration
   - **IP KVM Setup**: KVM dongle/IP KVM device configuration for remote server management and out-of-band access

2. **Core Services**
   - **Nextcloud**: Primary storage solution replacing Google Drive
     - User accounts for developer and graphic designer
     - Mobile app setup and configuration
     - Basic file sharing capabilities
     - Initial data migration from existing storage

3. **Security Foundation**
   - Firewall configuration (ufw/iptables)
   - VPN setup (WireGuard or OpenVPN) for remote access
   - Reverse proxy (Traefik) with automatic HTTPS (Let's Encrypt)
   - Basic access control and authentication
   - **Docker Image Security Scanning**: Pre-deployment security scanning of Docker images (Trivy, Clair, or similar)
   - Security update automation
   - **Automatic Updates**: Automatic deployment of updates when new versions are available

4. **Backup & Recovery**
   - Basic backup strategy implementation (3-2-1 rule)
   - **Selective Critical Backup**: System to tag folders/files as "critical" for priority cloud backup
   - **Cloud Backup Integration**: Hetzner Storage (or compatible) integration for critical data backup
   - **Encrypted Backups**: All cloud backups encrypted with user-provided encryption key
   - **Optimized Backup Strategy**: Compression and deduplication to minimize storage costs and transfer volume
   - Automated daily backups of critical data to cloud, weekly backups of all user data locally
   - Backup verification procedures
   - Disaster recovery documentation

5. **Monitoring & Observability**
   - Prometheus and Grafana setup
   - Basic system monitoring (CPU, RAM, disk, network)
   - Service health monitoring
   - **Alerting System with Mobile Notifications**:
     - Alertmanager configuration for alert routing
     - Push notification service setup (Gotify, Ntfy, Apprise, or Telegram bot)
     - **Critical Alert Categories**:
       - **Disk Failure**: SMART errors, disk health degradation, disk space critical
       - **Service Downtime**: Service down during active hours (configurable schedule)
       - **Suspicious Connections**: Unauthorized access attempts, failed login attempts, unusual network activity
       - **Security Incidents**: Vulnerability detections, security event anomalies
       - **System Health**: High CPU/RAM usage, network issues, backup failures
     - Alert rules configured for immediate notification on critical events
     - Alert escalation for unacknowledged critical alerts
   - Automated alerts for critical issues
   - Initial dashboard creation

6. **Infrastructure as Code**
   - Docker Compose files for all services
   - Ansible playbooks for system configuration (optional but recommended)
   - Version control setup (Git repository)
   - Documentation of infrastructure setup

#### MVP Success Criteria (Phase 1)

**The MVP Phase 1 is considered successful when:**

1. ✅ **Infrastructure Operational**: Base system running with Docker, ZFS, and monitoring
2. ✅ **First Service Deployed**: Nextcloud fully operational and accessible
3. ✅ **Security Baseline**: Firewall, VPN, and reverse proxy configured and tested
4. ✅ **Backup Working**: Automated backups running and verified
5. ✅ **Monitoring Active**: Basic monitoring and alerting functional, mobile push notifications configured for critical alerts
6. ✅ **Time to First Value**: < 1 week from setup start to first usable service (Nextcloud)
7. ✅ **User Adoption**: Graphic designer successfully using Nextcloud for daily file management
8. ✅ **Operational Time**: < 4 hours/week during setup phase, trending toward < 2 hours/week

### Phase 2 Features (Months 3-4)

**Building on MVP foundation, adding essential services:**

1. **Pi-hole**: Network-wide ad blocking and DNS filtering
2. **Immich**: Photo management and sharing (replacing iCloud Photos)
3. **Jellyfin + arr* Stack**: Media server and automation
   - Jellyfin for media streaming
   - Complete arr* suite: Radarr (movies), Sonarr (TV series), Prowlarr (indexer manager), Lidarr (music), Readarr (books), Bazarr (subtitles)
   - Deluge (torrent client) with Gluetun (VPN integration) for secure downloads
   - Overseerr for media requests and management
   - Byparr for Cloudflare bypass (if needed)
   - **Reference Implementation**: [belginux.com - Installer la suite *arr et Gluetun avec Docker](https://belginux.com/installer-la-suite-arr-et-gluetun-avec-docker/) provides comprehensive setup guide
   - All services configured via Docker Compose with VPN integration for privacy

4. **Enhanced Monitoring & Critical Alerting**: 
   - Expanded metrics collection
   - Security monitoring and alerting
   - **Mobile Push Notification System**: 
     - Push notification service deployment (Gotify, Ntfy, Apprise, or Telegram bot)
     - Mobile app installation and configuration
     - **Critical Alert Configuration**:
       - **Disk Failure Alerts**: SMART errors, disk health degradation, critical disk space
       - **Service Downtime Alerts**: Service down during active hours (configurable schedule, e.g., 8 AM - 11 PM)
       - **Suspicious Connection Alerts**: Unauthorized access attempts, failed logins, unusual network activity
       - **Security Incident Alerts**: Intrusion detection, vulnerability detections, security anomalies
       - **System Health Alerts**: Critical resource exhaustion, backup failures
     - Alert routing and prioritization (critical = immediate push, warnings = digest)
     - Alert acknowledgment and escalation
   - Performance optimization

5. **Oracle Cloud VPS Setup** (Hybrid Architecture):
   - Oracle Cloud Always Free VPS deployment
   - VPN server setup (WireGuard) on VPS
   - Secure VPN tunnel configuration between VPS and homelab
   - **Public Services on VPS**:
     - Uptime Kuma (monitoring homelab)
     - Public monitoring dashboards
     - Nextcloud public entry point (for non-technical users)
     - **Push Notification Service**: Gotify, Ntfy, or Apprise (ensures notifications work even if homelab is down)
   - **Security Hardening**: Firewall, Fail2Ban, automatic updates
   - **Reference**: [Oracle Cloud VPS Setup Guide](https://www.it-connect.fr/un-serveur-vps-gratuit-chez-oracle-cloud-ideal-pour-vos-projets-personnels/)

6. **Family Access Setup**: 
   - Account creation for family members
   - Quota management
   - User documentation
   - **Public Access**: Family members access via VPS Nextcloud instance (simpler than VPN)

### Phase 3 Features (Months 5-6)

**Advanced features and optimization:**

1. **Gaming Virtualization**:
   - Windows VM setup for gaming
   - Steam OS VM setup
   - GPU passthrough configuration
   - Remote gaming setup (Parsec, Moonlight, or Steam Remote Play)
   - **IP KVM Integration**: IP KVM access for remote VM management and troubleshooting (especially useful for gaming VMs)

2. **Service Expansion**:
   - Additional self-hosted services based on needs discovered during Phase 1-2
   - Service optimization and performance tuning
   - **VPS Service Expansion**: Additional public services on VPS (website hosting, public APIs if needed)

3. **Advanced Features**:
   - Advanced backup strategies
   - High availability considerations
   - Performance optimization
   - Advanced security hardening

### Out of Scope for MVP

**The following features are explicitly deferred to post-MVP phases:**

1. **Advanced Gaming Features**:
   - Multi-user gaming sessions
   - Advanced GPU virtualization optimizations
   - Gaming-specific network optimizations
   - **Rationale**: Gaming is a secondary use case; storage and services are primary

2. **Enterprise-Grade Features**:
   - Multi-node Kubernetes cluster
   - High availability with failover
   - Advanced load balancing
   - **Rationale**: Single-node homelab doesn't require enterprise features initially

3. **Advanced Automation**:
   - Complex CI/CD pipelines
   - Advanced infrastructure automation beyond Docker Compose
   - **Rationale**: Start simple, add complexity only when needed

4. **External Integrations**:
   - Third-party service integrations beyond core services
   - Advanced API integrations
   - **Rationale**: Focus on core functionality first

5. **Advanced Analytics**:
   - Complex data analytics
   - Advanced reporting beyond basic monitoring
   - **Rationale**: Basic monitoring sufficient for MVP validation

### MVP Success Criteria

**The overall MVP (Phases 1-3) is considered successful when all 6-month success criteria are met:**

1. ✅ **Functional Completeness**: All identified core needs met (storage, media, gaming, services)
2. ✅ **Operational Efficiency**: < 2 hours/week active management, < 15 minutes to add services (recurrent)
3. ✅ **Reliability**: < 4 hours/month downtime, > 70% auto-healing rate
4. ✅ **User Adoption**: Non-technical users actively using system (> 20 days/month)
5. ✅ **Cost Efficiency**: Total cost < $1000/year, demonstrating > $500/year savings
6. ✅ **Security**: Zero critical vulnerabilities, 100% security compliance
7. ✅ **Time to First Value**: < 1 week for first usable service
8. ✅ **Deployment Quality**: > 90% service deployment success rate

**Go/No-Go Decision Points:**

- **After Phase 1 (Month 2)**: Evaluate if infrastructure approach is working, if Nextcloud adoption is successful, if operational time is manageable
- **After Phase 2 (Month 4)**: Evaluate if additional services are adding value, if family adoption is successful, if cost targets are being met
- **After Phase 3 (Month 6)**: Comprehensive evaluation against all 6-month success criteria

### Future Vision (Post-MVP)

**Long-term vision for the homelab (12-24 months):**

1. **Service Expansion**:
   - Additional self-hosted services discovered through use
   - Integration with home automation (Home Assistant)
   - Advanced media processing and automation

2. **Performance Optimization**:
   - Advanced caching strategies
   - CDN integration for remote access
   - Performance tuning for all services

3. **Advanced Security**:
   - Intrusion detection and prevention systems
   - Advanced threat monitoring
   - Security automation and response

4. **Scalability**:
   - Multi-node architecture if needed
   - Advanced load balancing
   - High availability setup

5. **Ecosystem Integration**:
   - Integration with other home systems
   - Advanced automation workflows
   - Cross-service integrations

6. **Community & Sharing**:
   - Documentation and guides for others
   - Open-source contributions
   - Knowledge sharing

**The MVP provides a solid foundation that can evolve into this broader vision as needs and capabilities grow.**

---

## Network Architecture

### Current Network Setup (Phase 0 - Transition Period)

**Current Infrastructure:**
- **Router**: TP-Link Deco 5G (mobile broadband)
- **Limitations**: Basic router, no VLAN support, limited configuration options
- **DNS**: Pi-hole as primary DNS (when deployed)
- **Network**: Flat network, no segmentation

**Transition Strategy:**
- Deploy homelab with basic network configuration
- Prepare for future migration to Cloud Gateway Fiber
- Pi-hole will serve as primary DNS during transition period

### Target Network Architecture (Post-Migration)

**Infrastructure:**
- **Router/Firewall**: Cloud Gateway Fiber (UniFi) - 8Gb symmetric fiber connection
  - **Primary Firewall**: UniFi router handles all firewall functions
  - **Firewall Features**: Stateful firewall, inter-VLAN routing, NAT, port forwarding
  - **Management**: UniFi Controller for firewall rule management
- **Switch**: Managed switch (if needed for additional ports)
- **Access Points**: UniFi APs or compatible APs with VLAN tagging support
- **Wired Connection**: 10Gb Ethernet to salon (gaming setup)

#### VLAN Segmentation Strategy

**VLAN 10: Homelab (Trusted Infrastructure)**
- **Purpose**: Server, services, management
- **Devices**: Homelab server, management interfaces
- **Security**: Highest trust level, full access to other VLANs (controlled)
- **IP Range**: 10.0.10.0/24
- **Services**: All self-hosted services (Nextcloud, Jellyfin, Pi-hole, etc.)
- **Access**: VPN access from Internet, local access from other VLANs (restricted)

**VLAN 20: Principal (Trusted Devices)**
- **Purpose**: Personal devices, work devices, trusted equipment
- **Devices**: Mac, PC, smartphones, tablets, Sonos speakers
- **Security**: Trusted devices, can access homelab services
- **IP Range**: 10.0.20.0/24
- **Access**: Full access to homelab services, Internet access
- **Note**: Sonos on this VLAN for simplicity (multicast support)

**VLAN 30: IoT (Untrusted Devices)**
- **Purpose**: Internet of Things devices, smart home devices
- **Devices**: Smart plugs, sensors, cameras, other IoT devices
- **Security**: Isolated, no access to other VLANs, Internet-only
- **IP Range**: 10.0.30.0/24
- **Access**: Internet only, no inter-VLAN communication
- **Firewall Rules**: Strict egress filtering, no ingress from other VLANs

**VLAN 40: Gaming (High Performance)**
- **Purpose**: Gaming setup in salon
- **Devices**: Gaming PC/console, TV, Moonlight client
- **Security**: Trusted, can access homelab for Moonlight streaming
- **IP Range**: 10.0.40.0/24
- **Connection**: 10Gb Ethernet dedicated link
- **Access**: Access to homelab gaming VMs via Moonlight

**VLAN 50: Guests (Optional)**
- **Purpose**: Guest network access
- **Devices**: Guest devices
- **Security**: Isolated, Internet-only, rate-limited
- **IP Range**: 10.0.50.0/24
- **Access**: Internet only, no access to internal resources

#### DNS Configuration

**Current Setup (Transition Period):**
- **Primary DNS**: Pi-hole (VLAN 10)
- **Fallback DNS**: Cloudflare (1.1.1.1) or Google (8.8.8.8)
- **Configuration**: All VLANs use Pi-hole as primary DNS

**Target Setup (Post-Migration):**
- **Primary DNS**: Cloud Gateway Fiber (UniFi router)
- **Fallback DNS**: Pi-hole (VLAN 10)
- **Rationale**: Router as primary for reliability, Pi-hole as fallback for ad-blocking
- **Configuration**: Router forwards to Pi-hole for ad-blocking, falls back to router if Pi-hole unavailable

#### WiFi Configuration

**Access Points:**
- **Type**: UniFi APs or compatible APs with VLAN tagging support
- **Coverage**: Full apartment coverage via WiFi (no Ethernet in most rooms)
- **SSID Strategy**: 
  - Option A: Single SSID with VLAN tagging based on device authentication
  - Option B: Multiple SSIDs (one per VLAN) - simpler but more SSIDs visible
  - **Recommendation**: Option B for simplicity and security

**SSID Configuration:**
- **SSID-Principal** (VLAN 20): For trusted devices
- **SSID-IoT** (VLAN 30): For IoT devices
- **SSID-Gaming** (VLAN 40): For gaming devices (if WiFi needed)
- **SSID-Guest** (VLAN 50): For guests (optional)

#### VLAN Tagging Risks & Mitigation

**Risks Associated with VLAN Tagging:**

1. **VLAN Hopping Attack**:
   - **Risk**: Attacker on one VLAN could potentially access another VLAN
   - **Mitigation**: 
     - Proper switch configuration (disable dynamic trunking)
     - Access ports configured correctly (no trunking on user ports)
     - Firewall rules between VLANs
     - Regular security audits

2. **Misconfiguration**:
   - **Risk**: Incorrect VLAN tagging could expose devices to wrong network
   - **Mitigation**:
     - Document all VLAN configurations
     - Test VLAN isolation after configuration
     - Use VLAN management tools (UniFi Controller)
     - Regular configuration backups

3. **Multicast/Broadcast Issues**:
   - **Risk**: Some devices (like Sonos) rely on multicast which may not work across VLANs
   - **Mitigation**:
     - Place Sonos on VLAN 20 (Principal) for simplicity
     - Configure IGMP snooping if needed
     - Test multicast functionality after setup

4. **Performance Impact**:
   - **Risk**: VLAN tagging adds overhead, could impact performance
   - **Mitigation**:
     - Use hardware-accelerated switching (UniFi supports this)
     - Monitor network performance
     - 10Gb link for gaming minimizes impact

**Security Best Practices:**
- **Firewall Rules**: Configured on UniFi router - strict inter-VLAN rules (deny by default, allow specific)
- **Firewall Management**: All firewall rules managed via UniFi Controller
- **Access Control**: MAC address filtering for critical VLANs (optional, via UniFi)
- **Monitoring**: Network monitoring via UniFi Controller to detect VLAN hopping attempts
- **Documentation**: Complete network documentation with VLAN assignments and firewall rules
- **Regular Audits**: Quarterly network security audits, review firewall rules

#### Gaming Setup (Moonlight)

**Architecture:**
- **Server Side**: Gaming VMs (Windows/Steam OS) on homelab (VLAN 10)
- **Client Side**: Moonlight client in salon (VLAN 40)
- **Connection**: 10Gb Ethernet dedicated link
- **Protocol**: Moonlight (low-latency streaming protocol)

**Network Requirements:**
- **Latency**: < 5ms between VLAN 10 and VLAN 40
- **Bandwidth**: Sufficient for 4K gaming (recommended: > 100 Mbps)
- **QoS**: Prioritize gaming traffic on 10Gb link
- **Firewall Rules**: Allow Moonlight traffic between VLAN 10 and VLAN 40

**Configuration:**
- Moonlight server on gaming VMs (VLAN 10)
- Moonlight client on gaming device in salon (VLAN 40)
- Firewall rules on UniFi router to allow Moonlight protocol between VLAN 10 and VLAN 40
- Network optimization for low latency (QoS configuration on UniFi router)

#### Network Services Integration

**Pi-hole (VLAN 10):**
- **DNS**: Primary during transition, fallback after migration
- **Access**: Accessible from all VLANs for DNS resolution
- **Firewall**: UniFi router firewall rules allow DNS queries (port 53) from all VLANs to Pi-hole, block management interface from untrusted VLANs

**VPN (VLAN 10):**
- **Service**: WireGuard or OpenVPN on homelab
- **Access**: Internet access required for VPN server (port forwarding configured on UniFi router)
- **Routing**: VPN clients get access to VLAN 10 (homelab) and optionally VLAN 20 (principal) via UniFi router routing rules
- **Security**: Strong authentication, firewall rules on UniFi router prevent VPN access to IoT VLAN
- **Firewall Configuration**: UniFi router handles port forwarding and routing for VPN traffic

**Wake-on-LAN:**
- **Source**: VPN clients or LAN devices (VLAN 20)
- **Target**: Homelab server (VLAN 10)
- **Configuration**: Enable WoL on server, configure UniFi router firewall rules to allow WoL packets (UDP port 9) from authorized sources

#### Network Monitoring

**Monitoring Requirements:**
- **VLAN Traffic**: Monitor traffic between VLANs
- **Security Events**: Detect VLAN hopping attempts
- **Performance**: Monitor latency, bandwidth usage per VLAN
- **Device Tracking**: Track devices on each VLAN

**Tools:**
- **UniFi Controller**: Primary tool for network management, firewall rule management, and monitoring
- **Firewall Management**: All firewall rules configured and managed via UniFi Controller
- **Network Monitoring**: UniFi Controller built-in monitoring + network monitoring tools (Prometheus network exporter)
- **Security Monitoring**: UniFi Controller security features + intrusion detection (optional)

### Network Implementation Phases

**Phase 1 (Current - Transition):**
- Basic network with Deco 5G
- Pi-hole as primary DNS
- Flat network (no VLANs)
- Basic firewall rules

**Phase 2 (Post-Migration):**
- Cloud Gateway Fiber router/firewall setup
- VLAN configuration on UniFi router
- Firewall rules configuration (inter-VLAN, Internet access, port forwarding)
- WiFi APs with VLAN tagging
- Inter-VLAN firewall rules (managed via UniFi Controller)
- DNS migration (router primary, Pi-hole fallback)

**Phase 3 (Optimization):**
- Network performance tuning
- Advanced firewall rules
- Network monitoring setup
- Security hardening

---

## Hybrid Cloud Architecture

### Overview

To minimize exposure of the home network to the Internet while maintaining high availability for critical services, the solution uses a **hybrid architecture** combining:

- **Local Homelab**: Primary infrastructure for internal services, media, gaming, and data storage
- **Oracle Cloud VPS (Always Free)**: Internet-exposed services and high-uptime requirements

**Reference Implementations:**
- [Oracle Cloud Free Tier VPS Setup Guide](https://www.it-connect.fr/un-serveur-vps-gratuit-chez-oracle-cloud-ideal-pour-vos-projets-personnels/) - Comprehensive guide for setting up Oracle Cloud VPS
- [GitHub - Mafyuh/iac](https://github.com/mafyuh/iac) - Example of hybrid homelab + VPS architecture with GitOps
- [Reddit Discussion: VPS vs Homelab](https://www.reddit.com/r/selfhosted/comments/1m3l5r9/do_you_use_a_vpscloud_provider_or_a_homelab_setup/) - Community insights on VPS vs homelab hosting decisions

### Oracle Cloud VPS - Always Free Tier

**Available Resources:**
- **2x AMD VMs**: 1 OCPU, 1GB RAM, 47GB storage each (VM.Standard.E2.1.Micro)
- **ARM VMs**: Up to 4 VMs with more resources (limited hours)
- **200GB Block Storage**
- **20GB Object Storage**
- **10TB Outbound Data Transfer**

**Reference**: [Oracle Cloud Always Free Services](https://www.oracle.com/cloud/free/)

### Service Distribution Strategy

#### Services on Oracle Cloud VPS (Internet-Exposed / High Uptime)

**Rationale**: These services need Internet exposure or require maximum uptime, and don't need direct access to local storage or resources.

1. **Public-Facing Services**:
   - **Website Hosting**: Static sites, portfolio sites, landing pages
   - **Public APIs**: If needed for external integrations
   - **Public Monitoring Dashboards**: Status pages, public uptime monitoring

2. **High-Uptime Services**:
   - **Monitoring & Alerting**: Uptime Kuma, monitoring services for homelab
   - **Reverse Proxy Entry Point**: Traefik or Nginx as public entry point
   - **Nextcloud Public Access**: Public-facing Nextcloud instance (acts as entry point for non-technical users)
   - **VPN Server**: WireGuard/OpenVPN server for secure access to homelab

3. **Services Requiring Always-On**:
   - **Backup Coordination**: Services that coordinate backups to cloud storage
   - **Notification Services**: Services that send alerts/notifications
   - **DNS Services**: Secondary DNS or dynamic DNS services

**Benefits**:
- **Reduced Home Network Exposure**: No direct Internet exposure of home network
- **High Uptime**: VPS has better uptime than home connection
- **Cost-Effective**: Free tier sufficient for these services
- **Security Isolation**: Compromised VPS doesn't directly affect home network

#### Services on Local Homelab (Internal / Resource-Intensive)

**Rationale**: These services require local resources, large storage, or should remain internal.

1. **Storage-Intensive Services**:
   - **Nextcloud Primary Instance**: Main storage with 40TB local storage
   - **Media Server (Jellyfin + arr*)**: Large media library, requires local storage
   - **Photo Management (Immich)**: Large photo collections
   - **Backup Storage**: Local backup repository

2. **Resource-Intensive Services**:
   - **Gaming VMs**: Windows/Steam OS VMs requiring GPU passthrough
   - **Media Processing**: Transcoding, media conversion
   - **Development Environments**: Local development tools

3. **Internal-Only Services**:
   - **Pi-hole**: Local network DNS filtering
   - **Internal Services**: Services only accessible on local network
   - **Gaming Services**: Moonlight, game servers

**Benefits**:
- **High Performance**: Direct access to powerful hardware (64GB RAM, 40TB storage)
- **Low Latency**: Local network access for gaming and media streaming
- **Cost Efficiency**: No bandwidth costs for large data transfers
- **Privacy**: Sensitive data stays on local infrastructure

### Architecture Pattern: VPS as Entry Point

**Pattern**: Oracle Cloud VPS acts as a secure entry point and proxy to local homelab services.

```
Internet Users
    ↓
Oracle Cloud VPS (Public Entry Point)
    ├── Public Websites (Static sites)
    ├── Nextcloud Public Instance (Entry point for non-tech users)
    ├── Monitoring Services (Uptime Kuma, etc.)
    └── VPN Server (Secure tunnel to homelab)
         ↓
    Secure VPN Tunnel
         ↓
Local Homelab (Private Network)
    ├── Nextcloud Primary (Synced with VPS instance)
    ├── Media Services (Jellyfin, arr*)
    ├── Internal Services
    └── Gaming VMs
```

**Implementation Details**:

1. **Nextcloud Hybrid Setup**:
   - **VPS Instance**: Public-facing Nextcloud for non-technical users (graphic designer, family)
   - **Local Instance**: Primary Nextcloud with full storage, synced with VPS
   - **Sync Strategy**: VPS instance syncs with local instance via Nextcloud federation or external storage
   - **User Experience**: Non-technical users access via VPS (simple URL), data stored locally

2. **Monitoring Architecture**:
   - **VPS**: Uptime Kuma, public monitoring dashboards, push notification service (Gotify/Ntfy/Apprise)
   - **VPS → Homelab**: Monitoring services on VPS monitor homelab services via VPN
   - **Alert Routing**: Homelab alerts routed to VPS push notification service (ensures notifications work even if homelab is down)
   - **Benefits**: Monitoring and alerting available even if home network is down, critical alerts always reach mobile phone

3. **Reverse Proxy Strategy**:
   - **VPS**: Public Traefik/Nginx reverse proxy
   - **Homelab**: Internal Traefik for local services
   - **Connection**: VPS proxy forwards to homelab services via VPN tunnel

### Security Architecture

**Network Isolation**:
- **Home Network**: No direct Internet exposure, all access via VPN
- **VPS**: Public-facing, hardened security configuration
- **Connection**: Secure VPN tunnel (WireGuard) between VPS and homelab
- **Firewall**: Strict firewall rules on VPS, only necessary ports exposed

**Security Measures on VPS**:
- **Firewall**: UFW/iptables with minimal open ports
- **Fail2Ban**: Protection against brute force attacks
- **Automatic Updates**: Enabled for security patches
- **Docker Image Scanning**: All images scanned before deployment
- **Monitoring**: Security monitoring and alerting
- **Access Control**: VPN required for VPS → Homelab communication

**Security Measures for VPS → Homelab Connection**:
- **VPN Tunnel**: WireGuard or OpenVPN encrypted tunnel
- **Network Segmentation**: VPS can only access specific homelab services
- **Firewall Rules**: Homelab firewall restricts VPS access to authorized services only
- **No Direct Exposure**: Homelab services not directly accessible from Internet

### Service Deployment Strategy

**Phase 1 (Months 1-2)**: Local homelab setup, VPS not yet deployed
- Focus on local infrastructure
- Basic services on homelab

**Phase 2 (Months 3-4)**: VPS deployment and hybrid architecture
- Oracle Cloud VPS setup
- VPN tunnel configuration
- Public services migration to VPS
- Nextcloud hybrid setup (VPS entry point + local storage)

**Phase 3 (Months 5-6)**: Optimization and expansion
- Service optimization between VPS and homelab
- Advanced monitoring setup
- Performance tuning
- Security hardening

### Cost Analysis

**Oracle Cloud VPS**: **$0/month** (Always Free tier)
- Sufficient for entry point services
- No bandwidth costs for low-traffic services
- Can scale to paid tier if needed (but free tier should be sufficient)

**Benefits**:
- **Reduced Home Network Exposure**: No need for port forwarding, dynamic DNS, or exposing home IP
- **High Uptime**: VPS uptime > home network uptime
- **Cost Savings**: Free tier eliminates need for paid VPS
- **Security**: Better security posture with isolated public services

### Implementation Considerations

**Oracle Cloud VPS Setup**:
- Follow [Oracle Cloud setup guide](https://www.it-connect.fr/un-serveur-vps-gratuit-chez-oracle-cloud-ideal-pour-vos-projets-personnels/)
- Use Ubuntu or similar Linux distribution
- Configure firewall (UFW) with minimal open ports
- Set up automatic security updates
- Configure VPN server (WireGuard recommended)

**VPS → Homelab Connection**:
- WireGuard VPN tunnel (low latency, high performance)
- Static IP or dynamic DNS for homelab (if needed)
- Firewall rules to restrict VPS access
- Monitoring of VPN tunnel health

**Service Synchronization**:
- Nextcloud: Federation or external storage sync
- Monitoring: VPS monitors homelab via VPN
- Backups: VPS coordinates backups to cloud storage

### Reference Architecture Examples

**Similar Implementations**:
- [Mafyuh/iac](https://github.com/mafyuh/iac): GitOps-driven homelab with Oracle Cloud VPS for public services
  - Uses Oracle Cloud for uptime-critical services
  - Twingate for Zero Trust access
  - Cloudflare Tunnels for public exposure
  - Good reference for hybrid architecture patterns

**Community Insights** ([Reddit Discussion](https://www.reddit.com/r/selfhosted/comments/1m3l5r9/do_you_use_a_vpscloud_provider_or_a_homelab_setup/)):
- Common pattern: VPS for public-facing services, homelab for internal services
- VPS used for: Monitoring, reverse proxy, public websites, VPN server
- Homelab used for: Media, storage, gaming, internal services
- Benefits: Security, uptime, cost efficiency
