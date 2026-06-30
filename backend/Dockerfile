FROM php:8.2-fpm-alpine AS php
RUN apk add --no-cache nginx bash curl openssl ca-certificates tzdata icu-libs icu-data-full $PHPIZE_DEPS \
  && docker-php-ext-install opcache \
  && pecl install apcu && docker-php-ext-enable apcu \
  && echo "apc.enable_cli=1" >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini \
  && apk del $PHPIZE_DEPS

# Configure PHP-FPM for better concurrency
RUN { \
  echo "pm = dynamic"; \
  echo "pm.max_children = 20"; \
  echo "pm.start_servers = 4"; \
  echo "pm.min_spare_servers = 2"; \
  echo "pm.max_spare_servers = 8"; \
  echo "request_terminate_timeout = 120s"; \
  } > /usr/local/etc/php-fpm.d/zz-www.conf

# PHP config
COPY deploy/php.ini /usr/local/etc/php/conf.d/99-custom.ini

# Nginx config
COPY deploy/nginx.conf /etc/nginx/nginx.conf

# Copy app (source context IS the backend directory)
WORKDIR /var/www/html
COPY . /var/www/html/

# Ensure perms
RUN chown -R www-data:www-data /var/www/html && \
  mkdir -p /var/run/php && chown -R www-data:www-data /var/run/php && \
  mkdir -p /var/log/nginx /var/lib/nginx && chown -R www-data:www-data /var/log/nginx /var/lib/nginx && \
  mkdir -p /var/www/html/logs /var/www/html/cache /var/www/html/uploads/media && chown -R www-data:www-data /var/www/html/logs /var/www/html/cache /var/www/html/uploads

ENV PHP_FPM_LISTEN=/var/run/php/php-fpm.sock

EXPOSE 8080

USER www-data

CMD ["bash", "-lc", "php-fpm -D && (sleep 3 && php /var/www/html/api/warmup.php > /dev/null 2>&1 &) && nginx -g 'daemon off;'"]
