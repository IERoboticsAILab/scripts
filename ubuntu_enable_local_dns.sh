sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
cp /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.bak
config=$(cat /etc/NetworkManager/NetworkManager.conf)
if [[ $config == *dns=default* ]]; then
    line_number=$(grep -n "\[main\]" /etc/NetworkManager/NetworkManager.conf | cut -d: -f1)
    sed -i "$line_number a dns=10.205.10.3" /etc/NetworkManager/NetworkManager.conf
fi
cp /etc/resolv.conf /etc/resolv.conf.bak
rm /etc/resolv.conf
sudo systemctl restart NetworkManager
