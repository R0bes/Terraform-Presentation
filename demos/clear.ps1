## Clear terraform usage

# Remove .terraform directory
Remove-Item -Recurse ".terraform"

# Remove all files except .tf files
Get-ChildItem -Recurse -File | Where-Object {($_.Extension -ne ".tf")} | Remove-Item 