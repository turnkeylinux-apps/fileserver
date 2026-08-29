#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
root_password=${TKL_TEST_ROOT_PASS:?TKL_TEST_ROOT_PASS is required}
qa_dir=/run/tkl-v19-fileserver
smb_source=$qa_dir/smb-source
smb_copy=$qa_dir/smb-copy
ftp_source=$qa_dir/ftp-source
ftp_copy=$qa_dir/ftp-copy
landing=$qa_dir/landing.html
hostile=$qa_dir/hostile.html
updater=$qa_dir/updater.txt
smb_name=tkl-v19-smb-$$
ftp_name=tkl-v19-ftp-$$

cleanup() {
    smbclient //127.0.0.1/storage -U"root%$root_password" \
        -c "del $smb_name" >/dev/null 2>&1 || true
    curl --silent --show-error --insecure --ssl-reqd \
        --user "root:$root_password" --quote "DELE $ftp_name" \
        ftp://127.0.0.1/ >/dev/null 2>&1 || true
    rm -rf -- "$qa_dir"
}
trap cleanup EXIT
mkdir -p "$qa_dir"

# AUTO_RUN is a harness shortcut. Normal interactive firstboot closes the
# temporary web fence before the application is handed to the user.
systemctl stop turnkey-init-fence.service 2>/dev/null || true

systemctl --quiet is-active smbd.service pure-ftpd.service apache2.service \
    postfix.service multi-user.target
apache2ctl configtest
grep -Fxq 'VERSION_CODENAME=trixie' /etc/os-release
grep -Eq '^turnkey-fileserver-19\.0' /etc/turnkey_version
if grep -RqsE '(^|[/:._-])bookworm([/:._-]|$)' \
        /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    echo 'Bookworm APT source remains enabled' >&2
    exit 1
fi

# Firstboot must rotate the known build password and must not log the supplied
# credential. Authentication failures are checked before the positive flows.
root_hash=$(getent shadow root | cut -d: -f2)
case "$root_hash" in
    ''|'!'|'*'|U6aMy0wojraho)
        echo 'root password was not rotated from the build state' >&2
        exit 1
        ;;
esac
if grep -RFq -- "$root_password" /var/log/inithooks.log \
        /var/log/auth.log 2>/dev/null; then
    echo 'firstboot credential was written to a log' >&2
    exit 1
fi
if smbclient //127.0.0.1/storage -U'root%definitely-wrong-v19-password' \
        -c quit >/dev/null 2>&1; then
    echo 'SMB accepted an invalid password' >&2
    exit 1
fi
if curl --silent --show-error --insecure --ssl-reqd \
        --user 'root:definitely-wrong-v19-password' \
        ftp://127.0.0.1/ >/dev/null 2>&1; then
    echo 'FTPS accepted an invalid password' >&2
    exit 1
fi

# Exercise an authenticated file round trip, then prove it survives the
# service restart that a routine package update would perform.
printf 'fileserver-smb-v19-%s\n' "$$" >"$smb_source"
smbclient //127.0.0.1/storage -U"root%$root_password" \
    -c "put $smb_source $smb_name"
systemctl restart smbd.service
smbclient //127.0.0.1/storage -U"root%$root_password" \
    -c "get $smb_name $smb_copy"
cmp "$smb_source" "$smb_copy"
smbclient //127.0.0.1/storage -U"root%$root_password" \
    -c "del $smb_name"
pdbedit -L | grep -q '^root:'

printf 'fileserver-ftps-v19-%s\n' "$$" >"$ftp_source"
curl --silent --show-error --fail --insecure --ssl-reqd \
    --user "root:$root_password" --upload-file "$ftp_source" \
    "ftp://127.0.0.1/$ftp_name"
systemctl restart pure-ftpd.service
curl --silent --show-error --fail --insecure --ssl-reqd \
    --user "root:$root_password" "ftp://127.0.0.1/$ftp_name" \
    --output "$ftp_copy"
cmp "$ftp_source" "$ftp_copy"
curl --silent --show-error --fail --insecure --ssl-reqd \
    --user "root:$root_password" --quote "DELE $ftp_name" \
    ftp://127.0.0.1/ >/dev/null

# The landing page may use a syntactically safe request host, but hostile
# attribute/script input must neither survive nor become a link target.
curl --silent --show-error --fail --header 'Host: fileserver.example' \
    http://127.0.0.1/index.pl >"$landing"
grep -Fq 'href="https://fileserver.example:12321"' "$landing"
HTTP_HOST='bad.invalid"><svg/onload=alert(1)>' \
    perl /var/www/cgi-bin/index.pl >"$hostile"
grep -Fq 'href="https://localhost:12321"' "$hostile"
if grep -Fq '<svg/onload=alert(1)>' "$hostile"; then
    echo 'landing CGI reflected hostile Host input' >&2
    exit 1
fi
systemctl restart apache2.service
curl --silent --show-error --fail --header 'Host: fileserver.example' \
    http://127.0.0.1/index.pl >/dev/null

samba_version=$(dpkg-query -W -f='${Version}' samba)
ftp_version=$(dpkg-query -W -f='${Version}' pure-ftpd)
apache_version=$(dpkg-query -W -f='${Version}' apache2)
before="$samba_version|$ftp_version|$apache_version"
export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
{
    apt-cache policy samba pure-ftpd apache2
    apt-get indextargets --format '$(IDENTIFIER)|$(SUITE)|$(RELEASE)|$(SITE)'
} >"$updater"
grep -Eq '^Packages\|(trixie|trixie-updates|trixie-security)\|' "$updater"
for package in samba pure-ftpd apache2; do
    apt-cache policy "$package" | grep -Eq '^  Candidate: [^[:space:]]+$'
done
after="$(dpkg-query -W -f='${Version}' samba)|$(dpkg-query -W -f='${Version}' pure-ftpd)|$(dpkg-query -W -f='${Version}' apache2)"
test "$after" = "$before"

cat >"$result" <<EOF
package_source=Fileserver behavior from TurnKey common fileserver and FTP plans; Samba, Pure-FTPd and Apache from signed Debian 13 Trixie APT repositories; inherited Core and management packages from signed TurnKey Trixie APT repositories
installed_version=turnkey-fileserver $(cat /etc/turnkey_version); samba $samba_version; pure-ftpd $ftp_version; apache2 $apache_version
runtime_checks=normal firstboot and service health; rejected invalid SMB and FTPS credentials; authenticated SMB and explicit-TLS FTP upload/download/delete across service restart; least-surprise password rotation and log hygiene; safe landing CGI Host handling across Apache restart
updater_command=apt-get update; apt-cache policy samba pure-ftpd apache2; apt-get indextargets
updater_result=signed APT metadata refreshed; eligible Trixie candidates found; installed package versions unchanged
updater_channel=Debian and TurnKey Trixie, Trixie updates and Trixie security repositories
integrity_evidence=apt-get update accepted signed repository metadata; retained index targets prove configured Trixie channels; no Bookworm source remained; file-service package versions were captured before and after the non-mutating updater check
EOF
