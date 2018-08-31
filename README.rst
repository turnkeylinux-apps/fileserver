File Server - Simple Network Attached Storage
=============================================

An easy to use file server that combines Windows-compatible network file
sharing with a web based file manager. TurnKey File Server includes 
support for SMB, SFTP, NFS, WebDAV and rsync file transfer protocols. 
The server is configured to allow server users to manage files in private 
or public storage. Based on Samba and SambaDAV.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- SSL support out of the box.
- Webmin module for configuring Samba.
- Includes popular compression support (zip, rar, bz2).
- Includes flip to convert text file endings between UNIX and DOS
  formats.
- `WebDAV CGI`_ providing WebUI and WebDAV access.
- File server (`Samba`_) configurations:
   
   - Preconfigured wordgroup: WORKGROUP
   - Preconfigured netbios name: FILESERVER
   - Configured root as administrative samba user.
   - Configured shares:
      
      - Users home directory.
      - Public storage.
      - CD-ROM with automount and umount hooks (/media/cdrom).

   - NOTE: Due to the removal of libpam-smbpass (see `issue #1188`_), new Samba
     users must have their passwords explictly set separately when created.
     However, if you create a Samba user using smbpasswd, then a new Linux user
     of the same name, with the same password is automatically created
     (including home directory). E.g.::

       # smbpasswd -a new_user
       New SMB password:
       Retype new SMB password:
       Added user new_user.
       # ls /home/
       new_user

- Access your files securely from anywhere via `WebDAV CGI`_:
   
   - web GUI access to your files, with online previews of major formats and drag-n-drop
     support.
   - Pre-configured authentication (Samba).
   - Pre-configured repositories (storage, user home directories).

- Default storage: */srv/storage*
- Accessing file server via samba on the command line::

    smbclient //1.0.0.61/storage -Uroot
    mount -t cifs //1.0.0.61/storage /mnt -o username=root,password=PASSWORD

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, Webshell, SSH, Samba: username **root**
-  Web based file manager (WebDAV CGI):
   
   - username **root** (or Samba users)


.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Samba: https://www.samba.org/samba/what_is_samba.html
.. _issue #1188: https://github.com/turnkeylinux/tracker/issues/1188
.. _`WebDAV CGI`: https://danrohde.github.io/webdavcgi/
