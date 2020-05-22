Function Check-Spelling(){[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [String] $String,
        [Switch] $ShowErrors,
        [Switch] $RemoveSpecialChars)
    Process{
        If($RemoveSpecialChars){
            $String=Clean-String $String
        }
        ForEach($S in $String){
            $SplatInput=@{
                Uri="https://api.projectoxford.ai/text/v1.0/spellcheck?Proof"
                Method='Post'
            }
            $Headers=@{'Ocp-Apim-Subscription-Key'="XXXXXXXXXXXXXXXXXXXXXXXXXX"}
            $body=@{'text'=$s}
            Try{
                $SpellingErrors=(Invoke-RestMethod @SplatInput -Headers $Headers -Body $body).SpellingErrors
                $OutString=$String # Make a copy of string to replace the errorswith suggestions.
                If($SpellingErrors){  # If Errors are Found
                    ForEach($E in $spellingErrors){ # Nested ForEach to generate the Rectified string Post Spell-Check
                        If($E.Type -eq 'UnknownToken'){ # If an unknown word identified, replace it with the respective sugeestion from the API results
                            $OutString=ForEach($s in $E.suggestions.token){
                                $OutString -replace $E.token, $s
                            }
                        }Else{  # If REPEATED WORDS then replace the set by an instance of repetition
                            $OutString=$OutString -replace "$($E.token) $($E.token) ", "$($E.token) "
                        }
                    }
                    If($ShowErrors -eq $true){ # InCase ShowErrors switch is ON
                        Return $SpellingErrors|Select @{n='ErrorToken';e={$_.Token}},@{n='Type';e={$_.Type}}, @{n='Suggestions';e={($_.suggestions).token|?{$_ -ne $null}}}
                    }Else{ # Else Return the spell checked string
                        Return $OutString 
                    }
                }Else{ # When No error is found in the input string
                    Return "No errors found in the String."
                }
            }Catch{
                "Something went wrong, please try running the script again"
            }
        }
    }
}
# Function to Remove special character s and punctuations from Input string
Function Clean-String($Str){
    ForEach($Char in [Char[]]"!@#$%^&*(){}|\/?><,.][+=-_"){$str=$str.replace("$Char",'')}
    Return $str
}