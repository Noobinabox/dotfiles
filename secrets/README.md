# GPG secrets

Only encrypted `*.gpg` files belong in this directory.

Decrypted runtime files live outside the repo at:

- `~/.config/secrets/shell.env`
- `~/.config/secrets/npm.env`
- `~/.ssh` → `ssh.tar.gz.gpg`
- `~/.config/neomutt-work` → `neomutt.tar.gz.gpg` (account settings and OAuth2 token store)

Use `scripts/encrypt-secrets.sh` after editing local secret files, and use
`scripts/decrypt-secrets.sh` after cloning this repo on a new machine.

Select only the SSH directory backup with `ssh`, or work email with `neomutt`.
Close NeoMutt before backing up/restoring its files and refresh the backup
after reauthorization. The NeoMutt private directory uses the fixed path above;
the env-file paths honor `XDG_CONFIG_HOME`. Encryption
requires `GPG_RECIPIENT=<key id/email>` or `GPG_SYMMETRIC=1` (interactive
passphrase). Missing inputs are skipped.
Directory symlinks are followed when backing up; restores create ordinary
files, validate archives with Python 3, and preserve previous destinations in
private sibling backup directories. See the root README for recovery details.

MUD client configuration is managed by Stow under `tools/.config/mud-client`,
not by these encryption scripts. Old MUD archives are not restored.

