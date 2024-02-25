# This shell script will automatically export this project to multiple platforms.

clear

#echo "Exporting Game..."
# Linux
godot --headless --quiet --export-release "Linux/X11" "export/linux/FakedCubes_Linux.zip"
clear
# Windows
godot --headless --quiet --export-release "Windows Desktop" "export/windows/FakedCubes_Windows.zip"
clear

#echo "Exporting Dedicated Server..."
# Linux
godot --headless --quiet --export-release "Linux Dedicated Server" "export/linux/FakedCubes_Linux_Server.zip"
clear
# Windows
godot --headless --quiet --export-release "Windows Dedicated Server" "export/windows/FakedCubes_Windows_Server.zip"
clear

echo "Done Exporting"
