Param(
    [string]$CRSID,
    [string]$PROP
)


# Import and set Constants
$workingCourse = $CRSID
$Props = convertfrom-stringdata (get-content ./$PROP -raw)
$Props | Format-Table


$LMSURL = $Props.host
$key = $Props.key
$secret= $Props.secret
$resultLimit = $Props.resultLimit


# Authentication Function returns auth token
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

# Function to get all users enrolled in course
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

# Function to get all the attendance meetings for the course
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

# Function to get all the attendance record from Course/Meeing pair
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

# BEGIN SCRIPT

[System.Net.ServicePointManager]::SecurityProtocol += 'tls12'
$token = doAuthenticate $LMSURL $key $secret

$members = getUsers $LMSURL $token $workingCourse
#$members | Format-Table -Property id, userName, externalId, studentId
$memberCount = $members.Length

$meetings = getMeetings $LMSURL $token $workingCourse 
#$meetings | Format-Table -Property id, courseId, start, end
$meetingCount = $meetings.Length

foreach ($meeting in $meetings)
{
    $recs = getRecords $LMSURL $token $meeting.courseId $meeting.id
    $allRecords = $allRecords + $recs
}
#$allRecords | Format-Table -Property id, meetingId, userId, status
$recordCount = $allRecords.Length

$output = @()
foreach ($rec in $allRecords)
{
    $usr = $members | where {$_.id -eq $rec.userId}
    $meet = $meetings | where {$_.id -eq $rec.meetingId}
    $outputRecord = @{
            "course_id" = $workingCourse
            "courseId" = $meet.courseId
            "recordId" = $rec.id
            "meetingId" = $meet.id
            "userId" = $usr.id
            "userName" = $usr.UserName
            "externalId" = $usr.externalId
            "studentId"= $usr.studentId
            "start" = $meet.start
            "status" = $rec.status
    }
    $output += New-Object PSObject -Property $outputRecord
}

Write-Host "Course $workingCourse has $memberCount members, $meetingCount meetings, and $recordCount attendance records."

$Output | Sort-Object "start" | Format-Table
$Output | Export-Csv -Path .\$workingCourse.attendance.csv -NoTypeInformation

Remove-Variable * -ErrorAction SilentlyContinue