#!/usr/bin/perl -s

my $Help    = $h or $help;
my $Extract = $e;
my $Verbose = $v;
my $nProcAll= ($n or 8);
my $lSession= ($s or 60);
my $ProcShow= ($p or "roots");

use strict;

my $ERROR        ="ERROR in Performance.pl:";
my $ValidComp    ="SC|IH|SP|GM|IM|RB|IE|UA";
my $LayoutFile   ="run/LAYOUT.in";
my $ParamFile    ="run/PARAM.in";
my $TimingFile   ="run/TIMING.in";
my $CompinfoFile ="run/COMPINFO.in";

&print_help if $Help;
&extract_timing if $Extract;

die "$ERROR number of total processors is $nProcAll\n" 
    unless $nProcAll > 0;

my @RegisteredComp; # list of registered components in LAYOUT.in
my %Layout_C;       # layout information (Proc0, ProcLast, ProcStride, PEs)
my %nProc_C;        # number of PE-s assigned to the components
&read_layout;

my %TimeStep_C;     # Physical time step for the components
my %MinProc_C;      # Minimum number of PE-s allowed for the components
my %MaxProc_C;      # Maximum number of PE-s allowed for the components
&read_compinfo;

my %CpuStep_C;      # Total CPU time / time step for the components
&read_timing;

my %WallStep_C;     # Wall clock time / time step (on nProc_C PE-s)
&set_wallstep;

# These variables are set by read_param in each session

my $TimeAccurate=1; # True for time accurate session (initially true)
my %DnRun_C;        # Frequency of calling components in non-time accurate run 
my %Couple_CC;      # Coupling info for component pairs (dt, dn, tnext ...)
my %CoupleOnTime_C; # Logical array for letting components pass coupling time

my @ActiveComp = @RegisteredComp; # List of components active in a session
my @CoupleOrder = ("SC IH",       # Order of pairwise couplings
		   "IH SC",
		   "SC SP",
		   "IH SP",
		   "IH GM",
		   "GM IE",
		   "GM IM",
		   "GM RB",
		   "UA IE",
		   "IE IM",
		   "IM GM",
		   "IE UA",
		   "IE GM");

# These variables are set during the session execution

my $iSession;      # session number
my %Time_C;        # physical time of the components
my @WallTime_P;    # walltime for the processors
my @WallHist_P;    # history of wall time costs for the processors
my @CompList_P;    # list of local components for each processor
my $NewIeData;     # true if IE component receives information (from GM or UA)

 SESSION:
{
     $iSession++;

     print " === Starting session $iSession === \n" if $Verbose;
     my $IsLastSession = &read_param;

     &init_session;
     &do_session;
     &show_timing;
     print " === Finished session $iSession === \n" if $Verbose;
     redo SESSION unless $IsLastSession;
}

exit 0;

