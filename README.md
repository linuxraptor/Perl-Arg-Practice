This repo is just to work on simple Perl concepts.

I hope to practice variable hardening, error handling and regular expressions.  Ideally these scripts will have as few dependencies as possible, with only perl core necessary.  Only Perl 5.6+ is required unless otherwise noted.  (Might someday include perlsec and perlipc for hardening purposes.)

scrape-ip-address.pl

I started this simple script while practicing BASH but found the regular expression handling to be atrocious.  New and improved, the PCRE standard allows me to make a much faster website scraper whose regex is more strict yet more flexible at the same time.  
