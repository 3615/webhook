#!/bin/sh
set -e

uid=$(stat -c %u /srv)
gid=$(stat -c %g /srv)

export COMPOSER_ALLOW_SUPERUSER=true

if [ $uid == 0 ] && [ $gid == 0 ]; then
    exec "$@"
fi

sed -i -r "s/foo:x:\d+:\d+:/foo:x:$uid:$gid:/g" /etc/passwd
sed -i -r "s/bar:x:\d+:/bar:x:$gid:/g" /etc/group

sed -i "s/user = www-data/user = foo/g" /usr/local/etc/php-fpm.d/www.conf
sed -i "s/group = www-data/group = bar/g" /usr/local/etc/php-fpm.d/www.conf

user=$(grep ":x:$uid:" /etc/passwd | cut -d: -f1)

#if []; then
#    su-exec $user sh -c 'cat << EOF > $HOME/.
#These contents will be written to the file.
#        This line is indented.
#EOF'
#fi

if [ "${1}" != 'supervisord' ]; then
#    if [ $(stat -c %u /srv) == $uid ]; then
#        chown -R $uid:$gid $COMPOSER_HOME
#    fi
    # share env variables in the user's shell
    COMPOSER_HOME=$COMPOSER_HOME \
    COMPOSER_CACHE_DIR=$COMPOSER_CACHE_DIR \
    ENV=$ENV \
    PATH=$PATH \
    exec su-exec $user "$@"
fi

exec "$@"
