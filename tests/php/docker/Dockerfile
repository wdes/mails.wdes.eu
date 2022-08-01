FROM botsudo/phpunit:9

COPY --from=composer:2.3 /usr/bin/composer /usr/bin/composer

# Source: https://github.com/docker-library/php/issues/120#issuecomment-752125194
# ssmtp is for sendmail to work with php
RUN set -eux && \
    apk add --update --no-cache \
        imap-dev \
        openssl-dev \
        ssmtp && \
    (docker-php-ext-configure imap --with-imap-ssl) && \
    (docker-php-ext-install imap > /dev/null) && \
    php -m | grep -F 'imap' && composer global require phpmailer/phpmailer && ln -s $(composer global config vendor-dir --absolute --quiet) /composer && ls -lah /composer

COPY ssmtp.conf /etc/ssmtp/ssmtp.conf
