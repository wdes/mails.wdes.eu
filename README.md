# Emails

Our Docker-Mailserver infra.

## Nice tools to use to validate the infra

- https://www.checktls.com/TestReceiver
- https://ssl-tools.net/mailservers
- https://dane.sys4.de/
- https://stats.dnssec-tools.org/explore/
- https://cryptcheck.fr/

## DANE (TSLA records)

- https://www.mailhardener.com/kb/how-to-create-a-dane-tlsa-record-with-openssl
- https://github.com/internetstandards/toolbox-wiki/blob/main/DANE-for-SMTP-how-to.md
- https://gist.github.com/buffrr/609285c952e9cb28f76da168ef8c2ca6
- https://blogs.linux.pizza/deploy-tlsa-records-dane-on-your-email-server-with-lets-encrypt

### Generate

Use https://ssl-tools.net/tlsa-generator

Our CA is https://ssl-tools.net/subjects/082e3ff9058cfe8a7c18bd13efdf1d1660707a6b
Download PEM and put in the generator
Use full cert and SHA2-256.
SHA2-512 is not recommended by the mailhardener article.
Since it is the CA use: DANE-TA: Trust Anchor Assertion.
The values (0) PKIX-TA (1) PKIX-EE should not be used with SMTP.

Use PORT 25 !

Test the generated value:

- openssl s_client -brief -dane_tlsa_domain mx1.mails.example.org -dane_tlsa_rrdata "2 0 1 21acc1dbd6944f9ac18c782cb5c328d6c2821c6b63731fa3b8987f5625de8a0d" -connect mx1.mails.example.org:465 <<< "Q"
- Alter the hash to check that it fails.

## TODO

- Check SRV records: https://www.bortzmeyer.org/6186.html
- Read the DMARC spec: https://datatracker.ietf.org/doc/html/draft-ietf-dmarc-dmarcbis-01#section-6.3-7
- Find out why Spam is no longer moved to the Junk folder: https://serverfault.com/a/979114/336084 and https://www.yakati.com/art/filtrer-les-spams-avec-rspamd-debian-9-0-stretch.html
- Find a way to change the email separator: https://forum.howtoforge.com/threads/change-postfix-dovecot-recipient_delimiter.87437/
- Implement email quota: https://github.com/docker-mailserver/docker-mailserver/issues/2957
- Check why DMARC reports are not sent: https://github.com/docker-mailserver/docker-mailserver/issues/2636
- Test the fix for: https://github.com/docker-mailserver/docker-mailserver/issues/3323

## Interesting documentations

- https://www.renater.fr/wp-content/uploads/2022/01/article-complet-tordons-le-cou-au-phishing_compresse-1.pdf (in French)
