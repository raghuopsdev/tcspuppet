# Hands-on Lab: Puppet 8 Master-Agent Setup on Azure
**Lab Goal:** Provision two Ubuntu VMs on Azure, install Puppet Server and Agent, establish secure CA SSL trust, configure auto-signing, and execute your first live catalog run.

---

## 📋 Prerequisites & Prerequisites Check
* Active Microsoft Azure Subscription.
* Azure CLI installed or Azure Cloud Shell access.
* Basic SSH key pair generated on your local computer.

---

## Step 1: Provision Azure Virtual Machines

Run the following commands in **Azure Cloud Shell (Bash)** or your local terminal with Azure CLI:


# 1. Create Resource Group
az group create --name rg-puppet-training --location eastus


# 2. Provision Puppet Server VM (Requires 8GB RAM for JVM)
az vm create \
  --resource-group rg-puppet-training \
  --name puppet-server \
  --image Ubuntu2404 \
  --size Standard_D2s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys

# 3. Provision Puppet Agent VM
az vm create \
  --resource-group rg-puppet-training \
  --name puppet-agent-01 \
  --image Ubuntu2404 \
  --size Standard_D2s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys

# 4. Open TCP Port 8140 on Puppet Server Network Security Group (NSG)
az vm open-port --port 8140 --resource-group rg-puppet-training --name puppet-server --priority 1001
//az network nsg rule list --resource-group rg-puppet-training --nsg-name puppet-serverNSG --output table

## Step 2: Configure Hostnames & Local DNS Resolution

Obtain the private IP addresses of both VMs from Azure Portal or CLI:


# Fetch Private IPs
az vm list-ip-addresses --resource-group rg-puppet-training -o table


VirtualMachine    PublicIPAddresses    PrivateIPAddresses
----------------  -------------------  --------------------
puppet-agent-01   20.121.197.22        10.0.0.5
puppet-server     20.127.16.137        10.0.0.4

### On BOTH VMs (`puppet-server` AND `puppet-agent-01`):
SSH into each VM and update `/etc/hosts`:

 vi /etc/hosts


Add the private IP mapping (replace with your actual Azure private IPs):

10.0.0.4  puppet-server puppet
10.0.0.5  puppet-agent-01 puppet-agent-01

Test DNS resolution by pinging each host:

ping -c 2 puppet-server
ping -c 2 puppet-agent-01
```

---

## Step 3: Install & Configure Puppet Server (`puppet-server`)

SSH into `puppet-server`:

```bash
# 1. Download and install OpenVox / Puppet 8 Repository
wget https://apt.voxpupuli.org/openvox8-release-ubuntu24.04.deb
 dpkg -i openvox8-release-ubuntu24.04.deb
 apt update

# 2. Install Puppet Server Package
 apt install -y openvox-server

# 3. Configure JVM Memory allocation (Optional: adjust if using 4GB VM)
 vi /etc/default/puppetserver
# Ensure JAVA_ARGS="-Xms2g -Xmx2g"

# 4. Edit puppet.conf
 vi /etc/puppetlabs/puppet/puppet.conf

Add the following under `[main]` and `[server]` sections:

[main]
certname = puppet-server
server = puppet-server
runinterval = 30m

[server]
dns_alt_names = puppet,puppet-server,puppet-server

# 5. Start and Enable Puppet Server Service
systemctl daemon-reload
systemctl enable --now puppetserver

# Verify service status
 systemctl status puppetserver


## Step 4: Install & Configure Puppet Agent (`puppet-agent-01`)

SSH into `puppet-agent-01`:

```bash
# 1. Download and install OpenVox / Puppet Repository
wget https://apt.voxpupuli.org/openvox8-release-ubuntu24.04.deb
 dpkg -i openvox8-release-ubuntu24.04.deb
 apt update

# 2. Install Puppet Agent Package
apt install -y openvox-agent

# 3. Configure puppet.conf on Agent
vi /etc/puppetlabs/puppet/puppet.conf


Add the following config:

[main]
server = puppet-server-01
certname = puppet-agent-01


//Set the export path
echo 'export PATH=$PATH:/opt/puppetlabs/bin' >> ~/.bashrc
source ~/.bashrc

## Step 5: Establish SSL CA Certificate Trust

### On Agent Node (`puppet-agent-01`):
Initiate the first Certificate Signing Request (CSR):

 /opt/puppetlabs/bin/puppet agent -t


*(Expected Output: Agent generates keys and submits CSR to `puppet-server`, then waits for signing).*

### On Server Node (`puppet-server`):
List pending certificate requests:

// /opt/puppetlabs/bin/puppetserver ca list

# puppetserver ca list


Sign the agent's certificate request:
// /opt/puppetlabs/bin/puppetserver ca sign --certname puppet-agent-01

# puppetserver ca sign --certname puppet-agent-01


### Test on Agent Node (`puppet-agent-01`):
Re-run the agent test command:


// /opt/puppetlabs/bin/puppet agent -t
# puppet agent -t

*(Expected Output: Successful run retrieving catalog with 0 managed resources).*

---

## Step 6: Configure Auto-Signing (`autosign.conf`)

To auto-approve new agents in trusted domains without manual CLI intervention:

On `puppet-server`:

 vi /etc/puppetlabs/puppet/autosign.conf


Add domain whitelist entries:

*
puppet-agent-01
```

Save and set permissions:
```bash
 chmod 644 /etc/puppetlabs/puppet/autosign.conf
```

---

## Step 7: Create & Enforce Your First Manifest

On `puppet-server`, create a starter manifest in the default production directory:

```bash
 vi /etc/puppetlabs/code/environments/production/manifests/site.pp
```

Add the following Puppet resource declarations:
```puppet
node default {
  # Ensure Nginx package is installed
  package { 'nginx':
    ensure => installed,
  }

  # Manage index HTML file
  file { '/var/www/html/index.html':
    ensure  => file,
    content => "<h1>Hello from Puppet Master!</h1>\n<p>Node configured automatically via Puppet Catalog.</p>\n",
    require => Package['nginx'],
  }

  # Ensure Nginx service is active and running
  service { 'nginx':
    ensure    => running,
    enable    => true,
    subscribe => File['/var/www/html/index.html'],
  }
}
```

### Enforce Manifest on Agent (`puppet-agent-01`):
Execute the agent trigger:

```bash
# puppet agent -t
```

### Verification:
Test the running service on `puppet-agent-01`:
```bash
curl http://localhost
```
*(Expected Output: HTML page displaying "Hello from Puppet Master!").*

---

## Step 8: Test Idempotency & Configuration Drift Self-Healing

1. **Test Drift Creation:** Manually tamper with the file on `puppet-agent-01`:
   ```bash
    echo "Tampered data" > /var/www/html/index.html
   ```
2. **Re-enforce State via Puppet Agent:**
   ```bash
    /opt/puppetlabs/bin/puppet agent -t
   ```
3. **Verify Remediation:** Puppet detects the content drift, restores the original HTML content defined in `site.pp`, and reloads Nginx!

//To Remove and stop Nginx
apt-get purge --auto-remove nginx nginx-common nginx-core
apt-get remove nginx
systemctl stop nginx
 echo "Tampered data" > /var/www/html/index.html