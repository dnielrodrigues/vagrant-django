
# Deploy Rules to Proabakus Python env

#-- Criar Modelo de Instalacao para servidores com ambiente configurado.
#-- Ubuntu 16
#-- Update
apt-get update
apt-get upgrade





#-- Layout Dir
/
home
    deploy
        [production/testing]
            projectname
                evn_projectname
                    bin
                    local
                    lib
                    include
                    share
                projectname
                    apps
                        blog
                            template
                                blog
                        static
                    static
                    settings
            script
            log
            media
            run
            manage.py


# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
#-- Create Users
adduser deploy
su - deploy
mkdir production
mkdir testing
exit

#-- If develop runs on server
adduser develop

#-- Packages to Env Server
apt-get install htop squid nmap build-essential 
#-- Packages to Env Python
apt-get install python3-pip python3 libjpeg-dev python-pip python-virtualenv python-dev python-psycopg2 python3-psycopg2 python-pil python-django
apt-get install build-essential libssl-dev libffi-dev python-dev python-openssl

#-- Packages to Database PostgreSQL
export PG_VERSION='9.5'
export PG_VERSION_YUM='95'
apt-get install postgresql-${PG_VERSION} postgresql-plpython-${PG_VERSION} postgresql-plperl-${PG_VERSION} postgresql-server-dev-${PG_VERSION} postgresql-contrib-${PG_VERSION} postgresql-client-${PG_VERSION}

#-- Setup permissions and listen address
vim /etc/postgresql/9.5/main/postgresql.conf
vim /etc/postgresql/9.5/main/pg_hba.conf
/etc/init.d/postgresql restart

# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
#-- Creating a new Project App

export PROJECTNAME="EARetaguardaWeb"
export ENVDEPLOY="staging"
export PYVERSION="python3" # python is same python2.7 or python3 is same python3.4 (latest version)

#-- Runs
cd /home/deploy/${ENVDEPLOY}
django-admin startproject ${PROJECTNAME}
cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}
mkdir -p config script log run media temp
cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/${PROJECTNAME}
mkdir -p apps static settings

#-- Create VirtualEnv
cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}
virtualenv -p /usr/bin/${PYVERSION} .
source bin/activate # o prompt mudara para (env) ...

#-- Modules Defaults
pip install django
pip install pillow
pip install psycopg2
pip install setproctitle
pip install pdb

#-- If needed more modules, install with the same above command
pip install xyz

  #----------------------------------------------------------------------------------------
  #----------------------------------------------------------------------------------------
  #-- For Git Users Normally ProAbakus Environment
  #-- Pay Attention: The projectname on git repository must to be the same name on projectname created by django-admin
  cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}
  mkdir -p temp
  cd temp
  git clone URL # http://200.253.33.69:8081/proabakus/EARetaguardaWeb.git
  cd ..
  mv ${PROJECTNAME} ${PROJECTNAME}.zero
  mv temp/${PROJECTNAME} ./
  #-- PIP Requirements
  pip install -r PATH
  #-- Bower requirements
  bower install --allow-root
  # npm
  # npm bower -g
  #----------------------------------------------------------------------------------------
  #----------------------------------------------------------------------------------------

#-- Set Owner
cd /home/deploy/${ENVDEPLOY}
chown deploy:deploy ${PROJECTNAME} -R

#-- Test Run the Project host: localhost, port: 8888 
cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}
#source bin/activate

# Test connection with Python Django, if use custow settings uncomment next line and commect last line
#python manage.py shell --settings=${PROJECTNAME}.settings.prod
python manage.py shell --settings=${PROJECTNAME}.settings

#-- Setup Database if needed

# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
#-- Unicorn
cd /home/deploy/${ENVDEPLOY}/${PROJECTNAME}
pip install gunicorn

#-- Teste Run GUnicorn
#gunicorn ${PROJECTNAME}.wsgi:application --bind 0.0.0.0:5555 --env DJANGO_SETTINGS_MODULE=${PROJECTNAME}.settings.prod
gunicorn ${PROJECTNAME}.wsgi:application --bind 0.0.0.0:5555 --env DJANGO_SETTINGS_MODULE=${PROJECTNAME}.settings

#-- File gunicorn_start or appname.start
#-- Example by [ProjectName] app
#-- Start App File

cat << EOF > script/gunicorn.start
#!/bin/bash

NAME="${PROJECTNAME}_${ENVDEPLOY}"                                  # Name of the application
DJANGODIR=/home/deploy/${ENVDEPLOY}/${PROJECTNAME}       # Django project directory
SOCKETFILE=\${DJANGODIR}/run/gunicorn.sock             # we will communicte using this unix socket
#BIND="0.0.0.0:8888"                                   # we will communicte using TCP
LOGFILE=\${DJANGODIR}/log/gunicorn.log  # we will communicte using this unix socket
LOGLEVEL=debug
USER=deploy                                            # the user to run as
GROUP=deploy                                           # the group to run as
NUM_WORKERS=3                                          # how many worker processes should Gunicorn spawn
TIMEOUT=120
DJANGO_SETTINGS_MODULE=${PROJECTNAME}.settings         # which settings file should Django use
DJANGO_WSGI_MODULE=${PROJECTNAME}.wsgi                 # WSGI module name

