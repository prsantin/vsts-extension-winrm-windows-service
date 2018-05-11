param(
	[Parameter(Mandatory=$True,Position=0)]
	[string]$machines,
	
	[Parameter(Mandatory=$True,Position=1)]
	[string]$adminLogin,
	
	[Parameter(Mandatory=$True,Position=2)]
	[string]$password,
	
	[Parameter(Mandatory=$True,Position=3)]
	[bool]$createUpdateService,
		
	[Parameter(Mandatory=$True,Position=4)]
	[string]$serviceName,
	
	[Parameter(Mandatory=$True,Position=5)]
	[string]$serviceDisplay,
	
	[Parameter(Mandatory=$True,Position=6)]
	[string]$serviceDescription,
	
	[Parameter(Mandatory=$True,Position=7)]
	[string]$physicalPath,
	
	[Parameter(Mandatory=$True,Position=8)]
	[bool]$isLocalSystemAccount,
	
	[Parameter(Mandatory=$True,Position=9)]
	[string]$thisAccount,
	
	[Parameter(Mandatory=$True,Position=10)]
	[string]$thisAccountPassword
)

$adminPass = convertto-securestring -AsPlainText -Force -String $password
$adminCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $adminLogin, $adminPass
			
$out = Invoke-Command -ComputerName $machines -ScriptBlock { 

param(
	[Parameter(Mandatory=$True,Position=0)]
	[string]$machines,
	
	[Parameter(Mandatory=$True,Position=1)]
	[string]$adminLogin,
	
	[Parameter(Mandatory=$True,Position=2)]
	[string]$password,
	
	[Parameter(Mandatory=$True,Position=3)]
	[bool]$createUpdateService,
		
	[Parameter(Mandatory=$True,Position=4)]
	[string]$serviceName,
	
	[Parameter(Mandatory=$True,Position=5)]
	[string]$serviceDisplay,
	
	[Parameter(Mandatory=$True,Position=6)]
	[string]$serviceDescription,
	
	[Parameter(Mandatory=$True,Position=7)]
	[string]$physicalPath,
	
	[Parameter(Mandatory=$True,Position=8)]
	[bool]$isLocalSystemAccount,
	
	[Parameter(Mandatory=$True,Position=9)]
	[string]$thisAccount,
	
	[Parameter(Mandatory=$True,Position=10)]
	[string]$thisAccountPassword
)

$VerbosePreference='Continue'

	Function Logging ($State, $Message) {
		$Datum=Get-Date -format dd.MM.yyyy-HH:mm:ss
		$Text="$Datum - $State"+":"+" $Message"
		Write-Verbose $Text -verbose
	}

	function Initialize() {
	
		if($createUpdateService) {
		
			$exit = (Get-WmiObject -Class Win32_Service -Filter ("Name='" + $serviceName +"'"))
			if($exit) {
				RemoveService
			}
			InstallService
		}else {
			RemoveService
		}
	}

	function InstallService() {
		Logging "INFO" "Installing Service '$serviceName' from path '$physicalPath'"
		$exp = 'New-Service -BinaryPathName "' + $physicalPath + '" -Name "' + $serviceName +  '" -DisplayName "' + $serviceDisplay + '" -Description "' + $serviceDescription + '" -StartupType Automatic '
		if(-Not $isLocalSystemAccount -and $thisAccount -ne $null -and $thisAccountPassword -ne $null){
			Logging "INFO" "Installing Service to account '$thisAccount' "
			$pass = convertto-securestring -AsPlainText -Force -String $thisAccountPassword
			$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $thisAccount, $pass
			$exp = $exp + ' -Credential $cred' 
		}
		Invoke-Expression $exp
	}

	function RemoveService(){
		$exist =  (Get-WmiObject -Class Win32_Service -Filter ("Name='" + $serviceName +"'"))
		if($exist) {
			Logging "INFO" "'$serviceName' running. Trying stop."
			$servId = gwmi Win32_Service -Filter "Name LIKE '$serviceName'" | select -expand ProcessId
			$process = Get-Process -Id $servId
			$timeout = 300
			if($process.Name -ne "Idle"){
				Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
				Logging "INFO" "Command sent..."
				$timeout = 300
				$findProcess = $true 
				while($findProcess){
					if(!$process.HasExited){
						$findProcess = $false
					}
					else{
						Logging "INFO" "Waiting process kill...Waiting until '$timeout' seconds (max)."
						Start-Sleep -Seconds 1
						$timeout = $timeout - 1

						if($timeout -le 0){
							Logging "INFO" "Service process not kill! Trying forced kill!"
							Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
							Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
							Start-Sleep -Seconds 3
							$findProcess = $false
						}					
					}
				}
			}
			else{
				Logging "INFO" "Service stopped."
			}			
			
			$exist.Delete()
			Logging "INFO" "Service deleted, waiting 3 seconds..."
			Start-Sleep -s 3
		}
	}

	Initialize

} -Credential $adminCred -ArgumentList $machines, $adminLogin, $password, $createUpdateService, $serviceName, $serviceDisplay, $serviceDescription, $physicalPath, $isLocalSystemAccount, $thisAccount, $thisAccountPassword

$out