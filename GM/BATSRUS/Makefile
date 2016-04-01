#
# List the default target first for stand alone mode
#
DEFAULT_TARGET = BATSRUS
DEFAULT_EXE    = ${DEFAULT_TARGET}.exe

default : ${DEFAULT_TARGET}

include Makefile.def

#
# Menu of make options
#
help:
	@echo ' '
	@echo '  You can "make" the following:'
	@echo ' '
	@echo '    <default> ${DEFAULT_TARGET} in stand alone mode, help in SWMF'
	@echo ' '
	@echo '    help         (makefile option list)'
	@echo '    install      (install BATSRUS)'
	@#^CFG IF DOC BEGIN
	@#	^CFG IF NOT REMOVEDOCTEX BEGIN
	@echo ' '
	@echo '    PDF          (Make PDF version of the documentation)'
	@#		^CFG IF DOCHTML BEGIN
	@echo '    HTML         (Make HTML version of the documentation)'
	@#		^CFG END DOCHTML
	@#	^CFG END REMOVEDOCTEX
	@#^CFG END DOC
	@#^CFG IF TESTING BEGIN
	@echo '    test         (run all tests for BATSRUS)'
	@echo '    test_help    (show all options for running the tests)'
	@#^CFG END TESTING
	@echo ' '
	@echo '    LIB     (Component library libGM for SWMF)'
	@echo '    BATSRUS (Block Adaptive Tree Solar-Wind Roe Upwind Scheme)'
	@echo '    CRASH   (Code for Radiative Shock Hydrodynamics)'
	@echo '    NOMPI   (NOMPI library for compilation without MPI)'
	@echo '    PIDL    (PostIDL.exe creates 1 .out file from local .idl files)'
	@echo '    PSPH    (PostSPH.exe creates spherical tec file from sph*.tec files)'
	@echo '    SNAPSHOT    (SNAPSHOT.exe extract snapshots from *.outs movies)'
	@echo '    EARTH_TRAJ (EARTH_TRAJ.exe creates Earth trajectory file for heliosphere)'
	@echo '    TIME_CONV (TIME_CONV.exe converts the Carrington time to the usual one)'
	@echo ' '
	@echo '    rundir      (create run directory for standalone or SWMF)'
	@echo '    rundir RUNDIR=run_test (create run directory run_test)'
	@echo ' '
	@echo "    nompirun    (make and run ${DEFAULT_EXE} on 1 PE)"
	@echo "    mpirun      (make and mpirun ${DEFAULT_EXE} on 8 PEs)"
	@echo "    mpirun NP=7 RUNDIR=run_test (run on 7 PEs in run_test)"
	@echo "    mprun NP=5  (make and mprun ${DEFAULT_EXE} on 5 PEs)"
	@echo ' '	
	@echo '    clean     (remove temp files like: *~ *.o *.kmo *.mod *.T *.lst core)'
	@echo '    distclean (equivalent to ./Config.pl -uninstall)'
	@echo '    dist      (create source distribution tar file)'

INSTALLFILES =	src/Makefile.DEPEND \
		src/Makefile.RULES \
		srcBATL/Makefile.DEPEND \
		srcInterface/Makefile.DEPEND \
		srcPostProc/Makefile.RULES

install: src/ModSize.f90 src/ModHdf5.f90 src/ModImplHypre.f90 \
	srcBATL/BATL_size.f90
	touch ${INSTALLFILES}
	./Config.pl -u=Default -e=Mhd

src/ModSize.f90: src/ModSize_orig.f90
	cp -f src/ModSize_orig.f90 src/ModSize.f90

src/ModHdf5.f90: src/ModHdf5_empty.f90
	cp -f src/ModHdf5_empty.f90 src/ModHdf5.f90

src/ModImplHypre.f90: src/ModImplHypre_empty.f90
	 cp -f src/ModImplHypre_empty.f90 src/ModImplHypre.f90

srcBATL/BATL_size.f90: srcBATL/BATL_size_orig.f90
	cp -f srcBATL/BATL_size_orig.f90 srcBATL/BATL_size.f90

