### CONFIGS

<#
    All Prompted variables are set with default values but are set later with console prompts.
    Once prompted values are set, the script will continuously loop using whatever you set.
    If you need to change the parameters, you must restart the script.

    IntervalInMinutes - Interval in Minutes(if OnTheMark = True, valid values are 5,10,15,20,30,60).
                        Otherwise, recommended values range from 5 to 600
    OnTheMark         - If true, script will take the IntervalInMinutes and perform MOD math to determine time.
                        This makes script execute (for example) every hour on the hour, or every 30 minutes on the hour/half hour mark.
    Log Files
        Each log file name is based on the date and time (down to the second).
        If you start, stop and restart the script, you will have 2 log files.
#>


### Working Directories for Speedtest program and logs  
    [String]$WorkingDirectory = "$PSScriptRoot\#ookla";
    [String]$LoggingDirectory = "$PSScriptRoot\#logs";
    [String]$SpeedTestExe     = "$WorkingDirectory\Speedtest.exe"

### Log file naming convention
    [String]$LogStartDateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss";
    [String]$LogFileName      = "$LoggingDirectory\SpeedTestLog_$($LogStartDateTime).csv";

### Speedtest.exe default argument. Arguments get prepended based on SpecifyServer boolean value.
    [String]$ExeArgs          = "--format=json";

### PlaceHolder
    [datetime]$NextRunTime = Get-Date;

### Prompt-Set Variables
    [Int]$IntervalInMinutes   = 5;
    [Int]$ServerID            = 0;
    [bool]$OnTheMark          = $true;
    
### CODE START

### Prerequisites Check
    Clear-Host;
    Write-Host "--------------------------------"; Write-Host "Speed test will be conducted once all prompts are answered.";
    if(!(Test-Path -Path $WorkingDirectory)){ New-Item -Path $WorkingDirectory -ItemType Directory | Out-Null; };
    if(!(Test-Path -Path $LoggingDirectory)){ New-Item -Path $LoggingDirectory -ItemType Directory | Out-Null; };
    if(!(Test-Path -Path $WorkingDirectory\speedtest.exe)){
        Write-Host "--------------------------------"; Write-Host "Missing Speedtest.exe $WorkingDirectory";        
        [String]$result = Read-Host -Prompt "Would you like to download it now? y/n";
        switch($result.ToUpper()){
            "Y"{
                $HTML = Invoke-WebRequest -Uri "https://www.speedtest.net/apps/cli";
                foreach($Line in $HTML.Links){
                    if($Line.href.ToString().Contains("win64")){
                        Invoke-WebRequest -Uri $Line.href -Method Get -OutFile $WorkingDirectory\temp.zip;
                        Expand-Archive -Path $WorkingDirectory\temp.zip -DestinationPath $WorkingDirectory -Force;
                        Remove-Item -Path $WorkingDirectory\temp.zip;
                        switch(Test-Path -Path $WorkingDirectory\speedtest.exe -and Test-Path -Path $WorkingDirectory\speedtest.md){
                            $true{
                                Write-Warning "Speedtest files have been downloaded and unpacked.";
                            }
                            $false{
                                Write-Warning "Failed to locate Speedtest files... Quitting script."; return;
                            }
                        };
                    };
                };
            }
            "N"{
                Write-Warning "Quitting, you no download needed files :("; return;
            }
            default{
                Write-Warning "Your input was invalid."; return;
            }
        };
    };
    Write-Host "--------------------------------";
    [String]$result = Read-Host -Prompt "Do you want interval times to be 'OnTheMark'? y/n";
    switch($result.ToUpper()){
        "Y"{
            $OnTheMark = $true;
        }
        "N"{
            $OnTheMark = $false;
        }
        default{
            Write-Warning "Your input was invalid."; return;
        }
    };
    Write-Host "OnTheMark has been set to: $OnTheMark";
    Write-Host "--------------------------------";
    switch($OnTheMark){
        $true{ Write-Host "Valid values are: 5,10,15,30 and 60"; }
        $false{ Write-Host "Recommended values: 5-600 (whole numbers)"; }
    };
    $IntervalInMinutes = Read-Host -Prompt "Set the interval between speed tests (in minutes)";
    if($OnTheMark){
        if(!(5,10,15,20,30,60).Contains($IntervalInMinutes)){
            Write-Warning "Script only supports OnTheMark option for intervals 5, 10, 15, 20, 30 & 60"; return;
        };
    };
    Write-Host "IntervalInMinutes has been set to: $IntervalInMinutes";
    Write-Host "--------------------------------";
    [String]$result = Read-Host -Prompt "Would you like to specify a server to use for speed testing? y/n";
    switch($result.ToUpper()){
        "Y"{
            Invoke-Expression -Command "$SpeedTestExe --servers";
            Write-Host "--------------------------------";
            $ServerID = Read-Host -Prompt "Please specify the ID of the server you would like to use (0 to use random)";
            if($ServerID -ne 0){
                $ExeArgs = "--server-id=$ServerID $ExeArgs";
                Write-Host "ServerID has been set to: $ServerID";
            };
        }
        "N"{
        }
        default{
            Write-Warning "Your input was invalid."; return;
        }
    };

### Set CSV Headers
    Write-Host "Setting Log File Headers...";
    Set-Content -Path $LogFileName -Value "DateTime,Jitter.ms,Ping.ms,Ping.L.ms,Ping.H.ms,DL.bps,UL.bps,Loss%,ISP,ExternalIP,Server.ID,Server.Host,Server.Name,Server.City,Server.State,Server.Country,Server.IP,Result.URL";

### Perform Speed Test Loop
    while($true){
        Clear-Host;
        Write-Host "--------------------------------";
        Write-Host "Options Set | IntervalInMinutes = $IntervalInMinutes | OnTheMark = $OnTheMark | SpecifyServer = $SpecifyServer | Executing 'Speedtest.exe $ExeArgs'";
        if($OnTheMark){
            while($true){
                if(((Get-Date).Minute % $IntervalInMinutes -eq 0) -or (Get-Date).Minute -eq 0){
                    $NextRunTime = (Get-Date).AddMinutes($IntervalInMinutes);
                    break;
                };
                Start-Sleep -Seconds 45;
            };
        };
        Write-Host "--------------------------------";
        Write-Host "\|/ DO NOT open the log file while the speed test is running.";
        Write-Host " |  Either stop the script first, or wait for the delay between runtimes."; 
        Write-Host "/|\ It is time! Running Speed Test...Please wait...";
        [Int]$StartMinute = (Get-Date).Minute;
        $J = Invoke-Expression -Command "$SpeedTestExe $ExeArgs" | ConvertFrom-Json;
        while((Get-Date).Minute -eq $StartMinute){ Start-Sleep -Seconds 1; };
        Write-Host "Logging Results...";
        Add-Content -Path $LogFileName -Value "$($J.timestamp),$($J.ping.jitter),$($J.Ping.latency),$($J.Ping.low),$($J.ping.high),$($J.download.bandwidth),$($J.upload.bandwidth),$($J.packetLoss),$($J.isp),$($J.interface.externalIp),$($J.server.id),$($J.server.host),$($J.server.name),$($J.server.location),$($J.server.country),$($J.server.ip),$($J.result.url)";
        Write-Host "Results written to log file $LogFileName ...";
        if(!$OnTheMark){
            $NextRunTime = (Get-Date).AddMinutes($IntervalInMinutes * 60);
            Write-Host "--------------------------------"; Write-Host "Next Speedtest will execute at $NextRunTime ... please wait...";
            Start-Sleep -Seconds ($IntervalInMinutes * 60);
        };
    };
