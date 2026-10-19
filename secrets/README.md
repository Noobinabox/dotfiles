# GPG secrets

Only encrypted `*.gpg` files belong in this directory.

Decrypted runtime files live outside the repo at:

- `~/.config/secrets/shell.env`
- `~/.config/secrets/npm.env`
- `~/.ssh` → `ssh.tar.gz.gpg`
- `~/.config/mud-client` → `mud-client.tar.gz.gpg`

Use `scripts/encrypt-secrets.sh` after editing local secret files, and use
`scripts/decrypt-secrets.sh` after cloning this repo on a new machine.

Select only the directory backups with `ssh mud-client` arguments. Encryption
requires `GPG_RECIPIENT=<key id/email>` or `GPG_SYMMETRIC=1` (interactive
passphrase). Missing inputs are skipped. Config paths honor `XDG_CONFIG_HOME`.
Directory symlinks are followed when backing up; restores create ordinary
files, validate archives with Python 3, and preserve previous destinations in
private sibling backup directories. See the root README for recovery details.

