[CmdletBinding()]
param(
)

Trace-VstsEnteringInvocation $MyInvocation

$projectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
$projectName = $env:SYSTEM_TEAMPROJECT
$repository = Get-VstsInput -Name "repository" -Require
$env:TEAM_AuthType = Get-VstsInput -Name "authenticationType" -Require
$env:TEAM_PAT = $env:SYSTEM_ACCESSTOKEN
$stagingDirectory = $env:BUILD_STAGINGDIRECTORY
$showIssuesOnBuildSummary = [System.Convert]::ToBoolean((Get-VstsInput -Name "showIssuesOnBuildSummary" -Require))

$build = New-Object psobject -Property @{
  BuildId            = $env:SYSTEM_DEFINITIONID
  SourceBranch       = ($env:BUILD_SOURCEBRANCH).Replace("refs/heads/", "")
  BuildReason        = $env:BUILD_REASON
  PullRequestId      = [System.Convert]::ToInt32($env:SYSTEM_PULLREQUEST_PULLREQUESTID)
  RepositoryProvider = $env:BUILD_REPOSITORY_PROVIDER
}

$rules = New-Object psobject -Property @{
  MasterBranch                                 = Get-VstsInput -Name "masterBranch" -Require
  DevelopBranch                                = Get-VstsInput -Name "developBranch" -Require
  HotfixPrefix                                 = Get-VstsInput -Name "hotfixBranches" -Require
  ReleasePrefix                                = Get-VstsInput -Name "releaseBranches" -Require
  FeaturePrefix                                = Get-VstsInput -Name "featureBranches" -Require

  HotfixBranchLimit                            = [System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchLimit" -Require))
  HotfixDaysLimit                              = [System.Convert]::ToInt32((Get-VstsInput -Name "hotfixBranchDaysLimit" -Require))
  ReleaseBranchLimit                           = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchLimit" -Require))
  ReleaseDaysLimit                             = [System.Convert]::ToInt32((Get-VstsInput -Name "releaseBranchDaysLimit" -Require))
  FeatureBranchLimit                           = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchLimit" -Require))
  FeatureDaysLimit                             = [System.Convert]::ToInt32((Get-VstsInput -Name "featureBranchDaysLimit" -Require))

  HotfixeBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixMustNotBeBehindMaster" -Require))
  ReleaseBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseMustNotBeBehindMaster" -Require))
  DevelopMustNotBeBehindMaster                 = [System.Convert]::ToBoolean((Get-VstsInput -Name "developMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindMaster         = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindMaster" -Require))
  FeatureBranchesMustNotBeBehindDevelop        = [System.Convert]::ToBoolean((Get-VstsInput -Name "featureBranchesMustNotBeBehindDevelop" -Require))
  CurrentFeatureMustNotBeBehindDevelop         = [System.Convert]::ToBoolean((Get-VstsInput -Name "CurrentFeatureMustNotBeBehindDevelop" -Require))
  CurrentFeatureMustNotBeBehindMaster          = [System.Convert]::ToBoolean((Get-VstsInput -Name "CurrentFeatureMustNotBeBehindMaster" -Require))
  MustNotHaveHotfixAndReleaseBranches          = [System.Convert]::ToBoolean((Get-VstsInput -Name "mustNotHaveHotfixAndReleaseBranches" -Require))
  MasterMustNotHaveActivePullRequests          = [System.Convert]::ToBoolean((Get-VstsInput -Name "masterMustNotHavePendingPullRequests" -Require))
  HotfixBranchesMustNotHaveActivePullRequests  = [System.Convert]::ToBoolean((Get-VstsInput -Name "hotfixBranchesMustNotHavePendingPullRequests" -Require))
  ReleaseBranchesMustNotHaveActivePullRequests = [System.Convert]::ToBoolean((Get-VstsInput -Name "releaseBranchesMustNotHavePendingPullRequests" -Require))
  BranchNamesMustMatchConventions              = [System.Convert]::ToBoolean((Get-VstsInput -Name "branchNamesMustMatchConventions" -Require))

  BypassBranchesWithNameMatchingPattern        = Get-VstsInput -Name "BypassBranchesWithNameMatchingPattern"

  ErrorOnlyForTheCurrentBranch                 = [System.Convert]::ToBoolean((Get-VstsInput -Name "errorOnlyForTheCurrentBranch" -Require))
}

Write-Output "Project Collection: [$projectCollectionUri]"
Write-Output "Project Name: [$projectName]"
Write-Output "Build Reason: [$($build.BuildId)]"
Write-Output "Build Reason: [$($build.BuildReason)]"
Write-Output "Repository: [$repository]"
Write-Output "Current Branch: [$($Build.SourceBranch)]"
Write-Output "Authentication Type: [$env:TEAM_AUTHTYPE]"
Write-Output "Rules:"
$rules

$scriptLocation = (Get-Item -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)).FullName

#Import Required Modules
Import-Module "$scriptLocation\ps_modules\Custom\team.Extentions.psm1" -Force
Import-Module "$scriptLocation\ps_modules\Custom\BranchRules.psm1" -Force

#Check if the master branches exists
$refs = Get-Branches -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository
$master = $refs.Value | Where-Object { $_.name -eq "refs/heads/$($Rules.MasterBranch)" }
if ($master -eq $null) {
  Write-Error "Could not find remote branch: refs/heads/$($Rules.MasterBranch)"
}

$develop = $refs.Value | Where-Object { $_.name -eq "refs/heads/$($Rules.DevelopBranch)" }
if ($develop -eq $null) {
  Write-Error "Could not find remote branch: refs/heads/$($Rules.DevelopBranch)"
}

#Get All Branches
[System.Object[]]$pullRequests = Get-PullRequests -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -StatusFilter Active | ConvertTo-PullRequests
[System.Object[]]$branchesComparedToDevelop = (Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.DevelopBranch).Value
[System.Object[]]$branches = Get-BranchStats -ProjectCollectionUri $projectCollectionUri -ProjectName $projectName -Repository $repository -BaseBranch $Rules.MasterBranch | ConvertTo-Branches
$branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $branchesComparedToDevelop
$branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests
$branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules

Write-OutputCurrentBranches -Branches $Branches
Write-OutputPullRequests -PullRequests $pullRequests
Write-OutputWarnings -Branches $Branches

$summaryTitle = "Gitflow Branch Gate Report"
$summaryFilePath = "$stagingDirectory\GitflowBranchGate.ReportSummary.md"
Invoke-ReportSummary -Branches $branches -TemplatePath "$scriptLocation\ReportSummary.md" -ReportDestination $summaryFilePath -DisplayIssues $showIssuesOnBuildSummary
Write-Host "##vso[task.addattachment type=Distributedtask.Core.Summary;name=$summaryTitle;]$summaryFilePath"

# $reportFilePath = "$scriptLocation\Report.html"
# Write-Host "##vso[artifact.upload containerfolder=Reports;artifactname=GitflowGateReports;]$reportFilePath"

Write-OutputErrors -Branches $Branches

Trace-VstsLeavingInvocation $MyInvocation