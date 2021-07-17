# alpine-php-altver

Alernative php versions for alpine linux.

You can install PHP 7.3 at alpine edge or install PHP 8.0 at alpine 3.10 by using this repository.

All apks is built from offical APKBUILDs with minor modification (for package name "enchant" to "enchant-2" change).

## Usage

To use this, you need to add the build key and add repository url to your `/etc/apk/repositories` file

Examples following is assuming you are root, or in docker without modifing user. If not, use sudo or su to run these commands

### Add signature

<!-- remember to modify this key name and url when forking -->

```bash
wget -O /etc/apk/keys/phpaltver-60dd1390.rsa.pub https://raw.githubusercontent.com/dixyes/alpine-php-altver-storage/latest/phpaltver-60dd1390.rsa.pub
# or if you prefer curl
curl -o /etc/apk/keys/phpaltver-60dd1390.rsa.pub https://raw.githubusercontent.com/dixyes/alpine-php-altver-storage/latest/phpaltver-60dd1390.rsa.pub
```

### Add repository url

<!-- remember to modify this url when forking -->

```bash
# assuming you are using edge
echo "https://media.githubusercontent.com/media/dixyes/alpine-php-altver-storage/latest/edge/phpaltver" >> /etc/apk/repositories

# or v3.10
echo "https://media.githubusercontent.com/media/dixyes/alpine-php-altver-storage/latest/v3.10/phpaltver" >> /etc/apk/repositories

# then update apk cache
apk update
```

### Install a version of PHP that you want

```bash
# assuming you are using edge
# use this to install PHP 7.3
apk add 'php7<7.4'

# or if you want to install PHP 8.0 at v3.10
apk add php8
```
