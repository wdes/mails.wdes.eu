# Emails

Our Docker-Mailserver infra.

## Nice tools to use to validate the infra

- https://www.checktls.com/TestReceiver


## TODO

- Automate DANE:
    - https://gist.github.com/buffrr/609285c952e9cb28f76da168ef8c2ca6
    - https://github.com/internetstandards/toolbox-wiki/blob/main/DANE-for-SMTP-how-to.md
- Check SRV records: https://www.bortzmeyer.org/6186.html
- Read the DMARC spec: https://datatracker.ietf.org/doc/html/draft-ietf-dmarc-dmarcbis-01#section-6.3-7
- Find out why Spam is no longer moved to the Junk folder: https://serverfault.com/a/979114/336084 and https://www.yakati.com/art/filtrer-les-spams-avec-rspamd-debian-9-0-stretch.html
- Find a way to change the email separator: https://forum.howtoforge.com/threads/change-postfix-dovecot-recipient_delimiter.87437/
- Implement email quota: https://github.com/docker-mailserver/docker-mailserver/issues/2957
- Check why DMARC reports are not sent: https://github.com/docker-mailserver/docker-mailserver/issues/2636
- Test the fix for: https://github.com/docker-mailserver/docker-mailserver/issues/3323
