FROM debian:jessie
MAINTAINER jaekwon park <jaekwon.park@code-post.com>


# Configure apt
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libnss-ldapd libpam-ldapd openssh-server ldap-utils nscd dialog fping rsyslog && \
     apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD entrypoint.sh /usr/local/bin/
ADD ldap_auth.sh /ldap_auth/
ADD userlist.sh /etc/profile.d/

RUN mkdir -p /var/run/sshd && chmod u+x /usr/local/bin/*.sh && chmod -R 755 /ldap_auth

VOLUME /sshd_key /etc/profile.d/

EXPOSE 22

CMD ["entrypoint.sh"]
