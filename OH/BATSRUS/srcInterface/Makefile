
SHELL =/bin/sh

include ../../../Makefile.def
include ../../../Makefile.conf
-include Makefile.DEPEND


OBJECTS = \
	ModGridDescriptor.o\
	OH_wrapper.o

SEARCHDIR = -I${SHAREDIR} -I${COUPLERDIR} -I${LIBRARYDIR} -I${MAGNETOGRAMDIR} \
	-I../src -I../srcBATL

DEPEND:
	@perl ${SCRIPTDIR}/depend.pl ${SEARCHDIR} ${OBJECTS}

#
#	Making executables and libraries
#
MY_LIB = ${LIBDIR}/libOH.a

LIB:	DEPEND
	$(MAKE) ${MY_LIB}
	@echo
	@echo ${MY_LIB} has been brought up to date.
	@echo

BATSRUS_LIB = ../src/libBATSRUS.a 

${MY_LIB}: ${BATSRUS_LIB} ${OBJECTS}
	cp -f ${BATSRUS_LIB} ${MY_LIB}
	${AR} ${MY_LIB} ${OBJECTS}

clean: cleanfiles

distclean: clean
	rm -f ModGridDescriptor.f90 \
	ModBuffer.f90 \
	update_lagrangian_grid.f90 \
	ModRadioWaveImage.f90 \
	ModRadioWaveRaytracing.f90 \
	ModDensityAndGradient.f90 \
	OH_get_for_mh_with_xyz.f90 \
	OH_wrapper.f90