##############################################################################
sub print_help{
    print "
Purpose:
 
   Extract performance information, estimate run time, optimize layout

Usage: 

   Scripts/Performance.pl [-h] [-v] [-e FILE(s)] [-n=nProc] [-p=PROCS]

   -h          print help message and exit
   -v          print verbose information
   -e FILE(s)  extract timings from runlog FILE(s) and exit
   -n=nProc    emulate runs on nProc processors
   -p=PROCS    show history for the processors indicated by the PROCS string
               Possible values are 'none', 'roots', 'all', and a list of
               processor ranks separated by commas (e.g. 0,2,3). 
               Default value is 'roots', the root PE for all components.
";
    exit;
}
##############################################################################
sub extract_timing{

    my $Comp;
    my $File;
    my %Info;

    while($File=shift(@ARGV)){
	my %nProc_C;
	my %CpuStep_C;
	open(FILE,$File) or die "$ERROR could not open runlog file $File\n";
	while(<FILE>){
	    if(/^\# ($ValidComp).*version \d\.\d\d +(\d+) +\d+ +\d+ +\#$/){
		$nProc_C{$1} = $2;
	    }
	    if(/^($ValidComp)_run +(\d+\.\d\d) +\d+\.\d\d +(\d+) +\d+$/){
		$CpuStep_C{$1} = ($2/$3);
	    }
	}
	close(FILE);
	foreach $Comp (keys %nProc_C){
	    next unless $CpuStep_C{$Comp};
	    $Info{$Comp}{$File} = 
		sprintf("%2s%8d%10.2f\n", 
			$Comp, $nProc_C{$Comp}, $nProc_C{$Comp}*$CpuStep_C{$Comp});
	}
    }
    printf "%2s%8s%10s\n", "ID","nProc","CPU[s]";
    print  "-"x20,"\n";
    foreach $Comp (keys %Info){
	foreach $File (keys %{ $Info{$Comp} }){
	    print $Info{$Comp}{$File};
	}
    }

    exit 0;
}
##############################################################################
sub read_layout{

    open(FILE,$LayoutFile) or 
	die "$ERROR could not open layout file $LayoutFile\n";
    my $start;
    while(<FILE>){
	if(/^\#COMPONENTMAP/){$start=1; next}
	next unless $start; # Skip lines before #COMPONENTMAP
	last if /^\#END/;   # Ignore lines after #END

	# extract layout information from one line in the component map
        /^($ValidComp)\s+(\d+)\s+(\d+)\s+(\d+)/ or
            die "$ERROR incorrect syntax at line $. in $LayoutFile:\n$_";

	my $Comp       = $1;
	my $Proc0      = $2;
	my $ProcLast   = $3;
	my $ProcStride = $4;

        die "$ERROR root PE rank=$Proc0 should not exceed ".
	    "last PE rank=$ProcLast\n".
            "\tat line $. in $LayoutFile:\n$_"
            if $Proc0 > $ProcLast;

        die "$ERROR stride=$ProcStride must be positive ".
	    "at line $. in $LayoutFile:\n$_"
            if $ProcStride < 1;

	# Reduce component ranks if necessary
	$Proc0    = $nProcAll-1 unless $Proc0    < $nProcAll;
	$ProcLast = $nProcAll-1 unless $ProcLast < $nProcAll;

	$Layout_C{$Comp}{Proc0}      = $Proc0;
	$Layout_C{$Comp}{ProcLast}   = $ProcLast;
	$Layout_C{$Comp}{ProcStride} = $ProcStride;

	my $iProc;
	for($iProc = $Proc0; $iProc <= $ProcLast; $iProc += $ProcStride){
	    push(@{$Layout_C{$Comp}{ProcArray}}, $iProc);
	}
	$nProc_C{$Comp} = int(($ProcLast - $Proc0)/$ProcStride) + 1;

	die "nProc_C{$Comp}=$nProc_C{$Comp} differs from ProcArray size=".
	    scalar @{$Layout_C{$Comp}{ProcArray}}."\n"
	    if $nProc_C{$Comp} != scalar @{$Layout_C{$Comp}{ProcArray}};

    }
    close(FILE);

    # Store list of components
    @RegisteredComp = sort keys %nProc_C;

    if($Verbose){
	my $Comp;
	print "ID   nProc   Proc0 ProcLast ProcStride\n".
	    "--------------------------------------\n";
	foreach $Comp (@RegisteredComp){
	    printf "%s%8d%8d%8d%8d\n",$Comp,$nProc_C{$Comp},
	    $Layout_C{$Comp}{Proc0},
	    $Layout_C{$Comp}{ProcLast},
	    $Layout_C{$Comp}{ProcStride};
	}
	print "\n";
    }
}
##############################################################################
sub read_param{

    if($iSession == 1){
	open(PARAMFILE,$ParamFile) or 
	    die "$ERROR could not open parameter file $ParamFile\n";
    }

    my $IsLastSession = 1;
  LINE:
    while(<PARAMFILE>){

	next LINE unless /^\#/;

	if(/^\#RUN\b/){
	    $IsLastSession = 0;
	    last LINE;
	}

	if(/^\#END\b/){
	    last LINE;
	}

	if(/^\#TIMEACCURATE\b/){
	    $TimeAccurate = read_var("logical", "TimeAccurate");
	}

	if(/^\#COMPONENT\b/){
	    my $Comp   = read_var("id", "NameComp");
	    my $UseComp = read_var("logical", "UseComp");
	    my $UsedComp = grep /$Comp/, @ActiveComp;
	    if($UseComp and not $UsedComp){push @ActiveComp, $Comp};
	    if($UsedComp and not $UseComp){
		# Remove $Comp from @ActiveComp
		my $i;
		$i++ while $ActiveComp[$i] ne $Comp;
		splice @ActiveComp, $i, 1;
	    }
	    print "ActiveComp: @ActiveComp\n" if $Verbose;
	}

	if(/^\#COUPLEORDER\b/){
	    my $nCouple = read_var("integer", "nCouple");
	    my $iCouple;
	    @CoupleOrder = ();
	    for $iCouple (0..$nCouple-1){
		$CoupleOrder[$iCouple] = read_var("id id", "NameSourceTarget");
	    }
	    print "CoupleOrder: ",join(',',@CoupleOrder),"\n" if $Verbose;
	}

	if(/^\#COUPLE([12])(SHIFT)?/){

	    my $nWay = $1;
	    my $Shift= $2;

	    my $Comp1    = read_var("id",     "NameComp1");
	    my $Comp2    = read_var("id",     "NameComp2");
	    my $DnCouple = read_var("integer","DnCouple");
	    my $DtCouple = read_var("real",   "DtCouple");

	    my $DoCouple = ($DnCouple >=0 or $DtCouple >= 0);

	    $Couple_CC{$Comp1}{$Comp2}{do}    = $DoCouple;
	    $Couple_CC{$Comp1}{$Comp2}{dn}    = $DnCouple;
	    $Couple_CC{$Comp1}{$Comp2}{dt}    = $DtCouple;
	    $Couple_CC{$Comp1}{$Comp2}{tNext} = $DtCouple;
	    $Couple_CC{$Comp1}{$Comp2}{nNext} = $DnCouple;
	    if($nWay == 2){
		$Couple_CC{$Comp2}{$Comp1}{do}    = $DoCouple;
		$Couple_CC{$Comp2}{$Comp1}{dn}    = $DnCouple;
		$Couple_CC{$Comp2}{$Comp1}{dt}    = $DtCouple;
		$Couple_CC{$Comp2}{$Comp1}{nNext} = $DnCouple;
		$Couple_CC{$Comp2}{$Comp1}{tNext} = $DtCouple;
	    }
	    if($Shift){
		$Couple_CC{$Comp1}{$Comp2}{nNext} = 
		    read_var("integer","nNext12");
		$Couple_CC{$Comp1}{$Comp2}{tNext} = 
		    read_var("real",   "tNext12");
		if($nWay == 2){
		    $Couple_CC{$Comp2}{$Comp1}{nNext} = 
			read_var("integer","nNext21");
		    $Couple_CC{$Comp2}{$Comp1}{tNext} = 
			read_var("real",   "tNext21");
		}
	    }

	    # Store first coupling time and step for multisession
	    $Couple_CC{$Comp1}{$Comp2}{nFirst} = 
		$Couple_CC{$Comp1}{$Comp2}{nNext};
	    $Couple_CC{$Comp1}{$Comp2}{tFirst} = 
		$Couple_CC{$Comp1}{$Comp2}{tNext};
	    if($nWay == 2){
		$Couple_CC{$Comp2}{$Comp1}{nFirst} = 
		    $Couple_CC{$Comp2}{$Comp1}{nNext};
		$Couple_CC{$Comp2}{$Comp1}{tFirst} = 
		    $Couple_CC{$Comp2}{$Comp1}{tNext};
	    }

	}

	if(/^\#COUPLETIME\b/){
	    my $Comp = &read_var("id", "NameComp");
	    $CoupleOnTime_C{$Comp} = &read_var("logical","DoCoupleOnTime");
	}

	if(/^\#CYCLE\b/){
	    my $Comp = &read_var("id", "NameComp");
	    $DnRun_C{$Comp} = &read_var("integer","DnRun");
	}

    }

    close(PARAMFILE) if $IsLastSession;



    if($Verbose){
	print "\n";
	print "IsLastSession = $IsLastSession\n";
	print "TimeAccurate  = $TimeAccurate\n";
	print "Coupling schedule\n\n";
	print "Source => Target: DtCouple [s]\n".
	    "------------------------------\n";
	my $Comp1;
	foreach $Comp1 (sort keys %Couple_CC){
	    my $Comp2;
	    foreach $Comp2 (sort keys %{ $Couple_CC{$Comp1} }){
		next unless $Couple_CC{$Comp1}{$Comp2}{do};
		print "    $Comp1 => $Comp2    : ",
		$Couple_CC{$Comp1}{$Comp2}{dt},"\n";
	    }
	}
	print "\n";
    }

    return $IsLastSession;
}
#############################################################################
sub read_var{
    my $TypeVar = shift;
    my $NameVar = shift;

    # read variable
    my $Variable = <PARAMFILE>; chop $Variable;

    # get rid of comments and leading/trailing spaces
    $Variable =~ s/ *\t.*//;
    $Variable =~ s/   .*//;
    $Variable =~ s/^\s+//;
    $Variable =~ s/\s+$//;

    die "$ERROR invalid $TypeVar $NameVar=$Variable".
	" at line $. in $ParamFile\n" 
	if
	$TypeVar eq "id"      and $Variable !~ /^($ValidComp)$/ or
	$TypeVar eq "id id"   and $Variable !~ /^($ValidComp) ($ValidComp)$/ or
	$TypeVar eq "integer" and $Variable !~ /^[\+\-]?\d+$/ or
	$TypeVar eq "real"    and $Variable !~ /^[edED\+\-\.\d]+$/ or
	$TypeVar eq "logical" and $Variable !~ /^(t|f|\.true\.|\.false\.)$/i;

    if($TypeVar eq "logical"){
	if($Variable =~ /t/i){
	    $Variable = 1;
	}else{
	    $Variable = 0;
	}
    }

    if($Verbose){
	print "Read from $ParamFile $TypeVar variable $NameVar=$Variable\n";
    }

    return $Variable;
}
##############################################################################
sub read_timing{

    open(FILE,$TimingFile) or 
	die "$ERROR could not open timing file $TimingFile\n";

    my $start;

    while(<FILE>){

	if(/^--------------------/){$start = 1; next};
	next unless $start;
    
	if(/^($ValidComp)\s+(\d+)\s+(\d+\.\d+)$/){
	    $CpuStep_C{$1}{$2}=$3;
	}else{
	    die "$ERROR could not read from timing file $TimingFile line $_";
	}
    }
    close(FILE);

    die "$ERROR could not obtain timings from timing file $TimingFile\n"
	unless %CpuStep_C;

    my $Comp;
    foreach $Comp (@RegisteredComp){
	die "$ERROR no timing info in file $TimingFile for component $Comp\n"
	    unless $CpuStep_C{$Comp};
    }

    if($Verbose){
	print "ID on nProc PE-s uses   CpuTime sec total CPU time\n".
	    "--------------------------------------------------\n";
	foreach $Comp (@RegisteredComp){
	    my $nProc;
	    foreach $nProc (sort {$a<=>$b} keys %{ $CpuStep_C{$Comp} }){
		printf "%s%4d%s%10.2f%s\n", "$Comp on ",$nProc," PE-s uses ",
		    $CpuStep_C{$Comp}{$nProc}," sec total CPU time";
	    }
	}
	print "\n";
    }
}
##############################################################################
sub read_compinfo{

    open(FILE,$CompinfoFile) or 
	die "$ERROR could not open compinfo file $CompinfoFile\n";

    my $start;

    while(<FILE>){

	if(/^--------------------/){$start = 1; next};
	next unless $start;
    
	if(/^($ValidComp)\s+([\+\-\d\.]+)\s+(\d+)\s+(\d+)\s*$/){
	    $TimeStep_C{$1} = $2;
	    $MinProc_C{$1}  = $3;
	    $MaxProc_C{$1}  = $4;
	}else{
	    die "$ERROR could not read line from compinfo file $CompinfoFile:".
		$_;
	}
    }
    close(FILE);

    die "$ERROR could not obtain info from compinfo file $CompinfoFile\n"
	unless %TimeStep_C;

    my $Comp;
    foreach $Comp (@RegisteredComp){
	die "$ERROR no info in file $CompinfoFile for component $Comp\n"
	    unless $TimeStep_C{$Comp};
    }

    if($Verbose){
	print "ID      Dt      MinProc MaxProc\n".
	    "-------------------------------\n";

	foreach $Comp (sort keys %TimeStep_C){
	    printf "%s%10.2f%8d%8d\n", "$Comp",$TimeStep_C{$Comp},
	    $MinProc_C{$Comp},$MaxProc_C{$Comp};
	}
	print "\n";
    }
}
##############################################################################
sub set_wallstep{

    if($Verbose){
	print "ID   nProc    CPU[s] walltime[s] / time step\n".
	      "--------------------------------------------\n";
    }
    my $Comp;
    for $Comp (@RegisteredComp){

	my %Cpu    = %{ $CpuStep_C{$Comp} };    # timings for this component
	my @nProc  = sort {$a<=>$b} keys %Cpu;  # processor numbers in timings
	my $nProc0 = $nProc[0];                 # smallest number of timed PE-s
	my $Cpu0   = $Cpu{$nProc0};
	my $nProc1 = $nProc[$#nProc];           # largest  number of timed PE-s
	my $Cpu1   = $Cpu{$nProc1};

	my $nProc = $nProc_C{$Comp}; # number of PE-s used in this run

	# Calculate walltime
	my $WallTime;
	if($nProc0 == $nProc1){
	    # Take average
	    $WallTime = 0.5*($Cpu0 + $Cpu1);
	}else{
	    # Interpolate or extrapolate linearly
	    $WallTime = 
		(($nProc - $nProc0)*$Cpu1 + ($nProc1 - $nProc)*$Cpu0)
		/($nProc1 - $nProc0);
	}
	# Divide by number of PE-s
	$WallStep_C{$Comp} = $WallTime / $nProc;

	if($Verbose){
	    printf "%s%8d%10.2f%10.2f\n", $Comp, $nProc, 
	    $WallStep_C{$Comp}*$nProc, $WallStep_C{$Comp};
	}
    }
    if($Verbose){print "\n";}

}
##############################################################################
sub init_session{

    # Set the list of components running on a PE
    my $iProc;
    my $Comp;
    @CompList_P = ();
    for $Comp (@ActiveComp){
	for $iProc (@{ $Layout_C{$Comp}{ProcArray} }){ 
	    $CompList_P[$iProc] .= "$Comp,";
	}
    }
    for $iProc (0..$nProcAll-1){chop $CompList_P[$iProc]};

    # Set the array of PE-s for all the active couplings
    # Reset the next coupling time and step
    my $Comp1;
    foreach $Comp1 (@ActiveComp){
	my $Comp2;
	foreach $Comp2 (@ActiveComp){
	    next unless $Couple_CC{$Comp1}{$Comp2}{do};
	    my @Proc = (@{ $Layout_C{$Comp1}{ProcArray} }, 
			@{ $Layout_C{$Comp2}{ProcArray} } );

	    # Create a unique list
	    my %Proc; for $iProc (@Proc){ $Proc{$iProc}=1 }
	    @Proc = keys %Proc;

	    # Store the list
	    $Couple_CC{$Comp1}{$Comp2}{ProcArray} = \@Proc;

	    # Reset the next coupling time and step
	    $Couple_CC{$Comp1}{$Comp2}{tNext} = 
		$Couple_CC{$Comp1}{$Comp2}{tFirst};
	    $Couple_CC{$Comp1}{$Comp2}{nNext} = 
		$Couple_CC{$Comp1}{$Comp2}{nFirst};
	}
    }

    # Initialize physical time, wall time and histories
    %Time_C     = ();
    @WallTime_P = ();
    @WallHist_P = ();

    if($Verbose){
	print "iProc: component list\n";
	print "------------------------------\n";
	for $iProc (0..$nProcAll-1){
	    printf "%5d: %s\n", $iProc, $CompList_P[$iProc];
	}
	print "\n";
    }
}
###############################################################################
sub do_session{

    # Do the session

    my $TimeMax=$lSession; # Final time is the length of the session

    my %tNext_C;           # Next time a component should stop at

    my $iProc;
  TIMELOOP:
    {

	# figure out next wait time for all active components
	# this time is the same on all processors
	my $Comp;
	for $Comp (@ActiveComp){
	    my $tNext = $TimeMax;
	    my $Comp2;
	    for $Comp2 (@ActiveComp){
		if($Couple_CC{$Comp}{$Comp2}{do}){
		    my $tNextCouple = $Couple_CC{$Comp}{$Comp2}{tNext};
		    $tNext = $tNextCouple if $tNextCouple < $tNext;
		}
		if($Couple_CC{$Comp2}{$Comp}{do}){
		    my $tNextCouple = $Couple_CC{$Comp2}{$Comp}{tNext};
		    $tNext = $tNextCouple if $tNextCouple < $tNext;
		}
	    }
	    $tNext_C{$Comp} = $tNext;

	    print "tNext_C{$Comp} = $tNext\n" if $Verbose;
	}

	# Run all the active components
	my $Comp;
	for $Comp (@ActiveComp){

	    # run component if it has not reached the next waiting time
	    if($Time_C{$Comp} < $tNext_C{$Comp}){

		my $WallStep;	# cost of the step
		if($Comp eq "IE"){

		    # IE component always advances to next time
		    $Time_C{$Comp} = $tNext_C{$Comp};

		    # IE component does work only if there is new data
		    $WallStep = $WallStep_C{IE} if $NewIeData;
		    $NewIeData = 0;
		}else{
		    # Increase component time
		    $Time_C{$Comp} += $TimeStep_C{$Comp};

		    # Limit component time
		    if($CoupleOnTime_C{$Comp} eq "0"){
			# Limit by TimeMax only
			$Time_C{$Comp} = $TimeMax if 
			    $Time_C{$Comp} > $TimeMax;
		    }else{
			# Limit by next coupling time
			$Time_C{$Comp} = $tNext_C{$Comp} if 
			    $Time_C{$Comp} > $tNext_C{$Comp};
		    }

		    # Doing a step with $Comp will cost some wall time
		    $WallStep = $WallStep_C{$Comp};
		}

		my @Proc = @{ $Layout_C{$Comp}{ProcArray} };
		&add_wall_time("$Comp idle","$Comp runs",$WallStep,@Proc);

	    }
	}

	# Couple components
	my $Time = &minval(@Time_C{@ActiveComp});

	last TIMELOOP if $Time >= $TimeMax;

	my $CouplePair;
	foreach $CouplePair (@CoupleOrder){
	    my $Comp1 = substr($CouplePair,0,2);
	    my $Comp2 = substr($CouplePair,-2,2);

	    next unless grep /$Comp1/, @ActiveComp;
	    next unless grep /$Comp2/, @ActiveComp;
	    next unless $Couple_CC{$Comp1}{$Comp2}{do};

	    my %Couple = %{ $Couple_CC{$Comp1}{$Comp2} };
	    my $tCouple = $Couple{tNext};

	    if($Time >= $tCouple){
		print "Coupling $Comp1 => $Comp2 at t=$tCouple\n" if $Verbose;

		# Set next coupling time
		$Couple_CC{$Comp1}{$Comp2}{tNext} += $Couple{dt};

		# Estimate cost of coupling
		my $WallCouple = 0;

		# Set NewIeData if IE receives data
		$NewIeData = 1 if $Comp2 eq "IE";

		# If IE is sending info, it may need to do a potential solve
		if($Comp1 eq "IE" and $NewIeData){
		    $WallCouple += $WallStep_C{IE};
		    $NewIeData  = 0;
		}

		# List of processors involved in the coupling

		# Add wall time due to synchronizetion and coupling

		my @Proc = @{ $Couple_CC{$Comp1}{$Comp2}{ProcArray} };
		&add_wall_time("$Comp1===$Comp2","$Comp1-->$Comp2",
			       $WallCouple,@Proc);

	    }
	}
	redo TIMELOOP;
    }
    &add_wall_time("ENDidle","ENDsess",0,(0..$nProcAll-1));

}
##############################################################################
sub add_wall_time{

    # Add wall time to WallTime_P due to synchronization of a group of PE-s.
    # Add wall time to WallTime_P due to execution of some task.
    # Save wall time info into the WallHist_P array.

    my $NameSync = shift; # Name for synchronization in history
    my $NameExec = shift; # Name of task to be executed in history
    my $WallExec = shift; # Wall time of task to be executed
    my @Proc     = @_;    # List of processors involved

    # Synchronize wall time of PE-s in @Proc
    # Find the maximum wall time of the PE-s involved
    my $WallTimeMax = &maxval(@WallTime_P[@Proc]);
    my $iProc;
    for $iProc (@Proc){
	# Processors with wall time less than WallTimeMax must idle
	my $Idle = $WallTimeMax - $WallTime_P[$iProc];
	if($Idle){
	    $WallTime_P[$iProc] = $WallTimeMax;
	    &add_wall_hist($iProc,$NameSync,$Idle);
	}
    }

    # Execute task: increase wall clock time of PE-s in @Proc
    if($WallExec){
	for $iProc (@Proc){
	    $WallTime_P[$iProc] += $WallExec;
	    &add_wall_hist($iProc,$NameExec,$WallExec);
	}
    }
}
##############################################################################
sub add_wall_hist{
    my $iProc=shift;
    my $Name =shift;
    my $Step =shift;

    if($WallHist_P[$iProc][-1] eq $Name){
	# If the last name is the same as $Name, increase the wall step value
	$WallHist_P[$iProc][-2] += $Step;
    }else{
	# If new name, add new elements to the name and time history
	push( @{$WallHist_P[$iProc]} , ($Step, $Name) );
    }
}
##############################################################################
sub show_timing{


    printf "%8.2f seconds wall time for session $iSession\n", $WallTime_P[0];
    return if $ProcShow eq 'none';

    my @Proc;
    if( $ProcShow eq 'all' ){
	@Proc = (0..$nProcAll-1);
    }elsif( $ProcShow eq 'roots' ){
	# Collect root PE-s
	my %ProcShow;
	my $Comp;
	for $Comp (@ActiveComp){
	    $ProcShow{$Layout_C{$Comp}{Proc0}} = 1;
	}
	@Proc = sort {$a<=>$b} keys %ProcShow;
    }elsif( $ProcShow =~ /^[\d,]+$/ ){
	@Proc = split(/,/, $ProcShow);
    }else{
	die "$ERROR: Invalid format for -p=$ProcShow\n";
    }

    my $SepLine = "-" x (15*@Proc) . "\n";
    print $SepLine;
    my $iProc;
    for $iProc (@Proc){printf "     PE%4d    ", $iProc}; print "\n";
    print $SepLine;

    my $iLine;
    for ($iLine=0; 1; $iLine+=2){
	my $Continue;
	for $iProc (@Proc){
	    my $Step = $WallHist_P[$iProc][$iLine];
	    my $Name = $WallHist_P[$iProc][$iLine+1];
	    if($Name){
		printf "%6.1f(%s)", $Step, $Name;
		$Continue = 1;
	    }else{
		print " " x 15;
	    }
	}
	print "\n";
	last unless $Continue;
    }

}
##############################################################################
sub minval{
    my $minval = @_[0];
    foreach (@_){$minval = $_ if $_ < $minval};
    return $minval;
}
##############################################################################
sub maxval{

    my $maxval = @_[0];
    foreach (@_){$maxval = $_ if $_ > $maxval};
    return $maxval;
}
