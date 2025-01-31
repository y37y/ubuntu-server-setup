#!/bin/bash

# Disable touch screen for Dell Laptop from startup ubuntu

# Create the script file
sudo bash -c 'cat <<EOL > /etc/X11/Xsession.d/99-disable-touchscreen.sh
#!/bin/bash

# Disable touchscreen device with ID 10
xinput disable 10
EOL'

# Make the script executable
sudo chmod +x /etc/X11/Xsession.d/99-disable-touchscreen.sh

echo "Touchscreen disable script has been created and made executable."

