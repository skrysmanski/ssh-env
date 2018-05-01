# Enable exit-on-error
set -e

REPO_URL="https://github.com/skrysmanski/ssh-env"

command -v git >/dev/null 2>&1 || {
	echo "ERROR: Git is not installed"
	echo "Check $REPO_URL#required-software for details."
	echo
	exit 1
}

echo "Installing ssh-env..."
echo
echo "Where do you want to install ssh-env? [~/ssh-env]:"
read install_dir

if [ -z "$install_dir" ]; then
	install_dir="~/ssh-env"
fi

# Replace ~ with $HOME so that this actually works.
install_dir="${install_dir/#\~/$HOME}"

if [ -d "$install_dir" ]; then
	echo "ERROR: This directory already exists."
	exit 1
fi

# Prevent the cloned repository from having insecure permissions.
umask g-rwx,o-rwx

echo

# --depth=1 only grabs the newest revision
git clone --depth=1 $REPO_URL.git "$install_dir" || {
	echo "ERROR: git clone of ssh-env repo failed"
	exit 1
}

echo
echo "ssh-env has been installed successfully"
