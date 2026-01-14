# Human Created Words

This was my very first seriopus exploration into ansible.  I did one off's and followed RHEL guys, but
the need to pay the bills kept me from seeing what it could really do.  Ansible was not my first venture
into declaritive languages.  I had a bit of puppet training and building a dynamnic orchestrated cloud environent
as a test when all that stuff was getting popular. I like ruby, but the continual changes early one were painful.

I like to keep my own email server. Many years have passed and many different technologies. They all work, until
they don't. When you claim a spot on the internet, you get poked and proded mercilessly.  Entropy will creep into
your system and it will be time to move on.  On average I move to another server every two years because something
anomolus happens and the spidey senses tingle.  Over the last few years I have been exprimenting with collecting logs
remotely.  The cool people do that.  Products like WAZUH have a distinct niche.  I am small...I don't need that, but with judicous use of fail2ban and tools for monitoring infrastructure.  The jackaltx.solti_monitoring collection provides metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki.

## Development Testing

There are some biggies I learned.  venv is cool.  Python is versbose.  
Currently this project used a prepared venv.  I am tempted to look at uv or mise.

This whole Podman for testing concept works, but molecule to run ansible is a bit clunky.

The good work is here. Experimenting how to use data scoping and dictionaries to
chain a set of verification tests that execise the application and execution environment,

## Podman vs Proxmox vs Linode

There are better ways to test just the ansible...I may use
to Jeff Gerrlings method next, but it is not worth it for this project.

VM testing is dogggg slow.

Github testing is a crap shoot. might be better now with Claude code.

## Claude handing git work

That is the cat's meow.  My log and process has never been so professional.

## Molecule

It works. This was an exercise of how to create resable code. It's clever.
And clever rarely is simple to explain...more later.
