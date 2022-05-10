#NOTE: This only works with one J-Link, and with only one WSL instance.

#TODO: Make this work in cases where more than one WSL instance is installed / running.

function Error-Handler
{
    Write-Host "`nERROR." -fore Red
    Write-Host "Press any key to exit."

    # Make sure we keep any windows open so the error is noticed
    read-host 
    exit(1)
}

function Good-Exit
{
    Write-Host "`nComplete." -fore Green

    Start-Sleep -Seconds 2
    exit(0)
}

try{
    # this initial Select-String is now redundant, given the RegEx below
    $output = usbipd list | Select-String -Pattern 'J-Link'

    if ($output.Count -eq 0)
    {
        Write-Host "`nNo J-Links were found. Exiting." -fore red
	    Error-Handler
    }

    # We can only handle one J-Link for now
    if ($output.Count -ne 1)
    {
	    Write-Host "`nMore than one J-Link found. Exiting." -fore red
	    Error-Handler
    }

    $output = $output.ToString()

    # Use some RegEx to extract the BusID and the connection status
    $result = $output -match '^([0-9]+-[0-9]+)\s+[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\s+J-Link driver\s+([a-z,A-Z,\s]+)'

    # As the BusID is a long UUID if the device is not connected but is persisted, it will not match the regex  
    if ($result -eq $false)
    {
        Write-Host "`nNo connected J-Links were found. Exiting." -fore red
	    Error-Handler
    }

    $busid = $Matches[1]

    Write-Host "Found a J-Link on BusID $busid" -fore Green

    # Check if the J-Link is already attached to WSL2
    if ($Matches[2] -eq "Attached"){
        #Write-Host "The J-Link is already attached to WSL. Detaching and reattaching." -fore Yellow
        #usbipd wsl detach --busid $busid

        Write-Host "The J-Link is already attached to WSL." -fore Yellow
        Good-Exit
    }

    # Attaching isn't reliable without first doing a service restart in WSL
    wsl -- sudo service udev restart
    wsl -- sudo udevadm control --reload

    # Attach the J-Link to WSL
    usbipd wsl attach --busid $busid

    # Give it 2 seconds to actually attach before checking for success
    # TODO: Perhaps this should loop once or twice, both to allow for a faster confirmation and to account for potentially slower systems?
    Start-Sleep -Seconds 2
    $output = wsl -- lsusb | Select-String -Pattern 'J-Link'
    if ($output.Count -ne 1)
    {
        Write-Host "`nThe J-Link did not attach to WSL." -fore Red
        Error-Handler
    }

    Write-Host "`nThe J-Link is now attached to WSL."

    Good-Exit
}
catch
{
    Error-Handler
}



