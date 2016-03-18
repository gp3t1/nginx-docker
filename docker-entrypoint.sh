#!/bin/bash

CFG_DIR=/etc/nginx/conf.d
CFG_FILE=$CFG_DIR/nginx.conf
CFG_APPS=$CFG_DIR/sites-enabled
DHPARAM_FILE=$CFG_DIR/dhparam.pem
PROXYCFG_FILE=$CFG_DIR/proxy_conf
MIMETYPE_FILE=$CFG_DIR/mime.types

function check_dhparam {
	if [[ ! -f $DHPARAM_FILE ]]; then
		echo "$DHPARAM_FILE not found : Generating..."
		local debut=$( date +%s )
		openssl dhparam -out "$DHPARAM_FILE" 2048
		local fin=$( date +%s )
		if [[ -f "$DHPARAM_FILE" ]]; then
			echo "...generated in (( $fin - $debut ))s."
			return 0
		else
			return 1
		fi
	fi
}

function check_mime {
	if [[ ! -f "$MIMETYPE_FILE" ]]; then
		cp "/etc/nginx/mime.types" "$MIMETYPE_FILE"
	fi
}

function check_proxyconf {
	if [[ ! -f "$PROXYCFG_FILE" ]]; then
		cat > "$PROXYCFG_FILE" <<-EOF
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Real-IP  \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

		proxy_set_header Accept-Encoding "";
		proxy_set_header X-Forwarded-Proto \$scheme;
		
		client_max_body_size    1m;
		client_body_buffer_size 8k;
		
		proxy_connect_timeout   10;
		proxy_send_timeout      10;
		proxy_read_timeout      10;

		#proxy_buffering         off;
		#proxy_buffer_size       4k;
		proxy_buffers           32 4k;
		
		EOF
	fi
}

function write_configfile {
	if [[ -f $CFG_FILE ]] ; then
		echo "Config file already created!"
		return 0
	fi
	cat > "$CFG_FILE" <<-EOF
	user nginx;
	worker_processes 1;
	pid ${PID};
	
	events {
	  worker_connections  1024;
	  # worker_processes and worker_connections allows you to calculate maxclients value: max_clients = worker_processes * worker_connections
	}

	http {
	  include /etc/nginx/conf.d/mime.types;
	  include /etc/nginx/conf.d/proxy_conf;
	  default_type application/octet-stream;
	  #log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
	  #                  '\$status \$body_bytes_sent "\$http_referer" '
	  #                  '"\$http_user_agent" "\$http_x_forwarded_for"';
	  error_log /var/log/nginx/error.log warn;
	  sendfile        off;
	  
	  include ${CFG_APPS}/*.conf;

	}

	# All http traffic will be reroute to https
	server {
    listen 80;
    server_name *;
    access_log /var/log/nginx/http-access.log combined buffer=16k;
    error_log  /var/log/nginx/http-error.log  warn;
    location / {
      return 301 https://$host$request_uri;
    }
  }
	EOF
	[[ -f "$CFG_FILE" ]]
}

function test_nginx {
	echo "Testing nginx configuration"
	nginx -t -c ${CFG_FILE} -g "daemon off;"
}

function run_nginx {
	echo "Starting nginx..."
	chmod -R 660 ${CFG_DIR}
	exec nginx -c ${CFG_FILE} -g "daemon off;"
	exit $?
}

function wait_config {
	local start=$(date +%s)
	echo -n "Waiting for a config file(timeout=$TIMEOUT_CFG)"
	while [[ ! -f "$CFG_FILE" ]]; do
		sleep 1
		echo -n "."
		local tstamp=$(date +%s)
		[[ $(( tstamp - start )) -gt $(( TIMEOUT_CFG + 5 )) ]] && break
	done
}

function main {
	if ! check_dhparam; then
		echo "Error generating dhparam ($DHPARAM_FILE) !"
		exit 1
	fi
	if ! check_mime; then
		echo "Error retrieving mime.types !"
		exit 2
	fi
	if ! check_proxyconf; then
		echo "Error generating proxy_conf !"
		exit 3
	fi
	if ! write_configfile; then
		echo "Cannot find/generate nginx config file !"
		exit 4
	fi
	if ! letsencrypt_renew; then
		echo "Cannot Generate/Renew ssl certificate with LetsEncrypt..."
		exit 5
	fi
	if ! test_nginx; then
		echo "Error in configuration ($CFG_FILE) !"
		exit 6
	fi

	case $1 in
		nginx )
			run_nginx
			;;
		*)
			exit 0
			;;
	esac
}

main "$@"

