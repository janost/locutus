## Locutus

### Introduction
Locutus is a wrapper for [borg][1] and [rclone][4] to simplify the backup workflow of a typical home user and provide a secure and easy remote backup solution.  

The utility works with a single encrypted borg repository where all configured paths are backed up and synced to a remote cloud storage via `rclone`. With borg's encrypted backup solution and [rclone][4]'s support for a wide variety of cloud storage providers it's easy to set up a secure, free or relatively cheap way for home users to back up their important data.

### Dependencies
You will need a fairly recent version of [bash][2], [pwgen][3], [borg][1] and [rclone][4].

### Setting up
Clone the repository, rename `.env.template` to `.env` and customize the parameters to your needs. You will also need to setup your remote storage in `rclone` with `rclone config` before using this tool.

### Note on backup security
Locutus initializes your backup repository with `keyfile-blake2` encryption by default, and generates a random passphrase with `pwgen` and saves it to a file specified in the `PW_FILE` parameter in the `.env` file.  
To be able to access data in your repository, **you need both the keyfile and the passphrase**.
Please make sure to back up your repository key (by exporting it via [`borg key export`][5]) and your passphrase (saved in PW_FILE, configured in `.env`) in a safe and secure place (for example a proper password manager, like [KeePassXC][6] or [BitWarden][7]) and **never share them with anyone**. Exposing your repository, key and passphrase means others can access the data in your backup repository. You probably don't want that.

### Usage
Please make sure to read, understand and customize the `.env` file before using Locutus. Locutus will initialize your backup repository the first time you're using it.

#### locutus.sh create
Creates a backup with the current timestamp according to the configuration, prunes the repository and syncs it to the configured remote storage.

#### locutus.sh list
Lists backups in your repository.

#### locutus.sh list BACKUP_NAME
Lists the contents of a backup in your repository.

#### locutus.sh info
Displays detailed information about your repository.

#### locutus.sh info BACKUP_NAME
Displays detailed information about a backup in your repository.

#### locutus.sh check
Verifies the consistency of your repository and the data stored in it.

#### locutus.sh prune
Manually executes a prune operation on the repository, removing backups not matching the configured retention options in `.env`.  
Normally this is automatically done by `locutus.sh create`.

#### locutus.sh sync
Manually synchronizes your repository with the configured remote storage.  
Normally this is automatically done by `locutus.sh create`.

#### locutus.sh mount MOUNT_POINT
Mounts your repository as a FUSE filesystem to `MOUNT_POINT`.

#### locutus.sh export-tar BACKUP_NAME FILE_NAME
Creates a tarball (`FILE_NAME`) from the specified backup (`BACKUP_NAME`).


[1]: https://borgbackup.readthedocs.io/en/stable/
[2]: https://www.gnu.org/software/bash/
[3]: https://linux.die.net/man/1/pwgen
[4]: https://rclone.org/
[5]: https://borgbackup.readthedocs.io/en/stable/usage/key.html#borg-key-export
[6]: https://keepassxc.org/
[7]: https://bitwarden.com/
