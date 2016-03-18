FROM nginx:1.9

MAINTAINER Jeremy PETIT "jeremy.petit@gmail.com"

#Install openssl
RUN  apt-get update && apt-get install -y --no-install-recommends openssl \
	&& rm -rf /var/lib/apt/lists/*

#Install letsencrypt-auto (with git)
RUN  apt-get update && apt-get install -y --no-install-recommends git \
	&& git clone https://github.com/letsencrypt/letsencrypt /var/lib/letsencrypt \
	&& /var/lib/letsencrypt/letsencrypt-auto --help \
	&& apt-get purge -y git \
	&& rm -rf /var/lib/apt/lists/*

#Clean default config files
RUN  rm /etc/nginx/conf.d/default.conf \
	&& mv /etc/nginx/nginx.conf /etc/nginx/nginx_original.conf.bak \
	&& mkdir -p /var/run/nginx /var/log/nginx /usr/share/nginx /etc/letsencrypt /backups /etc/nginx/templates
		
##		VOLUMES --------------------------
# 		from nginx image: ["/var/cache/nginx"]
VOLUME ["/var/log/nginx", "/usr/share/nginx", "/etc/nginx/conf.d", "/etc/letsencrypt", "/backups"]
WORKDIR /etc/nginx

##		ENV VARIABLES --------------------
#			FROM nginx : NGINX_VERSION
ENV PID /var/run/nginx/pid
ENV TIMEOUT_CFG 125
ENV LETSENCRYPT_EMAIL ""
ENV PATH "$PATH:/var/lib/letsencrypt"

COPY docker-entrypoint.sh /
COPY bin/* /usr/local/bin/
RUN  chmod +x /usr/local/bin/* /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx"]
