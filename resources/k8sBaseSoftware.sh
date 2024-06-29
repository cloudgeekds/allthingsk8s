# Disable swap and persist this setting across reboots
sudo swapoff -a
sudo sed -e '/swap.img/s/^/#/g' -i /etc/fstab

# Update the system
sudo apt update ; sudo apt upgrade -y

# Install the packages needed to use the K8s apt repository
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Add repo for Kubernetes ---- The URL for the repo (line 13) has to be updated everytime a new k8s minor version is going to be deployed (or upgraded to a more recent version)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install the Kubernetes software, and lock the version
sudo apt update
sudo apt -y install kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Ensure Kernel has the required modules loaded
sudo modprobe overlay
sudo modprobe br_netfilter

# Update networking to allow traffic
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Configure containerd settings
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo sysctl --system

# Install the containerd software
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [signed-by=/etc/apt/keyrings/docker.gpg  arch=amd64]  https://download.docker.com/linux/ubuntu "$(lsb_release -cs)" stable" | sudo tee /etc/apt/sources.list.d/containerd.list
sudo apt update
sudo apt install containerd.io -y

# Configure containerd and restart
sudo mkdir -p /etc/containerd
containerd config default
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
sudo sed -e 's/pause:3.8/pause:3.9/g' -i /etc/containerd/config.toml
sudo systemctl restart containerd
cat /etc/containerd/config.toml

#Update crictl configuration to use an up to date notation for the Containerd´s runtime-endpoint
sudo crictl config --set \
runtime-endpoint=unix://///var/run/containerd/containerd.sock