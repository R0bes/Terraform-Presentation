
#Remove-Item *.svg

$Files = Get-ChildItem ".\draw.io\"

for ($i=0; $i -lt $Files.Count; $i++) {
    draw.io -x -f svg -o $($files[$i].BaseName + ".svg") $files[$i].FullName
}

