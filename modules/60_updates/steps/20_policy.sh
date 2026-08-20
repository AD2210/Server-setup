#!/usr/bin/env bash
log_step "Configuration de la politique de mises à jour"

POLICY="/etc/apt/apt.conf.d/52server-setup-unattended-upgrades"

cat >"$POLICY" <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Les redémarrages sont gérés séparément par le module 70_reboot.
Unattended-Upgrade::Automatic-Reboot "false";
EOF

chmod 644 "$POLICY"

cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

log_info "Mises à jour de sécurité automatiques activées."
log_info "Redémarrage automatique par unattended-upgrades désactivé."
