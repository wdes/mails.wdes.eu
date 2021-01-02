FROM botsudo/phpunit:9

# Source: https://github.com/docker-library/php/issues/120#issuecomment-752125194
# ssmtp is for sendmail to work with php
RUN set -xe && \
    apk add --update --no-cache \
        imap-dev \
        openssl-dev \
        krb5-dev \
        ssmtp && \
    (docker-php-ext-configure imap --with-kerberos --with-imap-ssl) && \
    (docker-php-ext-install imap > /dev/null) && \
    php -m | grep -F 'imap' && apk add --update --no-cache composer && composer global require phpmailer/phpmailer && ln -s $(composer global config vendor-dir --absolute --quiet) /composer && ls -lah /composer
