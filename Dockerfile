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
    php-igbinary php-xdebug; \
    cd /home/developer; \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    php -r "if (hash_file('sha384', 'composer-setup.php') === 'baf1608c33254d00611ac1705c1d9958c817a1a33bce370c0595974b342601bd80b92a3f46067da89e3b06bff421f182') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer; \
    php -r "unlink('composer-setup.php');"; \
    apt-get -y autoremove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*;

RUN sed -i "s/#ServerRoot \"\/etc\/apache2\"/ServerRoot \"\/etc\/apache2\"/" /etc/apache2/apache2.conf; \
    mkdir /var/www/booking-system; \
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/barbershop.conf; \
    sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin danekkatz@gmail.com/" /etc/apache2/sites-available/barbershop.conf; \
    sed -i "s/#ServerName www.example.com/ServerName www.barbershop.com/" /etc/apache2/sites-available/barbershop.conf; \
    sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/booking-system\/BookingSystem\/public\//" /etc/apache2/sites-available/barbershop.conf; \
    a2ensite barbershop.conf;

RUN mkdir /var/www/gci/; \
    echo "<html><head><title> Ubuntu rocks! </title></head><body><p> I'm running this website on an Ubuntu Server server!</body></html>" > /var/www/gci/index.html; \
    cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/gci.conf; \
    sed -i "s/ServerAdmin webmaster@localhost/ServerAdmin dankatz@thegreat.com/" /etc/apache2/sites-available/gci.conf; \
    sed -i "s/#ServerName www.example.com/ServerName gci.example.com/" /etc/apache2/sites-available/gci.conf; \
    sed -i "s/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/gci\//" /etc/apache2/sites-available/gci.conf; \
    a2ensite gci.conf;

WORKDIR /var/www/booking-system/BookingSystem

COPY . /home/developer

EXPOSE 80

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["apachectl","-d /etc/apache2", "-e info", "-DFOREGROUND"]

