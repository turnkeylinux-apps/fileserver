WEBMIN_FW_TCP_INCOMING += 21

NONFREE = yes

CREDIT_ANCHORTEXT = File Server Appliance
COMMON_CONF += ftp

include $(FAB_PATH)/common/mk/turnkey/fileserver.mk
include $(FAB_PATH)/common/mk/turnkey.mk
