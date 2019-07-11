[System.Net.ServicePointManager]::SecurityProtocol += 'tls12'

$LMSURL     = "https://host.blackboard.com"
$key        = "key"
$secret     = "secret"

$resultLimit = '100'
$testCourseID = "course_id"


function doAuthenticate ($thisHost, $thisKey, $thisSecret)
{
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $thisKey,$thisSecret)))
    $body = "grant_type=client_credentials"
    $apiuri = "$thisHost/learn/api/public/v1/oauth2/token"

    try {
        $authResponse = Invoke-RestMethod -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -body $body -Uri $apiuri -Method Post
    }
    catch {
        write-host "Error calling API at $apiuri`n$_"
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        exit
    }

    $expires_in = [int]($authResponse.expires_in / 60)
    $token = $authResponse.access_token

    write-host "Token: $token expires in $expires_in minutes"
    return $token
    # todo: routine to refresh token if less than X minutes remain
    # End Authenticate
}



function getUsers ($thisHost, $thisToken, $thisCourseId)
{
    $coursePath = "/learn/api/public/v1/courses/courseId:$thisCourseId"
    $extPath = "/users?expand=user&fields=user.id,user.externalId,user.userName,user.studentId&limit=$resultLimit"
    $fullPath = $coursePath + $extPath
    

    while ($fullPath.Length -gt 0){
        $apiuri = $thisHost + $fullPath

        try {
            $membersResponse = Invoke-RestMethod -Headers @{Authorization=("Bearer $thisToken")} -Uri $apiuri -Method "GET"
        } catch {
            write-host "Error calling API at $apiuri`n$_"
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            exit
        }
        $fullPath = $membersResponse.paging.nextPage
        $users = $users + $membersResponse.results.user
    }
    return $users
}

function getMeetings ($thisHost, $thisToken, $thisCourseId)
{
    $coursePath = "/learn/api/public/v1/courses/courseId:$thisCourseId"
    $extPath = "/meetings?limit=$resultLimit"
    $fullPath = $coursePath + $extPath
    

    while ($fullPath.Length -gt 0){
        $apiuri = $thisHost + $fullPath

        try {
            $meetingsResponse = Invoke-RestMethod -Headers @{Authorization=("Bearer $thisToken")} -Uri $apiuri -Method "GET"
        } catch {
            write-host "Error calling API at $apiuri`n$_"
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            exit
        }
        $fullPath = $meetingsResponse.paging.nextPage
        $meetings = $meetings + $meetingsResponse.results
    }
    return $meetings
}

function getRecords ($thisHost, $thisToken, $thisCrsId, $thisMeetingId)
{
    $coursePath = "/learn/api/public/v1/courses/$thisCrsId"
    $extPath = "/meetings/$thisMeetingId/users?limit=$resultLimit"
    $fullPath = $coursePath + $extPath

    while ($fullPath.Length -gt 0){
        $apiuri = $thisHost + $fullPath

        try {
            $recordsResponse = Invoke-RestMethod -Headers @{Authorization=("Bearer $thisToken")} -Uri $apiuri -Method "GET"
        } catch {
            write-host "Error calling API at $apiuri`n$_"
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            exit
        }
        $fullPath = $recordsResponse.paging.nextPage
        $records = $records + $recordsResponse.results
    }
    return $records

}



$token = doAuthenticate $LMSURL $key $secret

Clear-Variable -Name members
$members = getUsers $LMSURL $token $testCourseID
$members | Format-Table -Property id, userName, externalId, studentId
$membersCount = $members.Length

Clear-Variable -Name meetings
$meetings = getMeetings $LMSURL $token $testCourseID 
$meetings | Format-Table -Property id, courseId, start, end
$meetingCount = $meetings.Length


Clear-Variable -Name allRecords
foreach ($meeting in $meetings)
{
    $records = getRecords $LMSURL $token $meeting.courseId $meeting.id
    $allRecords = $allRecords + $records
}
$allRecords | Format-Table -Property id, meetingId, userId, status
$recordCount = $allRecords.Length

foreach ($record in $allRecords)
{
    $usr = $members | where {$_.id -eq $record.userId}
    $meet = $meetings | where {$_.id -eq $record.meetingId}
    #todo:  combine record, usr and meet
    
}





