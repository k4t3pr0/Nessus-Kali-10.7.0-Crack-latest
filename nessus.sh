#!/bin/bash
if [[ $(id -u) -ne 0 ]]; then echo "Please run as root" ; exit 1 ; fi
echo "//=============================================================="
echo "   Nessus latest Download, Install, and Crack by k4t3pr0"
echo "   Special thanks to John Doe for showing this works on Debian"
echo "   Thanks hunganhprox for tip about Latest as a version number"
echo "//=============================================================="
echo " + Added anti-skid additional function, removed all chattr settings 20231013"
chattr -i -R /opt/nessus
echo " + Ensuring we have prerequisites.."
apt update &>/dev/null
apt -y install curl dpkg expect &>/dev/null
echo " + Stopping old nessusd service if there's one!"
/bin/systemctl stop nessusd.service &>/dev/null
echo " + Downloading Nessus.."
curl -A Mozilla --request GET \
  --url 'https://www.tenable.com/downloads/api/v2/pages/nessus/files/Nessus-latest-debian10_amd64.deb' \
  --output 'Nessus-latest-debian10_amd64.deb' &>/dev/null
{ if [ ! -f Nessus-latest-debian10_amd64.deb ]; then
  echo " + Nessus download failed :/ Exiting. Get a copy from t.me/pwn3rzs"
  exit 0
fi }
echo " + Installing Nessus.."
dpkg -i Nessus-latest-debian10_amd64.deb &>/dev/null

echo " + Starting the service for the first initialization (must be done)"
/bin/systemctl start nessusd.service &>/dev/null
echo " + Letting Nessus initialize, waiting for about 20 seconds..."
sleep 20
echo " + Stopping nessus service.."
/bin/systemctl stop nessusd.service &>/dev/null
echo " + Changing nessus settings to Zen preferences (Free Warrior mode)"
echo "   Listening port: 11127"
/opt/nessus/sbin/nessuscli fix --set xmlrpc_listen_port=11127 &>/dev/null
echo "   Theme: Dark"
/opt/nessus/sbin/nessuscli fix --set ui_theme=dark &>/dev/null
echo "   Security checks: Off"
/opt/nessus/sbin/nessuscli fix --set safe_checks=false &>/dev/null
echo "   Log: Performance"
/opt/nessus/sbin/nessuscli fix --set backend_log_level=performance &>/dev/null
echo "   Updates: Off"
/opt/nessus/sbin/nessuscli fix --set auto_update=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set auto_update_ui=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set disable_core_updates=true &>/dev/null
echo "   Telemetry: Off"
/opt/nessus/sbin/nessuscli fix --set report_crashes=false &>/dev/null
/opt/nessus/sbin/nessuscli fix --set send_telemetry=false &>/dev/null
echo " + Adding a user, can change later (Username: admin, Password: admin)"
cat > expect.tmp<<'EOF'
spawn /opt/nessus/sbin/nessuscli adduser admin
expect "Login password:"
send "admin\r"
expect "Login password (again):"
send "admin\r"
expect "*(can upload plugins etc)? (y/n)*"
send "y\r"
expect "*(user can have an empty rules set)"
send "\r"
expect "Is that ok*"
send "y\r"
expect eof
EOF
expect -f expect.tmp &>/dev/null
rm -rf expect.tmp &>/dev/null
echo " + Downloading new plugins.."
curl -A Mozilla -o all-2.0.tar.gz \
  --url 'https://plugins.nessus.org/v2/nessus.php?f=all-2.0.tar.gz&u=4e2abfd83a40e2012ebf6537ade2f207&p=29a34e24fc12d3f5fdfbb1ae948972c6' &>/dev/null
{ if [ ! -f all-2.0.tar.gz ]; then
  echo " + Plugin all-2.0.tar.gz download failed :/ Exiting. Get a copy from t.me/pwn3rzs"
  exit 0
fi }
echo " + Installing plugins.."
/opt/nessus/sbin/nessuscli update all-2.0.tar.gz &>/dev/null
echo " + Fetching version number.."
# I used to see this for incorrect download. Well, but it works for me.
vernum=$(curl https://plugins.nessus.org/v2/plugins.php 2> /dev/null)
echo " + Building plugin feed..."
cat > /opt/nessus/var/nessus/plugin_feed_info.inc <<EOF
PLUGIN_SET = "${vernum}";
PLUGIN_FEED = "ProfessionalFeed (Direct)";
PLUGIN_FEED_TRANSPORT = "Tenable Network Security Lightning";
EOF
echo " + Protecting files.."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
cp /opt/nessus/var/nessus/plugin_feed_info.inc /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
echo " + Setting all files to immutable..."
chattr +i /opt/nessus/var/nessus/plugin_feed_info.inc &>/dev/null
chattr +i -R /opt/nessus/lib/nessus/plugins &>/dev/null
echo " + But removing immutability of key files.."
chattr -i /opt/nessus/lib/nessus/plugins/plugin_feed_info.inc &>/dev/null
chattr -i /opt/nessus/lib/nessus/plugins  &>/dev/null
echo " + Starting service.."
/bin/systemctl start nessusd.service &>/dev/null
echo " + Wait another 20 seconds for the server to have enough time to start!"
sleep 20
echo " + Monitoring Nessus progress. Following line updates every 10 seconds until 100%"
zen=0
while [ $zen -ne 100 ]
do
 statline=`curl -sL -k https://localhost:11127/server/status|awk -F"," -v k="engine_status" '{ gsub(/{|}/,""); for(i=1;i<=NF;i++) { if ( $i ~ k ){printf $i} } }'`
 if [[ $statline != *"engine_status"* ]]; then echo -ne "\n Issue: Nessus server inaccessible? Trying again..\n"; fi
 echo -ne "\r $statline"
 if [[ $statline == *"100"* ]]; then zen=100; else sleep 10; fi
done
echo -ne '\n  o Complete!\n'
echo
echo "        Access Nessus:  https://localhost:11127/ (or your Server IP)"
echo "             Username: admin"
echo "             Password: admin"
echo "             Changeable anytime"
echo
read -p "Press Enter to continue"
