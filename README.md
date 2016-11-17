# Redmine Grack integration plugin

This plugins integrates Grack (https://github.com/grackorg/grack) into Redmine
(https://www.redmine.org).

It allows access to your local git repositories over http under the /git
path. For example, if your application is located at https://myapp.org/, you
could access your repo by doing a

    git clone https://myapp.org/git/my-repo.git

It handles authentication using Redmine user and role management. When trying to
access a repository, the plugin builds the local its local path using the root
options. It then looks for a project with a local repository url matching the
local path. If a repository is not found, it sends a 404 HTTP error. If a
repository is found and its associated project is public, it allows access. If
the project is private, it tries to authenticate the user and see if the user as
any of the configured role for the project. If so, it allows access otherwise a
403 HTTP error is returned.


## Installation

To install, clone the repository in your redmine installion plugin directory,
copy the sample configuration [file](grack.yml.sample) to the redmine config
directory and edit it.

    git clone https://github.com/canatella/redmine_grack.git plugins/redmine_grack

## Configuration

This plugin adds two permission, push and pull to the repository module. Add
those permissions to the roles you wish to allow access to the repository. If
the project is public, pull is always allowed.
