"""
Génère la config JSON pour Nextcloud External Storage via `occ files_external:import`.
Exécuté en post-deploy par Pulumi.
"""

import json
import sys


def generate_import_json(host, smb_user, smb_pass):
    EXTERNAL_MOUNTS = [
        # Mounts per-user (variable $user remplacée par Nextcloud)
        {
            "mount_point": "/Mes Photos",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/immich/library/$user",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False},
            "applicable_users": [],
            "applicable_groups": [],
        },
        {
            "mount_point": "/Envoyer à Paperless",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/paperless/consume/$user",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False},
            "applicable_users": [],
            "applicable_groups": [],
        },
        # Mounts partagés (tous les utilisateurs)
        {
            "mount_point": "/Partagé/Musique",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/shared/music",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False, "read_only": True},
            "applicable_users": [],
            "applicable_groups": [],
        },
        {
            "mount_point": "/Partagé/Films",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/shared/movies",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False, "read_only": True},
            "applicable_users": [],
            "applicable_groups": [],
        },
        {
            "mount_point": "/Partagé/Livres",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/shared/books",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False, "read_only": True},
            "applicable_users": [],
            "applicable_groups": [],
        },
        {
            "mount_point": "/Partagé/Livres Audio",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/shared/audiobooks",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False, "read_only": True},
            "applicable_users": [],
            "applicable_groups": [],
        },
        {
            "mount_point": "/Partagé/ROMs",
            "storage": "\\OC\\Files\\Storage\\SMB",
            "authentication_type": "password::password",
            "configuration": {
                "host": host,
                "share": "/romm/library",
                "user": smb_user,
                "password": smb_pass,
            },
            "options": {"enable_sharing": False, "read_only": True},
            "applicable_users": [],
            "applicable_groups": [],
        },
    ]
    return json.dumps(EXTERNAL_MOUNTS, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python nextcloud_external_storage.py <host> <user> <pass>")
        sys.exit(1)

    host, user, password = sys.argv[1:4]
    print(generate_import_json(host, user, password))
