#!/usr/bin/perl -i
use strict;
our @Arguments       = @ARGV;
our $MakefileDefOrig = "src/Makefile.def";
our $Component = "RB";
our $Code      = "RBE";

my $config = "share/Scripts/Config.pl";
# get util and share
my $GITCLONE = "git clone"; my $GITDIR = "herot:/GIT/FRAMEWORK/";
if (-f $config or -f "../../$config"){
}else{
    `$GITCLONE $GITDIR/share.git; $GITCLONE $GITDIR/util.git`;
}


if(-f $config){
    require $config;
}else{
    require "../../$config";
}