LIB:
	cd srcBATL; $(MAKE) LIB
	cd src; $(MAKE) LIB
	cd srcInterface; $(MAKE) LIB

BATSRUS:
	cd ${SHAREDIR}; $(MAKE) LIB
	cd ${TIMINGDIR}; $(MAKE) LIB
	cd ${MAGNETOGRAMDIR}; $(MAKE) LIB
	cd ${DEMTDIR}; $(MAKE) LIB
	cd ${EMPIRICALEEDIR}; $(MAKE) LIB
	cd srcBATL; $(MAKE) LIB
	cd src; $(MAKE) LIB
	cd src; make BATSRUS

CRASH:
	cd ${SHAREDIR}; $(MAKE) LIB
	cd ${TIMINGDIR}; $(MAKE) LIB
	cd ${MAGNETOGRAMDIR}; $(MAKE) LIB
	cd ${DEMTDIR}; $(MAKE) LIB
	cd ${EMPIRICALEEDIR}; $(MAKE) LIB
	cd ${CRASHDIR}; $(MAKE) LIB
	cd srcBATL; $(MAKE) LIB
	cd src; $(MAKE) LIB
	cd src; make CRASH

NOMPI:
	cd util/NOMPI/src; $(MAKE) LIB

PIDL:
	cd ${SHAREDIR}; $(MAKE) LIB
	cd srcPostProc; make PIDL
	@echo ' '
	@echo Program PostIDL has been brought up to date.
	@echo ' '

PSPH:
	cd srcPostProc; $(MAKE) PSPH
	@echo ' '
	@echo Program PostSPH has been brought up to date.
	@echo ' '

SNAPSHOT:
	cd ${SHAREDIR}; $(MAKE) LIB
	cd srcPostProc; make SNAPSHOT
	@echo ' '
	@echo Program SNAPSHOT has been brought up to date.
	@echo ' '

EARTH_TRAJ:
	cd srcPostProc; $(MAKE) EARTH_TRAJ
	@echo ' '
	@echo Program EARTH_TRAJ has been brought up to date.
	@echo ' '

TIME_CONV:
	cd srcPostProc; $(MAKE) TIME_CONV
	@echo ' '
	@echo Program TIME_CONV has been brought up to date.
	@echo ' '

# The MACHINE variable holds the machine name for which scripts should
# be copied from share/JobScripts to the run directory when it is created. 
# The default is the short name of the current machine with the trailing
# 1 or 2 numbers removed (so 'pfe23' and 'pfe20' are both converted to 'pfe')
MACHINE = `hostname | sed -e 's/\..*//;s/[0-9]\?[0-9]$$//'`

# Default component
COMPONENT = GM

