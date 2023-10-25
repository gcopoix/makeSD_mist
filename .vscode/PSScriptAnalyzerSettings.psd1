# https://learn.microsoft.com/de-de/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules

@{
	Severity=@('Error','Warning','Information')
	ExcludeRules=@('PSAvoidUsingCmdletAliases',
	               'PSAvoidUsingWriteHost',
	               'PSUseApprovedVerbs',
	               'PSReviewUnusedParameter'
	               'PSAvoidUsingPositionalParameters'
	              )
}
