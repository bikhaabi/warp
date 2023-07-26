#!/bin/sh

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

cyan() {
    echo -e "\033[36m\033[01m$1\033[0m"
}


echo | ./wgcf register
chmod +x wgcf-account.toml

clear
yellow "Please select the type of WARP account you want to use"
echo ""
echo -e " ${GREEN}1.${PLAIN} WARP free account ${YELLOW} (default) ${PLAIN}"
echo -e " ${GREEN}2.${PLAIN} WARP+"
echo -e " ${GREEN}3.${PLAIN} WARP Teams"
echo ""
read -p "Please enter options [1-3]: " account_type
if [[ $account_type == 2 ]]; then
  yellow "How to get CloudFlare WARP account key information: "
  green "PC: Download and install CloudFlare WARP → Settings → Preferences → Accounts → Copy key into script"
  green "Mobile: Download and install 1.1.1.1 APP → Menu → Account → Copy the key into the script"
  echo ""
  yellow "Important: Please make sure that the account status of the 1.1.1.1 APP on your mobile phone or computer is WARP+!  "
  echo ""
  read -rp "Enter the WARP account license key (26 characters): " warpkey
  until [[ $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}$ ]]; do
    red "WARP account license key format input error, please re-enter!  "
    read -rp "Enter the WARP account license key (26 characters): " warpkey
  done
  sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml
  read -rp "Please enter a custom device name, if not entered, the default random device name will be used: " devicename
  green "In the registered WARP account, as shown below: 400 Bad Request, then use the WARP free version account"
  if [[ -n $devicename ]]; then
    ./wgcf update --name $(echo $devicename | sed s/[[:space:]]/_/g)
  else
    ./wgcf update
  fi
  ./wgcf generate
elif [[ $account_type == 3 ]]; then
  ./wgcf generate
  chmod +x wgcf-profile.conf
  
  yellow "Please choose the method to apply for a WARP Teams account"
  echo ""
  echo -e " ${GREEN}1.${PLAIN} Use Teams TOKEN ${YELLOW}(default)${PLAIN}"
  echo -e " ${GREEN}2.${PLAIN} Use the extracted xml configuration file"
  echo ""
  read -p "Please enter your choice [1-2]: " team_type

  if [[ $team_type == 2 ]]; then
    yellow "Method to obtain WARP Teams account xml configuration file: https://blog.misaka.rest/2023/02/11/wgcfteam-config/"
    yellow "Please upload the extracted xml configuration file to: https://gist.github.com"
    read -rp "Please paste the WARP Teams account configuration file link: " teamconfigurl
    if [[ -n $teamconfigurl ]]; then
      teams_config=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")
      private_key=$(expr "$teams_config" : '.*private_key&quot;>\([^<]*\).*')
      private_v6=$(expr "$teams_config" : '.*v6&quot;:&quot;\([^[&]*\).*')
      sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" wgcf-profile.conf;
      sed -i "s#Address.*128#Address = $private_v6/128#g" wgcf-profile.conf;
    else
      red "No WARP Teams account configuration file link provided, script exiting!"
      exit 1
    fi
  else
    # Ask the user for the WARP Teams account TOKEN and provide instructions on how to obtain it
    yellow "Please visit this website: https://web--public--warp-team-api--coia-mfs4.code.run/ to obtain your WARP Teams account TOKEN"
    read -rp "Please enter your WARP Teams account TOKEN: " teams_token

    if [[ -n $teams_token ]]; then
      # Generate WireGuard public and private keys, WARP device ID, and FCM Token
      private_key=$(wg genkey)
      public_key=$(wg pubkey <<< "$private_key")
      install_id=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)
      fcm_token="${install_id}:APA91b$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 134)"

      # Use CloudFlare API to request Teams configuration information
      team_result=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
        --header 'User-Agent: okhttp/3.12.1' \
        --header 'CF-Client-Version: a-6.10-2158' \
        --header 'Content-Type: application/json' \
        --header "Cf-Access-Jwt-Assertion: ${team_token}" \
        --data '{"key":"'${public_key}'","install_id":"'${install_id}'","fcm_token":"'${fcm_token}'","tos":"'$(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${install_id}'","locale":"zh_CN"}')

      # Extract the WARP IPv6 internal address to replace the corresponding content in wgcf-profile.conf
      private_v6=$(expr "$team_result" : '.*"v6":[ ]*"\([^"]*\).*')
      
      sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" wgcf-profile.conf;
      sed -i "s#Address.*128#Address = $private_v6/128#g" wgcf-profile.conf;
    fi
  fi
else
  ./wgcf generate
fi

clear
cyan  "t.me/P_tech2024"
green "WGCF WireGuard configuration file has been generated successfully!"
yellow "configuration file content:"
red "$(cat wgcf-profile.conf)"
echo ""
yellow "QR code for sharing the configuration file:"
qrencode -t ansiutf8 < wgcf-profile.conf
echo ""
yellow "Use this method locally: https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ to optimize the available Endpoint IP"
