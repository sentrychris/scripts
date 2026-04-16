#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
MOUNT_POINT="/mnt/volume-hel1-2"                      # Already mounted volume
DATA_SUBDIR="${MOUNT_POINT}/mysql"                    # MySQL data subdirectory
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"       # MySQL config path
APPARMOR_PROFILE="/etc/apparmor.d/usr.sbin.mysqld"    # AppArmor profile path
OLD_DATADIR="/var/lib/mysql"                          # Current MySQL datadir
BACKUP_DIR="/root/mysql-migration-backup"             # Config backups go here

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# --- Verify the volume is mounted ---
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Error: ${MOUNT_POINT} is not a mountpoint. Is the volume attached and mounted?" >&2
    exit 1
fi

# --- Verify MySQL config exists ---
if [[ ! -f "$MYSQL_CONF" ]]; then
    echo "Error: MySQL config not found at ${MYSQL_CONF}." >&2
    exit 1
fi

# --- Refuse to run if target already has data ---
if [[ -d "$DATA_SUBDIR" && "$(ls -A "$DATA_SUBDIR" 2>/dev/null)" ]]; then
    echo "Error: ${DATA_SUBDIR} already contains data. Remove it manually if you want to re-run." >&2
    exit 1
fi

# --- Confirm before proceeding ---
echo "This will:"
echo "  1. Stop MySQL"
echo "  2. Copy ${OLD_DATADIR} to ${DATA_SUBDIR}"
echo "  3. Update MySQL config to point to ${DATA_SUBDIR}"
echo "  4. Update AppArmor if active"
echo "  5. Start MySQL from the new location"
echo ""
echo "Volume:"
df -h "$MOUNT_POINT"
echo ""
echo "Current MySQL datadir size:"
du -sh "$OLD_DATADIR" 2>/dev/null || echo "  (could not read — will need root)"
echo ""
echo "Config backups will be saved to ${BACKUP_DIR}"
echo ""
read -rp "Continue? (y/N): " confirm
[[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# --- Back up configs before touching anything ---
mkdir -p "$BACKUP_DIR"
cp -a "$MYSQL_CONF" "${BACKUP_DIR}/mysqld.cnf.bak"
if [[ -f "$APPARMOR_PROFILE" ]]; then
    cp -a "$APPARMOR_PROFILE" "${BACKUP_DIR}/usr.sbin.mysqld.bak"
fi
echo "Config backups saved to ${BACKUP_DIR}"

# --- Stop MySQL and verify it is down ---
echo "Stopping MySQL..."
systemctl stop mysql

if systemctl is-active --quiet mysql; then
    echo "Error: MySQL is still running after stop. Aborting." >&2
    exit 1
fi
echo "MySQL stopped."

# --- Copy data ---
mkdir -p "$DATA_SUBDIR"
echo "Copying ${OLD_DATADIR} to ${DATA_SUBDIR} (this may take a while)..."
rsync -aHAX --numeric-ids "${OLD_DATADIR}/" "${DATA_SUBDIR}/"

# --- Verify critical files exist in new location ---
MISSING=()
for f in mysql auto.cnf; do
    if [[ ! -e "${DATA_SUBDIR}/${f}" ]]; then
        MISSING+=("$f")
    fi
done

if [[ -e "${OLD_DATADIR}/ibdata1" && ! -e "${DATA_SUBDIR}/ibdata1" ]]; then
    MISSING+=("ibdata1")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Error: Expected files missing from ${DATA_SUBDIR}: ${MISSING[*]}" >&2
    echo "Copy may have failed. Original data is intact at ${OLD_DATADIR}." >&2
    echo "Restoring config from backup..."
    cp -a "${BACKUP_DIR}/mysqld.cnf.bak" "$MYSQL_CONF"
    exit 1
fi

chown -R mysql:mysql "$DATA_SUBDIR"
chmod 750 "$DATA_SUBDIR"
echo "Data copied and permissions set."

# --- Update MySQL config ---
echo "Updating MySQL datadir in ${MYSQL_CONF}..."
sed -i "s|^datadir\s*=.*|datadir = ${DATA_SUBDIR}|" "$MYSQL_CONF"

# --- Update AppArmor if active ---
if aa-status --enabled 2>/dev/null && [[ -f "$APPARMOR_PROFILE" ]]; then
    if ! grep -q "${DATA_SUBDIR}" "$APPARMOR_PROFILE"; then
        echo "Adding AppArmor rules for ${DATA_SUBDIR}..."
        RULES="  # MySQL migration - new datadir\n"
        RULES+="  ${MOUNT_POINT}/ r,\n"
        RULES+="  ${DATA_SUBDIR}/ r,\n"
        RULES+="  ${DATA_SUBDIR}/** rwk,\n"
        RULES+="  ${DATA_SUBDIR}/** lk,"

        sed -i "/^}/i\\${RULES}" "$APPARMOR_PROFILE"
        apparmor_parser -r "$APPARMOR_PROFILE"
        echo "AppArmor profile updated and reloaded."
    fi
fi

# --- Verify mount is still active before starting MySQL ---
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Error: ${MOUNT_POINT} is no longer mounted. Cannot start MySQL safely." >&2
    echo "Restoring config from backup..."
    cp -a "${BACKUP_DIR}/mysqld.cnf.bak" "$MYSQL_CONF"
    if [[ -f "${BACKUP_DIR}/usr.sbin.mysqld.bak" ]]; then
        cp -a "${BACKUP_DIR}/usr.sbin.mysqld.bak" "$APPARMOR_PROFILE"
        apparmor_parser -r "$APPARMOR_PROFILE"
    fi
    exit 1
fi

# --- Start MySQL and verify ---
echo "Starting MySQL..."
if ! systemctl start mysql; then
    echo ""
    echo "ERROR: MySQL failed to start. Recovery steps:" >&2
    echo "  1. Check logs:  journalctl -u mysql --no-pager -n 50" >&2
    echo "  2. Original data is intact at ${OLD_DATADIR}" >&2
    echo "  3. Config backups are at ${BACKUP_DIR}" >&2
    echo "  4. To rollback:" >&2
    echo "     cp ${BACKUP_DIR}/mysqld.cnf.bak ${MYSQL_CONF}" >&2
    [[ -f "${BACKUP_DIR}/usr.sbin.mysqld.bak" ]] && \
        echo "     cp ${BACKUP_DIR}/usr.sbin.mysqld.bak ${APPARMOR_PROFILE}" >&2
    echo "     systemctl start mysql" >&2
    exit 1
fi

DATADIR=$(mysql -Nse "SHOW VARIABLES LIKE 'datadir';" | awk '{print $2}')
echo ""
echo "Migration complete."
echo "  MySQL datadir: ${DATADIR}"
echo "  Original data: ${OLD_DATADIR} (kept intact — remove manually when confident)"
echo "  Config backups: ${BACKUP_DIR}"
