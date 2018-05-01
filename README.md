# Portable SSH Environment #
Ssh-env provides a cross-platform, portable, easy-to-use, and yet secure environment for connecting to SSH servers (via the command line).

Portable in this case means that you can just copy the whole directory onto a different computer.

## Required Software ##
To use this project, you only need the following pieces of software:

* OpenSSH (along with its companion tools `ssh-keygen` and `ssh-agent`)
* Bash
* Git (optional)

On Linux and macOS, all packages are usually already installed.

On Windows, the easiest way to get SSH is to install [Git for Windows](https://git-for-windows.github.io/). You may also use alternatives like Cygwin if you like but this is untested.

## Getting started ##
First you need to clone or download this repository to your computer. It's recommended to clone the repository. This way you can more easily see what ssh-env actually does on your disk.

**Note:** ssh-env is completely self-contained and will not create or use any files outside of its directory. Thus, you can have as many copies of this repository on your computer as you like - without the copies interfering with each other.

On Linux and macOS, make sure that the file `/ssh-env` is executable:

    $ chmod u+x ./ssh-env

**Note:** There are some additional security measures (access rights and encryption; see below) that you should take at this step. However, we'll skip them for now to keep the first setup simple.

To check whether everything is setup correctly, issue the following command:

    $ ./ssh-env version  (Linux and macOS)
    $ ssh-env version    (Windows)

**Note:** ssh-env works the same on Windows, Linux and macOS. The only difference is that on Windows you use `ssh-env` instead of `./ssh-env`. The rest of this section will use the Linux style but it'll work the same way on Windows.

This should give you an output like this:

    ssh-env version 0.9.0
    OpenSSH_7.3p1, OpenSSL 1.0.2j  26 Sep 2016

**Note:** At this point I'm assuming that you have at least one server that you can ssh into. For testing purposes, you can use [Vagrant](https://www.vagrantup.com/) to quickly spin up a VM.

Now, that you're all set, let's first create a SSH key pair:

    $ ./ssh-env keys create

You'll be asked for the owner of the certificate (makes differentiating different public keys easier) and a password. **It's highly recommended that use a strong password here.**

This step creates an encrypted private key file (`ssh-data/id_rsa`) and a public key file (`ssh-data/id_rsa.pub`).

**Note:** If you already have an SSH key pair, you can use it. See [Importing an Existing SSH Key Pair](#markdown-header-importing-an-existing-ssh-key-pair) below.

Next, let's check the keys:

    $ ./ssh-env keys check

This should give you:

    Encryption: encrypted, strong

**Note:** If this gives anything else, then you didn't provide a password when creating the key pair or have imported a less secure key pair.

Next, configure ssh-agent. ssh-agent keeps your private key in memory so that you don't have to enter your private key encryption password every time you do an SSH connection.

    $ ./ssh-env agent config

During the configuration you can selected whether you want to use ssh-agent at all and for how long a decrypted private key should be held in memory.

Next, install the new public key on the target server. (If you've imported a SSH key pair and the public key is already on the target server, you can skip this step.) Note that you need some other SSH authentication method (usually a password) to do this. Use one of the following two methods:

    $ ./ssh-env keys install targetserver        (same username as current computer)
    $ ./ssh-env keys install user@targetserver   (explicit username)

That's it. Now you should be able to ssh into the target server:

    $ ./ssh-env targetserver        (same username as current computer)
    $ ./ssh-env user@targetserver   (explicit username)

## Where to go from here? ##
This is the minimum you *need* to know to use ssh-env. However, you should continue to read this readme to maximize the security of your ssh-env.

You may want to have a look at the `ssh-data/config` file.

It's also recommended to encrypt your ssh-env directory so that nobody can tamper with its contents.

And you may also want to explore all of ssh-env's commands:

    $ ./ssh-env --help

## File Layout ##
This section describes the file layout of ssh-env:

 * `helpers/` various helper files
 * `ssh-data/` shared ssh files
   * `config` ssh config file ([man page](https://linux.die.net/man/5/ssh_config))
   * `id_rsa` (encrypted) private key of ssh key pair
   * `id_rsa.pub` public key of ssh key pair
   * `known_hosts` contains "ids" of known servers; created and modified by `ssh` itself
 * `ssh-data-local/` local (i.e. per computer) ssh files
   * `agent.env` stores information about the running ssh-agent (must be kept private by all means); create when the ssh-agent is started
   * `ssh-agent.conf` ssh-agent configuration (i.e. whether to use and for how long to store decrypted private keys); created via `ssh-env agent config` or when sshing the first time into a machine and this file doesn't exist
 * `ssh-env` main bash script
 * `ssh-env.cmd` main Windows batch file (just calls `ssh-env`)

## Securing ssh-env ##
There are a couple of thing that you can and should do to secure your ssh-env.

### Don't Trust Other Admins ###
The first rule of thumb is: **Don't trust computers where someone else is (also) admin.**

If you want to make sure noone else but you ever has access to your private key, use ssh-env only on computers where you are the *only* admin.

The next sections add additional layers of protection that make it harder - but certainly not 100% impossible - for a malicious user or admin to get their hands on your private key.

Of course, the level of trust in the admin depends on your environment. In a corporate environment admins are usally more trustworthy than admins of an internet cafe. But better safe than sorry.

### Revoke Access For Anyone But You ###
On Linux or macOS, just call this on the ssh-env **directory** (not just on the bash file):

    $ chmod -R go-rwx ssh-env

**Note:** This does not revoke access for `root` or someone who gets physical access to your computer/hard drive. However, encrypting ssh-env directory will take care of this (see next section).

On Windows, this process is much more complicated. I've tried this but gave up. It's easier to just encrypt the whole directory (see next section).

### Encrypt ssh-env ###
The easiest way to protect ssh-env against unauthorized reads and writes, is to encrypt the whole ssh-env directory.

**Note:** Unauthorized writes are even more problematic than unauthorized reads because an unauthorized user could tamper with ssh-env's files to - for example - redirect you to a *malicious* server without you noticing it.

On Windows, encrypting a folder is quite easy. Just right-click it, go to `Properties`, then `Advanced` and then select `Encrypt contents to secure data`.

Linux TDB

### Don't Use ssh-env in a VM or Container ###
Another rule of thumb: **Don't use ssh-env inside of a virtual machine or (Docker/Kubernetes/...) container** - if you're not the only admin on the host.

Windows doesn't have a `ssh` command. So it may be tempting to use a Docker container or a virtual machine as workaround.

However, both solutions have security problems - because they have security measures to prevent a malicious user from breaking *out* - but (usually) no measures to prevent a malicious user from breaking *in*. Any user on a host system can access (e.g. RDP, start/stop/save) any running virtual machine (as far as I know).

One could try to protect a VM by setting up proper passwords inside of the VM. But VMs are difficult to audit (since they run a whole operating system), and so while it may be possible to make using a VM secure, they're hardly easy to use.

Since Docker on Windows just runs inside of a VM, the same problem applies to Docker as well. With Docker, it's even easier to get inside the container - because there is no authorization for `docker exec -ti /bin/sh`.

### Have a Dedicated Admin Machine ###
If you're really paranoid (security conscious), you may want to use a dedicated admin machine where you store you ssh-env.

This machine can be locked down and stripped of all unnecessary software to reduce the attack surface.

You would then remote into this machine (e.g. via RDP) and have preferably TFA set up to protect the account on this machine (for example via [Duo](https://duo.com/)).

## Synchronizing ssh-env Between Different Computers ##
On design goal of ssh-env is to be portable, i.e. it's possible to use the same files on different computers.

You could manually copy the files but it's far easier to use Git or Mercurial for this. Plus, you automatically get a history of all changes done to ssh-env.

Since you've already cloned this repository, I suggest you continue using Git to manage it. However, the following discussion applies to Mercurial as well.

### What to check in ##
First, a quick overview of what files should be checked in.

**Upstream:** Generally, all files that come from the upstream ssh-env repository should be kept checked in. These are the files in the root directory and the `helpers` directory.

**ssh-data:** All files in the `ssh-data` directory can/should be checked in. The private key must be encrypted with bcrypt (verify with `./ssh-env keys check`).

**ssh-data-local:** The directory `ssh-data-local` is supposed to be per computer and thus should not be checked in. (In the upstream repository this directory is already on the ignore list.)

### How to synchronize ###
To synchronize Git repositories between computers you have (at least) three options:
 * synchronize via network shares
 * use a self-hosted (on-premise) Git server
 * use a hosted Git server (like GitHub or Bitbucket)

Even though your private key is only stored *highly* encrypted, I strongly advise against using a publicly visible repository. For that reason, if you don't want to run a self-hosted Git server, I recommend using Bitbucket (instead of GitHub) because Bitbucket gives you free private repositories (whereas GitHub does not).

The most secure solution would be a self-hosted Git server. However, with this solution if you're using SSH+Git, you have to verify the host key of the Git server everytime you do an *initial* checkout. This doesn't happen if you use HTTPS+Git instead (if you have a valid SSL certificate).

I haven't put much thought into synchronizing via network shares. I've never seen or used such a setup and spontaneously I'd expect this to be complicated to setup (especially the access rights).

## Why use ssh-env? ##
When comparing sshing into a machine via plain ssh (`ssh targetserver`) and via ssh-env (`./ssh-env targetserver`), one might wonder what the benefit is of using ssh-env instead of plain ssh.

Here are some pointers:
 * **No files in home directory:** ssh-env stores all of its data files inside a directory inside of ssh-env (`ssh-data`). This especially allows you to have multiple ssh-envs on the same computer and also makes sharing the files between computers a little bit easier.
 * **Easier to use on Windows:** There's usually no `ssh` available on Windows. Or you have some third-party product installed but need to open up a shell to get to `ssh`. On Windows, calling `ssh-env targetserver` greatly simplifies this process.
 * **Easier tooling:** `ssh` itself is pretty easy to use; however, its tools are not. ssh-env makes it pretty easy to create, check and install SSH key pairs and to manage the ssh-agent.

## Importing an Existing SSH Key Pair ##
If you already have an SSH key pair and are certain that you want to use it (i.e. you don't think it has been compromised), here's how to import it into ssh-env.

**Important:** Only checkin the *end* result of the following steps. Do *not* check in results of any intermediary step.

 1. Copy your *private* key file into the `ssh-data` directory and name if `id_rsa`. Also copy your *public* key file into the `ssh-data` directory and name if `id_rsa.pub`. Make sure that you do *not* confuse these two files.
 1. Run `./ssh-env keys check`
 1. If this shows `Encryption: encrypted, strong`, you're all set. You can skip the next step. If not, or if you want to change the encryption password for the private key, continue with the next step.
 1. Go into the `ssh-data` directory and execute `ssh-keygen -o -p -f id_rsa` (On Windows, use `ssh-env shell` to get a shell where `ssh-keygen` is available.)
 1. Run `./ssh-env keys check` again and check that it prints out `Encryption: encrypted, strong`
 1. Check in both `id_rsa` and `id_rsa.pub`.

That's it.

## Using Predefined Hosts ##
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

## Design Principles ##
There were several decisions to be made during the creation of this project. These decisions were made based on the following design principles.

* **Easy-to-use, maintainable, secure:** The project should fulfill all three of these but for individual features we may need to have to choose.
* **Cross Platform:** The project must work on Windows, Linux, and OS X.
* **Portable:** The environment must be portable - ideally everything you need should be in one folder.
* **Not Sharable Between Users:** The project is designed to be used by one person only. It's not designed to be shared across all admins of a company, for example.

### Design Decisions ###
Based on the **Easy-to-use, maintainable, secure** principle, here are the decisions that were made:

* **Private Key => Secure:** The SSH private key is encrypted with a password using bcrypt pbkdf, which makes it extremely compute intensive to brute-force the password. You can find out more about this [here](http://www.tedunangst.com/flak/post/new-openssh-key-format-and-bcrypt-pbkdf).
* **known_hosts => Maintainable:** Host names in the `known_hosts` file are not hashed (by default) to make this file better maintainable; i.e. host names are stored in plain-text. (This behavior is controlled by the `HashKnownHosts` setting in the SSH `config` file.) While hashing them would prevent attackers from harvesting host names in case of a security breach, there is usually a list of hosts in the SSH `config` file anyways; so, hashing the host names wouldn't bring any benefits at all.
* **No support for PuTTy => Secure:** I thought about support for PuTTy on Windows. However, PuTTy doesn't support OpenSSH's new, more secure private key format. So I decided against PuTTy support.
* **No support for changing passphrase of private key => Secure:** This was left out so that people would not think that this increases security. It does not because old versions of the private key may still be in the Git repository. If you think that your passphrase is not secure enough anymore, it's more secure to create a new certificate.

## Disclaimer ##
While I'm trying to make ssh-env as secure as possible, I'm not considering myself a security professional. I just understand the basic concepts.

So, use ssh-env at your own risk.
