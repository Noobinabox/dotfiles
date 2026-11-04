# GPG secrets

Only encrypted `*.gpg` files belong in this directory.

Decrypted runtime files live outside the repo at:

- `~/.config/secrets/shell.env`
- `~/.config/secrets/npm.env`
- `~/.ssh` → `ssh.tar.gz.gpg`

Use `scripts/encrypt-secrets.sh` after editing local secret files, and use
`scripts/decrypt-secrets.sh` after cloning this repo on a new machine.

Select only the SSH directory backup with the `ssh` argument. Encryption
requires `GPG_RECIPIENT=<key id/email>` or `GPG_SYMMETRIC=1` (interactive
passphrase). Missing inputs are skipped. Config paths honor `XDG_CONFIG_HOME`.
Directory symlinks are followed when backing up; restores create ordinary
files, validate archives with Python 3, and preserve previous destinations in
private sibling backup directories. See the root README for recovery details.

MUD client configuration is managed by Stow under `tools/.config/mud-client`,
not by these encryption scripts. Old MUD archives are not restored.


The encrypt/decrypt helpers set `GPG_TTY` from the current terminal before
starting GPG, including when an SSH archive is streamed through stdin. This
keeps the passphrase prompt attached to the terminal when sessions change.
For agent/pinentry troubleshooting, set `export GPG_TTY="$(tty)"` in an interactive
shell and retry the same helper command. Headless calls retain an explicitly
provided `GPG_TTY`; no passphrase is placed in command arguments.
