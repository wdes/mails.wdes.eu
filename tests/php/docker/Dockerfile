FROM botsudo/phpunit:10

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Source: https://github.com/docker-library/php/issues/120#issuecomment-752125194
# ssmtp is for sendmail to work with php
RUN set -eux && \
    apk add --update --no-cache \
        openssl-dev \
        ssmtp && \
        composer global require phpmailer/phpmailer webklex/php-imap && ln -s $(composer global config vendor-dir --absolute --quiet) /composer && ls -lah /composer

COPY ssmtp.conf /etc/ssmtp/ssmtp.conf
