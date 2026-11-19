//Create a Non-Root Agent User and Install Dependencies

sudo apt-get update && sudo apt-get install -y curl jq libicu-dev
sudo adduser --disabled-password --gecos "" azagent
sudo mkdir -p /opt/azagent
sudo chown -R azagent:azagent /opt/azagent




//2.Download and Extract the Linux Agent Package:


sudo -u azagent -i
mkdir -p /opt/azagent/agent && cd /opt/azagent/agent
curl -L -o agent.tar.gz "<paste-your-vsts-agent-linux-x64-url>"
tar zxvf agent.tar.gz
rm agent.tar.gz

//Configure the Agent Against Azure DevOps:

./config.sh

//Configure the Agent Against Azure DevOps

When prompted:

Server URL: [https://dev.azure.com/](https://dev.azure.com/)<your-organization> (or your Azure DevOps Server / TFS URL).

Authentication type: Press Enter for PAT.

Personal access token: Paste your PAT.

Agent pool: Enter your pool name (for example, linux-lab-pool).

Agent name: Enter a unique name (such as puppet-server-agent) or press Enter for the hostname.

Work folder: Press Enter to accept the default (_work).
Verification: ./config.sh finishes with Enter run agent on startup? / configuration summary without authentication or connectivity errors, and .agent is created in /opt/azagent/agent.

//Install and Start the Systemd Service

exit
cd /opt/azagent/agent
sudo ./svc.sh install azagent
sudo ./svc.sh start
sudo ./svc.sh status
