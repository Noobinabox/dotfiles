# GPG secrets

Only encrypted `*.gpg` files belong in this directory.

Decrypted runtime files live outside the repo at:

- `~/.config/secrets/shell.env`
- `~/.config/secrets/npm.env`

Use `scripts/encrypt-secrets.sh` after editing local secret files, and use
`scripts/decrypt-secrets.sh` after cloning this repo on a new machine.

