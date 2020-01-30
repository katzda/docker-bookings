FROM ubuntu:18.04

LABEL maintainer="Daniel Katz"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo curl npm git nano vim unzip iputils-ping;

RUN useradd developer -m; \
    usermod -aG sudo developer;

RUN apt-get update && apt-get install -y \
    php php-cli php-pgsql php-curl php-xml \
    php-mbstring php-readline php-zip php-soap \
    php-bcmath php-intl php-memcached \
    php-imap php-gd php-msgpack \
    php-igbinary php-xdebug;

RUN cd /home/developer; \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'baf1608c33254d00611ac1705c1d9958c817a1a33bce370c0595974b342601bd80b92a3f46067da89e3b06bff421f182') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    php -r "unlink('composer-setup.php');"; \
    apt-get -y autoremove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

RUN apt-get update && apt-get install -y apache2; \
    usermod -a -G developer www-data; \
    usermod -g developer www-data; \
    usermod -a -G www-data developer; \
    mkdir /var/www/%WEB_DOMAIN_NAME%%URL_ENDING%;

RUN mv /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/%WEB_DOMAIN_NAME%%URL_ENDING%.conf; \
    bash -c "sed -i $'s/#ServerRoot \"\/etc\/apache2\"/\\\nServerName localhost\\\nServerRoot \"\/etc\/apache2\"/' /etc/apache2/apache2.conf;"; \
    sed -i -E -z "s/(<Directory \/var\/www\/>$NUL\s+Options Indexes FollowSymLinks$NUL\s+AllowOverride )(None)/\1All/" /etc/apache2/apache2.conf; \
    a2enmod rewrite; \
    sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin %email_address%/" /etc/apache2/sites-available/%WEB_DOMAIN_NAME%%URL_ENDING%.conf; \
    sed -i "s/#ServerName www.example.com/ServerName %WEB_DOMAIN_NAME%%URL_ENDING%/" /etc/apache2/sites-available/%WEB_DOMAIN_NAME%%URL_ENDING%.conf; \
    sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/%WEB_DOMAIN_NAME%%URL_ENDING%\/%PATH_TO_PUBLIC_ESCAPED%\/public\//" /etc/apache2/sites-available/%WEB_DOMAIN_NAME%%URL_ENDING%.conf; \
    a2ensite %WEB_DOMAIN_NAME%%URL_ENDING%.conf;

WORKDIR /var/www/%WEB_DOMAIN_NAME%%URL_ENDING%/%PATH_TO_PUBLIC%

USER developer

COPY .env /home/developer/.env

RUN sed -i "s/&WEB_DOMAIN_NAME&/$WEB_DOMAIN_NAME/;s/&DB_CONTAINER_NAME&/$DB_CONTAINER_NAME/;s/&DB_PORT&/$DB_PORT/;s/&DB_NAME&/$DB_NAME/;s/&DB_USER_NAME&/$DB_USER_NAME/;s/&DB_USER_PASSWORD&/$DB_USER_PASSWORD/;" /home/developer/.env

USER root

CMD apachectl -DFOREGROUND

