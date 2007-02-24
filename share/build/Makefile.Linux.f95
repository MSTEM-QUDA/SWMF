#^CFG COPYRIGHT UM

SHELL=/bin/sh

#
#	Space Weather Modeling Framework (SWMF) 
#	NAG f95 Fortran 90/95 Compiler
#       Linux specific part of Makefile
#

COMPILE.f77     = ${CUSTOMPATH_F}f95
COMPILE.f90     = ${CUSTOMPATH_F}f95
LINK.f90	= ${CUSTOMPATH_MPI}mpif90
AR = ar -rs

SINGLEPREC =
DOUBLEPREC = -r8
PRECISION  = ${DOUBLEPREC}

MPILIB = 
#MPILIB = -L${LIBDIR} -lNOMPI

# This is the search path for used modules
# SEARCH_EXTRA should be set in the individual Makefiles

SEARCH = -I${SHAREDIR} ${SEARCH_EXTRA}

DEBUGFLAG = -C -gline
DEBUG     = 

OPT0 = -O0
OPT1 = -O1
OPT2 = -O2
OPT3 = -O3
OPT4 = -O4

CFLAG = ${SEARCH} -c -w -dusty ${DEBUG}

Cflag0  = ${CFLAG} ${PRECISION} ${OPT0}
Cflag1  = ${CFLAG} ${PRECISION} ${OPT1}
Cflag2  = ${CFLAG} ${PRECISION} ${OPT2}
Cflag3  = ${CFLAG} ${PRECISION} ${OPT3}
Cflag4  = ${CFLAG} ${PRECISION} ${OPT4}

# RCM compilation flags
# To allow RCM to compile as double precision, add PRECISION flag
CFLAGS = ${CFLAG} -save

# The '-Bstatic' flag avoids segmentation fault for large number of blocks
Lflag1  = ${PRECISION} ${MPILIB} ${DEBUG} -Bstatic
Lflag2  = ${PRECISION} ${DEBUG} -Bstatic

# BLAS and LAPACK libraries
LBLAS =
BLAS  = lapack.o blas.o


#
#       General rules
#

.SUFFIXES:
.SUFFIXES: .f90 .F90 .f .for .ftn .o

.f90.o:
	${COMPILE.f90} ${Cflag3} $<

.F90.o:
	${COMPILE.f90} -DsysLinux -DcompNAGF95 ${Cflag3} $<

.f.o:
	${COMPILE.f77} ${Cflag3} -132 $<

.for.o:
	${COMPILE.f77} ${Cflag3} -132 $<

.ftn.o:
	${COMPILE.f77} ${Cflag3} -132 $<

clean:	
	rm -f *~ core *.o *.mod fort.* *.out *.exe *.a *.so *.protex


# keep this line
