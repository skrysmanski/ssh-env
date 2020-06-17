# Portable SSH Environment
Ssh-env provides a cross-platform, portable, easy-to-use, and yet secure environment for connecting to SSH servers (via the command line).

Portable in this case means that you can *easily* use the same config and keys on different computers.


## Required Skills
To use ssh-env you already need to know the following:

* How to use the command line (terminal) on your machine.
* How to ssh into a machine via username and password.
* (Theoretical knowledge of) How to ssh into a machine via username and ssh key pair.
* Basic understanding of what the `known_hosts` file is.
* Basic understanding of how to use git.

If you lack knowledge in ssh, Digital Ocean has some great tutorials on [ssh key pairs](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2) and [ssh in general](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys).


## Required Software
To use this project, you need the following pieces of software:

* PowerShell
* OpenSSH (along with its companion tools `ssh-keygen` and `ssh-agent`)
* Git

On Windows, the easiest way to install both SSH and Git is to install [Git for Windows](https://git-for-windows.github.io/). You may also use alternatives like Cygwin if you like but this is untested.

On macOS, Git and SSH are already preinstalled. You only need to install PowerShell; see [Installing PowerShell Core on macOS](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-macos) for more details.

On Linux, SSH is often preinstalled but Git is not. Use the package manager of your Linux distro to install both. To install PowerShell, see [Installing PowerShell Core on Linux](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-powershell-core-on-linux).


## Basic Installation
Ssh-env is installed by simply cloning this repository with `git`.

I recommend you clone ssh-env in your home directory (i.e. `~/ssh-env`) but you can put it anywhere you like.

In the following `git` commands the option `--depth=1` make git clone only the newest commit (i.e. leaving out the whole history). You can drop this option to get the whole history.

**Linux and macOS**

    mkdir ~/ssh-env
    chmod 0700 ~/ssh-env
    git clone --depth=1 https://github.com/skrysmanski/ssh-env.git ~/ssh-env

**Windows**

    mkdir "%USERPROFILE%\ssh-env"
    git clone --depth=1 https://github.com/skrysmanski/ssh-env.git "%USERPROFILE%\ssh-env"


### Verifying the installation
After installing ssh-env, you may want to verify that it's working properly.

To do this, go to the directory where you clone ssh-env and execute:

    $ ./ssh-env version  (Linux and macOS)
    $ ssh-env version    (Windows)

This should give you an output like this:

    ssh-env version 0.9.3
    OpenSSH_7.6p1, LibreSSL 2.6.2
    Using SSH binaries from: /usr/bin


### Notes
* ssh-env works the same on Windows, Linux and macOS. The only difference is that on Windows you use `ssh-env` instead of `./ssh-env`. The rest of this section will use the *Linux style* but it'll work the same way on Windows.
* ssh-env is completely self-contained and will not create or use any files outside of its directory. Thus, you can clone ssh-env as often as you want on your computer - without the copies interfering with each other. (Unless you install the data dir globally; see below for more information on this.)


## Getting started
This chapter describes how you get from zero to your first SSH connection with ssh-env. This process is comprised of three steps:

1. Populating the ssh data dir
1. Installing the public key on the target server
1. Connecting to the target server

**Note:** To go forward, you need to have a server that you can ssh into (via password). For testing purposes, you may use [Vagrant](https://www.vagrantup.com/) to quickly spin up a VM.

### Populating the ssh data dir
Before you can use ssh-env, you need to populate its data directory: `ssh-data`

This directory contains all your personal ssh files and should be versioned with git - so that you can easily transfer its contents to other computers.

The contents of this directory are:

* your ssh key pair (`id_rsa` and `id_rsa.pub`)
* your ssh config (optional)
* your `known_hosts` file

To create this directory from scratch, call:

    $ ./ssh-env datadir init

You'll be asked a series of questions.

**Note:** When you're asked for the "passphrase" for the rsa key pair, it's highly recommended that use **a strong password** here.

```
$ ./ssh-env datadir init
Do you have an SSH key pair (in case of doubt: no)? (y/n): n

Who does this certificate belong to? [manski]:
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /Users/manski/ssh-env/ssh-data/id_rsa.
Your public key has been saved in /Users/manski/ssh-env/ssh-data/id_rsa.pub.
The key fingerprint is:
SHA256:92b8uZazEiM1LmVP/W5Z1yqSxtALoScv9bYwjabwVdA manski
The key's randomart image is:
+---[RSA 4096]----+
|                 |
|         .       |
|        . E    . |
|        ..  = . .|
|       .Soo= +  o|
|      o ==+o+ . =|
|    .  =*=.==o ++|
|     o.+.oOoo.=oo|
|      o. o.o +== |
+----[SHA256]-----+

Do you want to version the SSH data with Git? (Y/n): y
Initialized empty Git repository in /Users/manski/ssh-env/ssh-data/.git/
[master (root-commit) 763fa1d] SSH data repository created
 4 files changed, 68 insertions(+)
 create mode 100644 config
 create mode 100644 id_rsa
 create mode 100644 id_rsa.pub
 create mode 100644 known_hosts

Creating SSH data folder: success
```

**Note:** If you already have an SSH key pair, you can use it. See [Importing an Existing SSH Key Pair](#importing-an-existing-ssh-key-pair) below.

Now you're all set to interact with your first SSH server.


### Installing the public key on the target server
The next step is to install your *public* key on the server you want to connect to. (If you've imported a SSH key pair and the public key is already on the target server, you can skip this step.)

    $ ./ssh-env keys install user@targetserver

That's it. Now you should be able to ssh into the target server.


### Connecting to the target server
To connect to a server, simply enter the following:

    $ ./ssh-env targetserver        (same username as current computer)
    $ ./ssh-env user@targetserver   (explicit username)


## Where to go from here?
This is the minimum you *need* to know to use ssh-env. However, you should continue to read this readme to maximize the security of your ssh-env.

You may want to have a look at the `ssh-data/config` file.

It's also recommended to encrypt your ssh-env directory so that nobody can tamper with its contents.

And you may also want to explore all of ssh-env's commands:

    $ ./ssh-env --help


## File Layout
This section describes the file layout of ssh-env:

 * `ssh-data/` shared ssh files
   * `config` ssh config file ([man page](https://linux.die.net/man/5/ssh_config))
   * `id_rsa` (encrypted) private key of ssh key pair
   * `id_rsa.pub` public key of ssh key pair
   * `known_hosts` contains "ids" of known servers; created and modified by `ssh` itself
 * `.local/` local (i.e. per computer) ssh files; you don't need to backup these files and these files should not be shared with other computers
   * `ssh-agent.settings.json` ssh-agent configuration (i.e. whether to use it and for how long to store decrypted private keys); created via `ssh-env agent config` or when sshing the first time into a machine and this file doesn't exist
   * `ssh-agent-env.json` stores information about the running ssh-agent (must be kept private by all means); create when the ssh-agent is started
   * `ssh-env.settings.json`: local (not to be shared) configuration for ssh-env itself
   * `ssh.generated.conf`: Auto-generated SSH config file (based on `ssh-data/config`).
 * `ssh-env`: main bash script
 * `ssh-env.cmd`: main Windows batch file
 * `ssh-env.ps1`: main PowerShell file


## Securing ssh-env
There are a couple of thing that you can and should do to secure your ssh-env.


### Don't Trust Other Admins
The first rule of thumb is: **Don't trust computers where someone else is (also) admin.**

If you want to make sure no one else but you ever has access to your private key, use ssh-env only on computers where you are the *only* admin.

The next sections add additional layers of protection that make it harder - but certainly not 100% impossible - for a malicious user or admin to get their hands on your private key.

Of course, the level of trust in the admin depends on your environment. In a corporate environment admins are usually more trustworthy than admins of an internet cafe. But better safe than sorry.


### Revoke Access For Anyone But You
On Linux or macOS, just call this on the ssh-env **directory** (not just on the bash file):

    $ chmod 0700 <ssh-env-directory>

**Note:** This does not revoke access for `root` or someone who gets physical access to your computer/hard drive. However, encrypting ssh-env directory will take care of this (see next section).

On Windows, this process is much more complicated. I've tried this but gave up. It's easier to just encrypt the whole directory (see next section).


### Encrypt ssh-env
The easiest way to protect ssh-env against unauthorized reads and writes, is to encrypt the whole ssh-env directory.

**Note:** Unauthorized writes are even more problematic than unauthorized reads because an unauthorized user could tamper with ssh-env's files to - for example - redirect you to a *malicious* server without you noticing it.

On Windows, encrypting a folder is quite easy. Just right-click it, go to `Properties`, then `Advanced` and then select `Encrypt contents to secure data`.

Linux TDB


### Don't Use ssh-env in a VM or Container
Another rule of thumb: **Don't use ssh-env inside of a virtual machine or (Docker/Kubernetes/...) container** - if you're not the only admin on the host machine.

Windows doesn't have a `ssh` command. So it may be tempting to use a Docker container or a virtual machine as workaround.

However, both solutions (VMs and containers) have security problems - because they have security measures to prevent a malicious user from breaking *out* - but (usually) no measures to prevent a malicious user from breaking *in*. Any user on a host system can access (e.g. RDP, start/stop/save) any running virtual machine (as far as I know).

One could try to protect a VM by setting up proper passwords inside of the VM. But VMs are difficult to audit (since they run a whole operating system), and so while it may be possible to make using a VM secure, they're hardly easy to use.

Since Docker on Windows just runs inside of a VM, the same problem applies to Docker as well. With Docker, it's even easier to get inside the container - because there is no authorization required for `docker exec -ti /bin/sh`.


### Have a Dedicated Admin Machine
If you're really paranoid (security conscious), you may want to use a dedicated admin machine where you store you ssh-env.

This machine can be locked down and stripped of all unnecessary software to reduce the attack surface.

You would then remote into this machine (e.g. via RDP) and have preferably TFA set up to protect the account on this machine (for example via [Duo](https://duo.com/)).


## Synchronizing ssh-env Between Different Computers
On design goal of ssh-env is to be portable, i.e. it's possible to use the same files on different computers.

As far as synchronizing is concerned, an ssh-env directory is comprised of three parts:

1. `/` : the root directory represents the ssh-env "app"
1. `/ssh-data/` : the ssh data directory
1. `/.local/` : the local ssh-agent settings

The root directory is (usually) already under Git control - so you can use Git to put it on other computers.

If you used `./ssh-env datadir init` to create your data directory, ssh-env gave you the option to create a Git repository for the data directory. In this case, you use Git to synchronize your ssh data between computers. On another computer you can then use this command to get your ssh data:

    ./ssh-env datadir clone

*Note:* While ssh-env uses Git internally for `datadir init/clone`, you can use any other version control system you like (like Mercurial or even Subversion) to version your ssh data directory. ssh-env doesn't mind.

The third part (`./local/`) should not be synchronized. So there's nothing you need to do here.


### How to synchronize
To synchronize Git repositories between computers you have (at least) three options:
 * synchronize via network shares
 * use a self-hosted (on-premise) Git server
 * use a hosted Git server (like GitHub or Bitbucket)

Even though your private key is only stored *highly* encrypted, I strongly advise against using a publicly visible repository. For that reason, if you don't want to run a self-hosted Git server, I recommend using Bitbucket or GitHub because they give you free private repositories.

The most secure solution would be a self-hosted Git server. However, with this solution if you're using SSH+Git, you have to verify the host key of the Git server every time you do an *initial* checkout. This doesn't happen if you use HTTPS+Git instead (if you have a valid SSL certificate).

I haven't put much thought into synchronizing via network shares. I've never seen or used such a setup and spontaneously I'd expect this to be complicated to setup (especially the access rights).


## Why use ssh-env?
When comparing ssh-ing into a machine via plain ssh (`ssh targetserver`) and via ssh-env (`./ssh-env targetserver`), one might wonder what the benefit is of using ssh-env instead of plain ssh.

Here are some pointers:

* **You control where your ssh files are stored:** ssh-env stores all of its data files inside a directory inside of ssh-env (`ssh-data`). This especially allows you to have multiple ssh-envs on the same computer and also makes sharing the files between computers a little bit easier.
* **Easier to use on Windows:** There's usually no `ssh` available on Windows. Or you have some third-party product installed but need to open up a shell to get to `ssh`. On Windows, calling `ssh-env targetserver` greatly simplifies this process.
* **Easier tooling:** `ssh` itself is pretty easy to use; however, its tools are not. ssh-env makes it pretty easy to create, check and install SSH key pairs and to manage the ssh-agent - all under one command.


## Importing an Existing SSH Key Pair
If you already have an SSH key pair and are certain that you want to use it (i.e. you don't think it has been compromised), here's how to import it into ssh-env.

**Important:** Only checkin the *end* result of the following steps into Git (or the version control system of your choice). Do *not* check in results of any intermediary step.

 1. Copy your *private* key file into the `ssh-data` directory and name it `id_rsa`. Also copy your *public* key file into the `ssh-data` directory and name it `id_rsa.pub`. Make sure that you do *not* confuse these two files.
 1. Run `./ssh-env keys check`
 1. If this shows `Encryption: encrypted, strong`, you're all set. You can skip to step 6. If not, or if you want to change the encryption password for the private key, continue with the next step.
 1. Go into the `ssh-data` directory and execute `ssh-keygen -o -p -f id_rsa`
 1. Run `./ssh-env keys check` again and check that it prints out `Encryption: encrypted, strong`
 1. Check in both `id_rsa` and `id_rsa.pub`.

That's it.

## Install data dir globally
While ssh-env is self-contained, there may be SSH-based tools out there that won't work out-of-the-box with the data stored in an ssh-env.

For these tools, you can install the data dir of an ssh-env globally for your user.

Under the hood this means that ssh-env will take control of your `~/.ssh/config` file and fill it with some auto-generated content.

This way the above mentioned SSH-based tools get access to your SSH key (and all your other settings).

**Note:** Only *one* ssh-env can be globally installed per user at the same time.

To install your data dir globally, call:

```
./ssh-env datadir global-install
```

To make your private key available to SSH-based tools, you can either connect to a host or call:

```
./ssh-env keys load
```

**Tip:** This feature works great with [Visual Studio Code's Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension.

## Using Predefined Hosts
The ssh `config` file (in `ssh-data`) allows you to organize certain SSH host configurations under a name.

These configurations look like this:

    Host marvin
        HostName example.com
        Port 1234
        User johndoe
        HostKeyAlias marvin

    Host trillian
        HostName trillian.local
        ProxyCommand ssh marvin -F ssh/config -W %h:%p
        HostKeyAlias trillian

You can find a good introduction to host config in [this article](http://nerderati.com/2011/03/17/simplify-your-life-with-an-ssh-config-file/).


## Design Principles
There were several decisions to be made during the creation of this project. These decisions were made based on the following design principles.

* **Easy-to-use, maintainable, secure:** The project should fulfill all three of these but for individual features we may need to have to choose.
* **Cross Platform:** The project must work on Windows, Linux, and OS X.
* **Portable:** The environment must be portable - ideally everything you need should be in one folder.
* **Not Sharable Between Users:** The project is designed to be used by one person only. It's not designed to be shared across all admins of a company, for example.


### Design Decisions
Based on the **Easy-to-use, maintainable, secure** principle, here are the decisions that were made:

* **Private Key => Secure:** The SSH private key is encrypted with a password using bcrypt pbkdf, which makes it extremely compute intensive to brute-force the password. You can find out more about this [here](http://www.tedunangst.com/flak/post/new-openssh-key-format-and-bcrypt-pbkdf).
* **known_hosts => Maintainable:** Host names in the `known_hosts` file are not hashed (by default) to make this file better maintainable; i.e. host names are stored in plain-text. (This behavior is controlled by the `HashKnownHosts` setting in the SSH `config` file.) While hashing them would prevent attackers from harvesting host names in case of a security breach, there is usually a list of hosts in the SSH `config` file anyways; so, hashing the host names wouldn't bring any benefits at all.
* **No support for PuTTy => Secure:** I thought about support for PuTTy on Windows. However, PuTTy doesn't support OpenSSH's new, more secure private key format. So I decided against PuTTy support.
* **No support for changing passphrase of private key => Secure:** This was left out so that people would not think that this increases security. It does not because old versions of the private key may still be in the Git repository. If you think that your passphrase is not secure enough anymore, it's more secure to create a new certificate.
* **Separation of app and data dir => Maintainable/Secure/Easy-to-use:** There are (at least) three different variants on how to combine the ssh-env app with the ssh data dir:
  1. **Both in same repository and directory:** This is easiest to use (and was the initial design) but requires more knowledge about how merge the upstream ssh-env into your private repository. It's also less secure if you want to do pull request - as your ssh data dir might end up in the pull request if you're not super careful.
  1. **Both in the same directory but in different repositories (current design):** In my opinion the best compromise without the drawbacks of the other designs.
  1. **Both in different directories (and thus different repositories):** You would set up the ssh-env app in a central location and have your ssh data dir somewhere else. The downside of this design is that the user would need to secure two directories. And since most people probably only have one set of ssh data, there's no advantage of this design.


## Disclaimer
While I'm trying to make ssh-env as secure as possible, I'm not considering myself a security professional. I just understand the basic concepts.

So, use ssh-env at your own risk (and/or check out all the source code).

That being said, I'm using ssh-env productively (and therefor am trusting it).
