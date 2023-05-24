WEBMIN_FW_TCP_INCOMING = 21 22 80 135 139 443 445 12320 12321
WEBMIN_FW_UDP_INCOMING = 137 138

NONFREE = yes

CREDIT_ANCHORTEXT = File Server Appliance

include $(FAB_PATH)/common/mk/turnkey/fileserver.mk
include $(FAB_PATH)/common/mk/turnkey.mk
