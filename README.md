# PS-Tools
Collection of PowerShell-Scripts

### Update-asCMOfficeApplication
**Installed ConfigMgr-console is required to be able to update the application with the ConfigMgr-PowerShell module**
~~~
Put your configuration.xml file to C:\Office Deployment Toolkit and set $ODTSetupConfigXML
~~~
- Downloads newest Office Deployment Kit
- Downloads newest Office sources
- Copies file to ConfigMgr file share
- Reads the Office applicaiton
- Refreshes the Office application incl. detection method
- Refreshes distribution points