rundir:
	mkdir -p ${RUNDIR}/${COMPONENT}
	cd ${RUNDIR}/${COMPONENT}; \
		mkdir restartIN restartOUT IO2; \
		ln -s ${BINDIR}/PostIDL.exe .; \
		ln -s ${BINDIR}/PostSPH.exe .; \
		cp    ${SCRIPTDIR}/pIDL .; \
		cp    ${GMDIR}/Scripts/TEC/pTEC .; \
		ln -s ${GMDIR}/Param .
	@(if [ "$(STANDALONE)" != "NO" ]; then \
		touch ${DIR}/share/JobScripts/job._TMP_${MACHINE}; \
		touch ${DIR}/share/JobScripts/_TMP_.${MACHINE}.pl; \
		cp ${DIR}/share/JobScripts/job.*${MACHINE}* ${RUNDIR}/; \
		cp ${DIR}/share/JobScripts/*.${MACHINE}.pl ${RUNDIR}/; \
		rm -f ${RUNDIR}/*_TMP_* ${DIR}/share/JobScripts/*_TMP_*; \
		cp -f Param/PARAM.DEFAULT ${RUNDIR}/PARAM.in; \
		touch ${RUNDIR}/core; chmod 444 ${RUNDIR}/core; \
		cp ${SCRIPTDIR}/PostProc.pl ${RUNDIR}/; \
		cp ${SCRIPTDIR}/Restart.pl ${RUNDIR}/; \
		cd ${RUNDIR}; ln -s ${BINDIR}/${DEFAULT_EXE} .; \
		ln -s ${COMPONENT}/* .;                          \
	fi);

rundir_rh:
	$(MAKE) rundir RUNDIR=run STANDALONE=YES GMDIR=`pwd`
	cd run; ln -s ${BINDIR}/CRASH.exe .; \
	cp -f Param/CRASH/PARAM.in .                          
#
#       Run the default code on NP processors
#

NP=2

mpirun: ${DEFAULT_TARGET}
	cd ${RUNDIR}; mpirun -np ${NP} ./${DEFAULT_EXE}

mprun: ${DEFAULT_TARGET}
	cd ${RUNDIR}; mprun -np ${NP} ./${DEFAULT_EXE}

nompirun: ${DEFAULT_TARGET}
	cd ${RUNDIR}; ./${DEFAULT_EXE}

#					^CFG IF DOC BEGIN
#	Create the documentation files      ^CFG IF NOT REMOVEDOCTEX BEGIN
#	
PDF:
	@cd Doc/Tex; $(MAKE) cleanpdf; $(MAKE) PDF

CLEAN1 = cleanpdf #				^CFG IF NOT MAKEPDF

#	Create HTML documentation		^CFG IF DOCHTML BEGIN
HTML:
	@cd Doc/Tex; $(MAKE) cleanhtml; $(MAKE) HTML

CLEAN2 = cleanhtml #				    ^CFG IF NOT MAKEHTML
#						^CFG END DOCHTML
#					    ^CFG END REMOVEDOCTEX
#					^CFG END DOC

#
# Cleaning
#

clean:
	@touch ${INSTALLFILES}
	cd src; $(MAKE) clean
	cd srcBATL; $(MAKE) clean
	cd srcInterface; $(MAKE) clean
	cd srcPostProc;  $(MAKE) clean
	@(if [ -d util  ]; then cd util;  $(MAKE) clean; fi);
	@(if [ -d share ]; then cd share; $(MAKE) clean; fi);

distclean: 
	./Config.pl -uninstall

allclean:
	@touch ${INSTALLFILES}
	cd src; $(MAKE) distclean
	cd srcBATL; $(MAKE) distclean
	cd srcInterface; $(MAKE) distclean
	cd srcPostProc;  $(MAKE) distclean
	cd srcTest; $(MAKE) distclean
	@				#^CFG IF DOC BEGIN
	@					#^CFG IF NOT REMOVEDOCTEX BEGIN
	cd Doc/Tex; $(MAKE) clean ${CLEAN1} ${CLEAN2}
	@					#^CFG END REMOVEDOCTEX
	@				#^CFG END DOC

dist:
	./Config.pl -uninstall
	@echo ' '
	@echo ' NOTE: All "run" or other created directories not included!'
	@echo ' '
	tar -cf tmp.tar  Makefile Makefile.test
	tar -rf tmp.tar  README Copyrights
	tar -rf tmp.tar  CVS* .cvsignore	#^CFG IF CONFIGURE
	tar -rf tmp.tar  Configure.options	#^CFG IF CONFIGURE
	tar -rf tmp.tar  Configure.pl		#^CFG IF CONFIGURE
	tar -rf tmp.tar  Test*.pl		#^CFG IF TESTING
	tar -rf tmp.tar  Doc			#^CFG IF DOC
	tar -rf tmp.tar  PARAM.XML
	tar -rf tmp.tar  Config.pl
	tar -rf tmp.tar  Idl
	tar -rf tmp.tar  Param
	tar -rf tmp.tar  Scripts
	tar -rf tmp.tar  src srcBATL srcUser srcEquation srcInterface
	tar -rf tmp.tar  srcPostProc srcTest 
	@(if [ -d util  ]; then tar -rf tmp.tar util; fi);
	@(if [ -d share ]; then tar -rf tmp.tar share; fi);
	@echo ' '
	gzip tmp.tar
	mv tmp.tar.gz BATSRUS_v${VERSION}_`date +%Y%b%d_%H%M.tgz`
	@echo ' '
	@ls -l BATSRUS_v*.tgz
include Makefile.test #^CFG IF TESTING
