# NeoMutt with work Microsoft 365

The `tools` Stow package configures direct IMAP over TLS on
`outlook.office365.com:993` and SMTP with required STARTTLS on
`smtp.office365.com:587`. Both use XOAUTH2 exclusively. Exchange saves sent
messages; NeoMutt does not upload a second copy. Drafts use `Drafts`; adjust
`postponed` if your mailbox uses another name.

## Local setup

Install `neomutt`, Python 3, and GnuPG using your platform's package manager
(on Debian/Ubuntu: `sudo apt install neomutt python3 gpg`). NeoMutt must have
IMAP, SMTP, TLS, and XOAUTH2 support. The wrapper finds the upstream
`mutt_oauth2.py` shipped under `/usr/share/neomutt/oauth2`,
`/usr/local/share/neomutt/oauth2`, or `/opt/homebrew/share/neomutt/oauth2`.
If your package omits it, obtain it from the [NeoMutt OAuth2 sources](https://github.com/neomutt/neomutt/tree/main/contrib/oauth2)
and export `NEOMUTT_OAUTH2_HELPER` pointing to the installed script.

From the dotfiles repository:

```sh
scripts/install.sh tools
install -d -m 700 ~/.config/neomutt-work
cp -n ~/.config/neomutt/work-account.example ~/.config/neomutt-work/account.rc
nvim ~/.config/neomutt-work/account.rc
```

Set your work address and display name in that copy. This separate directory
keeps account settings outside the Stow-linked config directory. Run the copy
step only on first setup; `cp -n` preserves an existing account file.

## Microsoft Entra requirements

Ask IT for an approved public-client app registration and its application
(client) ID. Enable public-client flows for device-code authorization. The
registration must support your work tenant, with the required user/admin
consent. The bundled helper uses Microsoft's `/common` authority, so it needs
an approved multitenant registration. For an approved single-tenant registration,
copy the helper to a private location outside Git, replace `/common/` in all
three Microsoft endpoint URLs with your directory (tenant) ID, and set the
Microsoft registration's `tenant` field to that ID. Export
`NEOMUTT_OAUTH2_HELPER` pointing at that copy in every shell launching NeoMutt.
Keep the copy updated when the packaged helper changes. IT should approve the
registration and authority choice; see Microsoft's [tenant authority guidance](https://learn.microsoft.com/en-us/troubleshoot/entra/entra-id/app-integration/error-code-aadsts50020-user-account-identity-provider-does-not-exist).
Use your own approved registration rather than another mail client's
application ID. No client secret is needed for a public client.

The delegated Exchange mail scopes are
`https://outlook.office.com/IMAP.AccessAsUser.All` and
`https://outlook.office.com/SMTP.Send`, plus `offline_access` for refresh
tokens. The bundled upstream helper also requests
`https://outlook.office.com/POP.AccessAsUser.All`; account for that permission
when arranging consent, even though this configuration does not use POP.
Permission labels and their portal placement can vary; use the Exchange
resource scopes in Microsoft's [mail OAuth documentation](https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth)
as the source of truth, rather than Graph `Mail.Read`/`Mail.Send` permissions.

IT must permit IMAP access and [SMTP AUTH](https://learn.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/authenticated-client-smtp-submission)
for your mailbox. OAuth does not override disabled protocols, application
consent restrictions, Conditional Access, or device-compliance requirements.
If device-code sign-in is blocked, ask IT which flow is permitted; the helper
also supports `--authflow localhostauthcode` with an approved `http://localhost/`
desktop redirect URI and a browser that can reach the local callback.

## Authorize once

Find an existing GPG encryption key with `gpg --list-secret-keys --keyid-format long`;
if you have none, create one with `gpg --full-generate-key`. Keep its private
key backed up securely. Replace the example address, client ID, and GPG
fingerprint below with your own values:

```sh
export GPG_TTY="$(tty)"
printf '%s\n' 'YOUR-GPG-FINGERPRINT' > ~/.config/neomutt-work/gpg-recipient
bash ~/.config/neomutt/oauth2.sh \
  --authorize --verbose \
  --provider microsoft --authflow devicecode \
  --email 'your.name@company.example' \
  --client-id 'YOUR-APPROVED-APPLICATION-ID'
```

If prompted for a client secret, press Enter for a public-client registration.
Follow the displayed Microsoft sign-in URL and enter the device code, then
complete MFA and consent. The upstream helper prints an access token after
authorization; do not copy that output into notes, logs, or chat. Never use
its `--debug` option in shared logs.

Tokens are GPG-encrypted at `~/.config/neomutt-work/work.tokens.gpg`, with mode
600 and a mode-700 parent directory. This private directory uses a fixed path
under `$HOME`, matching the account settings loaded by the managed config.
The wrapper reads the full GPG fingerprint from `gpg-recipient` and passes the
encryption command on every invocation, including automatic token refresh.
Use the primary key's full 40- or 64-character hexadecimal fingerprint, without
spaces. The upstream helper itself does not remember its encryption command.
Do not put token files, decrypted JSON, or client secrets in the repository.
Losing the GPG key requires authorizing a new token store.

## Keep the private files in Git with GPG

After setting up the account and authorizing, close NeoMutt and back up its
private directory with the existing secret scripts:

```sh
GPG_RECIPIENT='YOUR-GPG-FINGERPRINT' scripts/encrypt-secrets.sh neomutt
```

Commit the resulting `secrets/neomutt.tar.gz.gpg` alongside the public config.
This archive contains account settings, the GPG recipient fingerprint, and the
already encrypted OAuth token store. On a new machine, import your GPG private
key securely, then run:

```sh
scripts/decrypt-secrets.sh neomutt
scripts/install.sh tools
```

Restore validates archive contents and preserves an existing private directory
in a sibling backup before replacing it. Run encryption again after account
changes or reauthorization, and before migrating to another machine, to capture
the latest refresh token. A revoked or stale backup can require sign-in again.
The `neomutt` selector is also included in the scripts' default all-secrets run.
The shared config and helper remain readable in Git; personal settings and
OAuth credentials are stored only in encrypted form.

## Run and verify

```sh
neomutt
```

Opening INBOX checks receiving access. Send a message to yourself to verify
SMTP separately, then confirm it appears once in Sent Items. These are manual
account checks; repository tests do not authenticate or send mail.

If consent or a refresh token is revoked, close NeoMutt and repeat authorization.
For GPG errors, check `GPG_TTY` and unlock your key through pinentry. If sending
fails while reading works, ask IT to verify SMTP AUTH and SMTP consent; do not
fall back to password authentication.
