A Markdown Viewer
=================

Application that opens `.md`
[markdown](http://daringfireball.net/projects/markdown/) files for
viewing. The uses file system events to figure out when the source
markdown file changes and refresh the viewer with the new markup. This
means I can use my favourite text editor (emacs) to edit my markdown
files at the same time as seeing the results.

Some issues:

1. Markdown is not part of the package, but is required to be installed under `/usr/local/bin/markdown`
2. Copy/paste is not implemented.
3. Possible to close window and not get it up again.
