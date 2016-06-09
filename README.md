# repo-cycler

This is a single-purpose utility designed to change checked-out tags
in a target git repo. It provides a simple terminal UI to navigate
and cycle through tags, forward and backwards.

I wrote this is aid in live demos to be able to easily change between
pre-defined code states of an example application. This was originally
written for the YAPC::NA 2016 talk on RapidApp.

## Usage:

```bash
# clone this repo:
git clone https://github.com/vanstyn/repo-cycler
cd repo-cycler/

# install deps:
cpanm --installdeps .

# run on a repo:
./cycler.pl /path/to/git/repo
```
