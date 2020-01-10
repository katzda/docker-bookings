FROM ubuntu:latest

LABEL maintainer="Daniel Katz"

ENV DEBIAN_FRONTEND=noninteractive

RUN useradd developer -m

RUN apt-get update; \
    echo "Europe/London" > /etc/timezone; \
    apt-get install -y gnupg tzdata; \
    dpkg-reconfigure -f noninteractive tzdata;

RUN apt-get update && apt-get install -y \
    curl npm git nano unzip sudo apache2 \
    php php-cli php-pgsql php-curl php-xml \
    php-mbstring php-readline php-zip php-soap \
    php-bcmath php-intl php-sqlite3 php-memcached \
    php-imap php-gd php-mysql php-msgpack \
    php-igbinary php-xdebug;

RUN cd /home/developer; \
    mkdir booking-system; \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'baf1608c33254d00611ac1705c1d9958c817a1a33bce370c0595974b342601bd80b92a3f46067da89e3b06bff421f182') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    php -r "unlink('composer-setup.php');"; \
    apt-get -y autoremove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

USER developer

WORKDIR /home/developer

EXPOSE 80

CMD apachectl -D FOREGROUND
