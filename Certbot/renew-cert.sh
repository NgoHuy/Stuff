#!/bin/bash
cd /root/certbot
./certbot-auto certonly --renew-by-default  --dns-cloudflare --dns-cloudflare-credentials ~/.secret-auth -d infosec.xyz -d dns.infosec.xyz
systemctl restart nginx

function get_expired_date() {
echo "Q" | openssl s_client -connect $1 2>/dev/null | openssl x509 -noout -dates | grep notAfter | awk '{printf("%s %s %s %s", $1, $2,$3,$4)}' | sed 's/notAfter=//g'
}

declare -A domains
domains=(['infosec']='infosec.xyz:443' ['dns']='dns.infosec.xyz:8443')

declare -A expired_date
declare -A epoc
declare -A renew_date

for domain in ${!domains[@]}
do
  expired_date["$domain"]="$(get_expired_date ${domains["$domain"]})"
  epoc["$domain"]=$(date -d "${expired_date["$domain"]} GMT" +'%s')
  epoc["$domain"]=$((${epoc["$domain"]}-1800))
  renew_date["$domain"]="${epoc["$domain"]}"
done

if [[ ${epoc["infosec"]} -gt ${epoc["dns"]}  ]]
then
  sed -i "s/OnCalendar=.*/OnCalendar=$(date -d @"${epoc["dns"]}" +'%Y-%m-%d %H:%M:00')/g" /etc/systemd/system/certbot.timer
else
  sed -i "s/OnCalendar=.*/OnCalendar=$(date -d @"${epoc["infosec"]}" +'%Y-%m-%d %H:%M:00')/g" /etc/systemd/system/certbot.timer
fi

systemctl daemon-reload