echo "Starting $NAME as \`whoami\` on \`echo \${DJANGODIR} | cut -d '/' -f 3\`"

# Activate the virtual environment
cd \$DJANGODIR
source ./bin/activate
export DJANGO_SETTINGS_MODULE=\$DJANGO_SETTINGS_MODULE
#export PYTHONPATH=\$DJANGODIR:\$PYTHONPATH

# Create the run directory if it doesn't exist
LOGDIR=\$(dirname \$LOGFILE)
test -d \$LOGDIR || mkdir -p \$LOGDIR
RUNDIR=\$(dirname \$SOCKETFILE)
test -d \$RUNDIR || mkdir -p \$RUNDIR


# Start your Django Unicorn
# Programs meant to be run under supervisor should not daemonize themselves (do not use --daemon)
exec ./bin/gunicorn \${DJANGO_WSGI_MODULE}:application \\
  --name \${NAME} \\
  --workers \${NUM_WORKERS} \\
  --user=\${USER} --group=\${GROUP} \\
  --bind=unix:\${SOCKETFILE} \\
  --log-level=\${LOGLEVEL} \\
  --timeout=\${TIMEOUT} \\
  --log-file=\${LOGFILE}

# End
EOF

#-- Run script to test
chmod 755 script/gunicorn.start
#-- Set Owner
cd /home/deploy/production
chown deploy:deploy ${PROJECTNAME} -R
cd -
./script/gunicorn.start

#-- Check log
tail -f ./log/gunicorn.log



# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
#-- Supervisor

#-- install
apt-get install supervisor

#-- Config File
cat << EOF > /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/config/supervisor.conf
[program:${PROJECTNAME}_${ENVDEPLOY}]
command = /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/script/gunicorn.start 
user = deploy
stdout_logfile = /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/log/supervisor.log
redirect_stderr = true
environment=LANG=en_US.UTF-8,LC_ALL=en_US.UTF-8
EOF

ln -s /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/config/supervisor.conf /etc/supervisor/conf.d/${PROJECTNAME}_${ENVDEPLOY}.conf

#-- Init Daemon
/etc/init.d/supervisor start

#-- Run to setup
supervisorctl reread
supervisorctl update
supervisorctl start ${PROJECTNAME}

#-- Controls stop and start project Service
supervisorctl status ${PROJECTNAME}_${ENVDEPLOY}
supervisorctl stop ${PROJECTNAME}_${ENVDEPLOY}
supervisorctl start ${PROJECTNAME}_${ENVDEPLOY}
supervisorctl restart ${PROJECTNAME}_${ENVDEPLOY}

# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------------------

#-- Pay Attention
#-- If Apache installed, change the nginx project port

#-- NGinx
apt-get install nginx

export NGINX_LISTEN=8001
export NGINX_SERVERNAME=localhost.localdomain

#-- sites-available

cat << EOF > /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/config/nginx.conf
upstream ${PROJECTNAME}_${ENVDEPLOY} {
  server unix:/home/deploy/${ENVDEPLOY}/${PROJECTNAME}/run/gunicorn.sock fail_timeout=0;
}

server {

    listen ${NGINX_LISTEN};
    server_name ${NGINX_SERVERNAME};
    client_max_body_size 4G;
    access_log /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/log/nginx-access.log;
    error_log /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/log/nginx-error.log;
    location /static/ {
        alias   /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/${PROJECTNAME}/static/;
    }
    location /media/ {
        alias   /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/media/;
    }
    location / {
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_redirect off;
        if (!-f \$request_filename) {
            proxy_pass http://unix:/home/deploy/${ENVDEPLOY}/${PROJECTNAME}/run/gunicorn.sock;
            break;
        }
        proxy_connect_timeout 300s;
        proxy_read_timeout 300s;
    }

    # Error pages
    error_page 500 502 503 504 /500.html;
    location = /500.html {
        root /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/apps/static/;
    }
}
EOF

#-- Ativar
ln -s /home/deploy/${ENVDEPLOY}/${PROJECTNAME}/config/nginx.conf /etc/nginx/sites-available/${PROJECTNAME}_${ENVDEPLOY}
ln -s /etc/nginx/sites-available/${PROJECTNAME}_${ENVDEPLOY} /etc/nginx/sites-enabled/${PROJECTNAME}_${ENVDEPLOY}

#-- Start
/etc/init.d/nginx restart

tail /var/log/nginx/error.log


#-- Set Permissions
cd /home/deploy/${ENVDEPLOY}
chown deploy:deploy ${PROJECTNAME} -R






