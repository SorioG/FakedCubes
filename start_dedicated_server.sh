# This shell script assumes that godot is in /usr/bin or any PATH directories.
# This will start the dedicated server for development purposes.
# You probably don't need this if you export this project to dedicated servers.

godot --headless --dediserver "$@"
