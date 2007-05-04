
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     ALEX(10/11/04): I THINK THAT THIS SUBROUTINE INITIALIZES THE GRID AND
C     AND SETS CONSTANTS. IT MUST BE INITIALIZED EVERY TIME THE CODE RUNS
C     EVEN IF RESTARTING FROM A FILE.
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

      SUBROUTINE STRT
C
C

      use ModCommonVariables

C
      NPT1=14
      NPT2=16
      NPT3=30
      NPT4=35
      NPT5=60
      NPT6=70
1     FORMAT(5X,I5)
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE GAS SPECIFIC HEAT AT CONSTANT PRESSURE (CP),          C
C           THE AVERAGE MOLECULAR MASS (AVMASS), THE ACTUAL            C
C           GAS CONSTANT (RGAS) AND THE SPECIFIC HEAT RATIO (GAMMA)    C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C Gas constant = k_Boltzmann/AMU
      RGAS=8.314E7
C Adiabatic index
      GAMMA=5./3.
C AMU in gramms
      XAMU=1.6606655E-24
C Mass of atomic O in gramms
      XMSO=15.994*XAMU
C Mass of atomic H in gramms
      XMSH=1.00797*XAMU
C Mass of atomic He in gramms
      XMSHE=4.0026*XAMU
C Mass of electron in gramms
      XMSE=9.109534E-28
C Relative mass of atomic O to electron
      RTOXEL=XMSE/XMSO
C Relative mass of atomic H to electron
      RTHDEL=XMSE/XMSH
C Relative mass of atomic He to electron
      RTHEEL=XMSE/XMSHE
C kB/m_O
      RGASO=RGAS*XAMU/XMSO
C kB/m_H
      RGASH=RGAS*XAMU/XMSH
C kB/m_He
      RGASHE=RGAS*XAMU/XMSHE
C kB/m_e
      RGASE=RGAS*XAMU/XMSE
      GMIN1=GAMMA-1.
      GMIN2=GMIN1/2.
      GPL1=GAMMA+1.
      GPL2=GPL1/2.
      GM12=GMIN1/GAMMA/2.
      GRAR=GAMMA/GMIN2
      GREC=1./GAMMA
      CPO=GAMMA*RGASO/GMIN1
      CPH=GAMMA*RGASH/GMIN1
      CPHE=GAMMA*RGASHE/GMIN1
      CPE=GAMMA*RGASE/GMIN1
      CVO=RGASO/GMIN1
      CVH=RGASH/GMIN1
      CVHE=RGASHE/GMIN1
      CVE=RGASE/GMIN1
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE RADIAL GRID STRUCTURE                                 C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) DRBND
CALEX DRBND=altitude step? I think the units here are in cm not meters
CALEX like most of the code.
      DRBND=2.E6

CALEX RN=lower boundary of the simulation? 
CALEX RAD=radial distance of cell centers?      
CALEX RBOUND=radial distance of lower boundary of cell     
CALEX ALTD = same as RAD but distance is from surface, not center of planet
      RN=6.55677E8+0.5*DRBND
      DO 20 KSTEP=1,NDIM1
         RBOUND(KSTEP)=RN+(KSTEP-1)*DRBND
20    CONTINUE
      DO 30 KSTEP=1,NDIM
         KSTEP1=KSTEP+1
         RAD(KSTEP)=(RBOUND(KSTEP)+RBOUND(KSTEP1))/2.
         ALTD(KSTEP)=RAD(KSTEP)-6356.77E5
 30   CONTINUE
      ALTMIN=ALTD(1)-DRBND
      ALTMAX=ALTD(NDIM)+DRBND
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ THE EXPONENT OF THE  A(R)=R**NEXP  AREA FUNCTION            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,1) NEXP
      NEXP=3

CAlex      write(*,*) NEXP

CALEX AR stands for area function. 12 is the lower boundary of the cell
CALEX and 23 is the upper boundary

      DO 40 K=1,NDIM
      DAREA(K)=NEXP/RAD(K)
      AR12(K)=(RBOUND(K)/RAD(K))**NEXP
      AR23(K)=(RBOUND(K+1)/RAD(K))**NEXP

!     For the cell volume in the Rusanov Solver we use a cell volume 
!     calculated by assuming an area function in the form A=alpha r^3
!     and then assuming each cell is a truncated cone.
!     So CellVolume_C is the volume of cell j divided by the crossesction
!     of cell j, A(j). 

      CellVolume_C(K)=1.0/3.0 * DrBnd *
     &     ( Ar12(K) + Ar23(K) + ( Ar12(K)*Ar23(K) )**0.5 ) 

40    CONTINUE
! area and volume for ghost cell
      AR12top(1)=((RN+nDim*drbnd)/(RN+nDim*drbnd+drbnd*0.5))**NEXP
      AR23top(1)=((RN+(nDim+1.0)*drbnd)/(RN+(nDim+1.0)*drbnd+drbnd*0.5))**NEXP
      CellVolumeTop(1)=1.0/3.0 * DrBnd *
     &     ( Ar12top(1) + Ar23top(1) + ( Ar12top(1)*Ar23top(1) )**0.5 ) 


      AR12top(2)=((RN+(nDim+1.0)*drbnd)/(RN+(nDim+1.0)*drbnd+drbnd*0.5))**NEXP
      AR23top(2)=((RN+(nDim+2.0)*drbnd)/(RN+(nDim+2.0)*drbnd+drbnd*0.5))**NEXP
      CellVolumeTop(2)=1.0/3.0 * DrBnd *
     &     ( Ar12top(2) + Ar23top(2) + ( Ar12top(2)*Ar23top(2) )**0.5 ) 

C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ FIELD ALIGNED CURRENT DENSITY AT LOWEST GRID POINT          C
C        (UNIT=mAMPERE/M**2)                                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) CURR(1)
C      CURR(1)=0.E-6

      CURR(1)=2.998E2*CURR(1)
!      CURTIM=150.
!      CURTIM0=500.
      CURRMN=CURR(1)*(RAD(1)/(RAD(1)-DRBND))**NEXP
      CURRMX=CURR(1)*(RAD(1)/(RAD(NDIM)+DRBND))**NEXP
      
      do k=2,nDim
         CURR(k)=CURR(1)*(RAD(1)/(RAD(k)))**NEXP
      enddo


C      SGN1=1.
C      IF (CURR(1).LT.0.) SGN1=-1.
C      IF (ABS(CURR(1)).LT.1.E-4) SGN1=0.
C      CURRMX=SGN1*0.2998*(RAD(1)/(RAD(NDIM)+DRBND))**NEXP
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE NEUTRAL ATMOSPHERE MODEL                              C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C IF GEOMAGNETIC COORDINATES ARE SPECIFIED, SET IART TO 1 !!!!!
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE DATE                                                      C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C SOLAR MAXIMUM WINTER
C      IYD=80360
C      F107A=180.
C      F107=180.
C SOLAR MAXIMUM SUMMER
C      IYD=80172
C      F107A=180.
C      F107=180.
C SOLAR MINIMUM WINTER
C      IYD=84360
C      F107A=60.
C      F107=60.
C SOLAR MINIMUM SUMMER
c      IYD=84172
c      F107A=60.
c      F107=60.
c      SEC=43200.
c      STL=12.
c      GMLAT=80.
c      GMLONG=0.
c      IART=1
c      GLAT=0.
c      GLONG=180.
c      IART=0
C FEB 20, 1990
CALEX IYD=year_day of year

      IYD=76183
      STL=12.
      F107A=60.
      F107=60.
      IART=1
!      GMLONG=0.
!      GMLAT=80.
C END
      CALL GGM(IART,GLONG,GLAT,GMLONG,GMLAT)
      SEC=mod((STL-GLONG/15.)*3600.,24.*3600.)
      
      DO 49 I=1,7
c      AP(I)=50.
         AP(I)=4.  
49    CONTINUE 
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC 
C                                                                      C
      DO 50 K=1,NDIM
         CALL MODATM(ALTD(K),XO2(K),XN2(K),XO(K),XH(K),XHE(K),XTN(K))
50    CONTINUE


      
      CALL GLOWEX
      DO 1099 J = 1,40

 9999    FORMAT(2X,1PE15.3,2X,1PE15.3)
 1099 CONTINUE
C
      CALL STRT1
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE TOPSIDE ELECTRON HEAT FLUX AND PARAMETRIC HEAT SOURCES    C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,2) ETOP,ELFXIN
c      ETOP=5.0E-3
      ETOP=10.0E-3

      ELFXIN=0.
C
C      ELFXIN=9.
C
2     FORMAT(6X,1PE15.4)

C      READ (5,2) HEATI1,HEATI2,ELHEAT
      HEATI1=0.
      HEATI2=0.
C
C      HEATI1=1.0E-7
C
      HEATI2=5.E-6
C
      ELHEAT=0.

      HEATA1=3.5E7
      HEATA2=1.30E7
      HEATA3=1.5E8
      HEATS1=2.*1.0E7**2
      HEATS2=2.0E6
      HEATS3=2.*1.0E7**2
      DO 53 K=1,NDIM
      HEATX1=EXP(-(ALTD(K)-HEATA1)**2/HEATS1)
      HEATX2=EXP(-(ALTD(K)-HEATA2)/HEATS2-EXP(-(ALTD(K)-HEATA2)/HEATS2))
      HEATX3=EXP(-(ALTD(K)-HEATA3)**2/HEATS3)

c      QOXYG(K)=(HEATI1*HEATX1+HEATI2*HEATX2)/
c     #         (DOXYG(K)+DHYD(K)+DHEL(K))
c      QHYD(K)=QOXYG(K)/16.
c      QHEL(K)=QOXYG(K)/4.

      QOXYG(K)=0.
      QHYD(K)=QOXYG(K)/16.
      QHEL(K)=QOXYG(K)/4.


C
C      QOXYG(K)=0.
C
      QELECT(K)=ELHEAT*HEATX3


53    CONTINUE
!      DO 54 K=1,NDIM,10
!      WRITE (iUnitOutput,52) ALTD(K),QOXYG(K),QHYD(K),QHEL(K),QELECT(K)
52    FORMAT(5(1PE15.4))
!54    CONTINUE
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     READ STARTING TIME, TERMINATION TIME AND BASIC TIME STEP         C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ (5,4) TIME,TMAX
CCC      TIME=0.
CCC      TMAX=1.E6

            

4     FORMAT(6X,2(1PE15.4))
!!!!      READ (iUnitInput,*) Dt
C      DT=1./10.
      DTX1=DT
      DTR1=DTX1/DRBND
      DTX2=DT*NTS
      DTR2=DTX2/DRBND

      H0=0.5/DRBND
      H1E1=1./DTX1
      H1O1=1./DTX1
      H1H1=1./DTX1
      H1E2=1./DTX2
      H1O2=1./DTX2
      H1H2=1./DTX2
      H2=1./DRBND/DRBND
      H3=0.5*H2
      H4=0.5*H0
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     DEFINE THE HEAT CONDUCTION PARAMETERS                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
CALEX terms with "surf" in them refer to surface values      
      HLPE0=GMIN1/RGASE
      HLPE=1.23E-6*GMIN1/RGASE
      HLPO=1.24E-8*(XMSE/XMSO)*GMIN1/RGASO
      HLPHE=2.5*(RGASHE**2*XMSHE)*GMIN1/RGASHE
      HLPH=4.96E-8*(XMSE/XMSH)*GMIN1/RGASH
      CALL MODATM(ALTMIN,XNO2,XNN2,XNO,XNH,XNHE,TEMP)
CALEX I believe these are heat conduction coef. at lower boundary
      CXHN2=3.36E-9*XNN2
      CXHO2=3.20E-9*XNO2
      CXHO=6.61E-11*XNO*SQRT(TSURFH)*(1.-0.047*ALOG10(TSURFH))**2
      CXHOX=1.23*(DSURFO/XMSO)/TSURFH**1.5
      CXHEN2=1.60E-9*XNN2
      CXHEO2=1.53E-9*XNO2
      CXHEHE=8.73E-11*XNHE*SQRT(TSURHE)*(1.-0.093*ALOG10(TSURHE))**2
      CXHEO=1.01E-9*XNO
      CXHEH=4.71E-10*XNH
      CXHEOX=0.57*(DSURFO/XMSO)/TSURHE**1.5
      CXHEHD=0.28*(DSURFH/XMSH)/TSURHE**1.5
CALEX I believe these are heat conductivities      
      TCSFO=HLPO*(DSURFO/DSURFE)*TSURFO**2.5
      TCSFE=HLPE*TSURFE**2.5
      TCSFH=HLPH*(DSURFH/DSURFE)*TSURFH**2.5
      TCSFH=TCSFH/(1.+(0.7692*(CXHN2+CXHO2)+1.0962*CXHO)/CXHOX)
      TCSFHE=HLPHE*(DSURHE/XMSHE)*TSURHE
      TCSFHE=TCSFHE/(0.99*CXHEN2+0.99*CXHEO2+1.02*CXHEO+1.48*CXHEHE+
     $2.22*CXHEH+1.21*CXHEOX+2.23*CXHEHD)      
      CALL MODATM(ALTMAX,XNO2,XNN2,XNO,XNH,XNHE,TEMP)
      XTNMAX=TEMP
CALEX I believe these are heat conduction coef. at upper boundary
      CZHN2=3.36E-9*XNN2
      CZHO2=3.20E-9*XNO2
      CZHO=6.61E-11*XNO
      CZHOX=1.23*17.**1.5/XMSO
      CZHEN2=1.60E-9*XNN2
      CZHEO2=1.53E-9*XNO2
      CZHEHE=8.73E-11*XNHE
      CZHEO=1.01E-9*XNO
      CZHEH=4.71E-10*XNH
      CZHEOX=0.57*5.**1.5/XMSO
      CZHEHD=0.28*5.**1.5/XMSH
      ETOP=ETOP*DRBND/1.23E-6
      CALL PW_set_upper_bc
3     FORMAT(4X,I6)
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C     PRINT INITIAL AND BOUNDARY PARAMETERS                            C
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
C      READ(5,3) NCNPRT

      
      NCNPRT=0

      CALL MODATM(ALTMIN,XNO2,XNN2,XNO,XNH,XNHE,XNT)
      CALL MODATM(ALTMAX,YNO2,YNN2,YNO,YNH,YNHE,YNT)
      DO 60 I=1,NDIM
      ALTD(I)=ALTD(I)/1.E5
60    CONTINUE
      ALTMIN=ALTMIN/1.E5
      ALTMAX=ALTMAX/1.E5
      ETOP1=ETOP*1.23E-6/DRBND
      CALL COLLIS(NDIM)

      CALL ELFLDW

      !write log
      if (DoLog) then
      IF (NCNPRT.NE.0) GO TO 999
      WRITE(iUnitOutput,1005) NDIM
1005  FORMAT(1H1,5X,'NUMBER OF CELLS=',I4)
      WRITE(iUnitOutput,1020) NEXP
1020  FORMAT(5X,'NEXP=',I1)
      WRITE (iUnitOutput,1008) GAMMA,RGASO,CPO,CVO,RGASHE,CPHE,CVHE,
     ;RGASH,CPH,CVH,RGASE,CPE,CVE
1008  FORMAT(5X,'GAMMA=',F4.2,/5X,'RGAS(OXYGEN)=',1PE10.4,7X,
     ;'CP(OXYGEN)=',1PE10.4,7X,'CV(OXYGEN)=',1PE10.4
     ;/5X,'RGAS(HELIUM)=',1PE10.4,7X,
     ;'CP(HELIUM)=',1PE10.4,7X,'CV(HELIUM)=',1PE10.4/5X,
     ;'RGAS(HYDROGEN)=',1PE10.4,5X,'CP(HYDROGEN)=',1PE10.4,5X,
     ;'CV(HYDROGEN)=',1PE10.4,/5X,'RGAS(ELECTRON)=',1PE10.4,5X
     ;,'CP(ELECTRON)=',1PE10.4,5X,'CV(ELECTRON)=',1PE10.4)
      WRITE (iUnitOutput,1023)
1023  FORMAT(1H0,5X,'LOWER BOUNDARY PLASMA PARAMETERS:')
      WRITE(iUnitOutput,1001)
1001  FORMAT(1H ,4X,'OXYGEN:')
      WRITE (iUnitOutput,1009) USURFO,PSURFO,DSURFO,TSURFO,WSURFO
1009  FORMAT(5X,'VELOCITY=',1PE11.4,3X,'PRESSURE=',1PE10.4,3X,
     ;'MASS DENSITY=',1PE10.4,3X,'TEMPERATURE=',1PE10.4,3X,
     ;'SOUND VELOCITY=',1PE10.4)
      WRITE(iUnitOutput,10021)
10021 FORMAT(1H ,4X,'HELIUM:')
      WRITE (iUnitOutput,1009) USURHE,PSURHE,DSURHE,TSURHE,WSURHE
      WRITE(iUnitOutput,1002)
1002  FORMAT(1H ,4X,'HYDROGEN:')
      WRITE (iUnitOutput,1009) USURFH,PSURFH,DSURFH,TSURFH,WSURFH
      WRITE(iUnitOutput,1003)
1003  FORMAT(1H ,4X,'ELECTRONS:')
      WRITE (iUnitOutput,1009) USURFE,PSURFE,DSURFE,TSURFE,WSURFE
      WRITE (iUnitOutput,1027)
1027  FORMAT(1H0,5X,'UPPER BOUNDARY INITIAL PLASMA PARAMETERS:')
      WRITE (iUnitOutput,1004)
1004  FORMAT(1H ,4X,'OXYGEN:')
      WRITE (iUnitOutput,1009) UBGNDO,PBGNDO,DBGNDO,TBGNDO,WBGNDO
      WRITE (iUnitOutput,1088)
1088  FORMAT(1H ,4X,'HELIUM:')
      WRITE (iUnitOutput,1009) UBGNHE,PBGNHE,DBGNHE,TBGNHE,WBGNHE
      WRITE (iUnitOutput,1006)
1006  FORMAT(1H ,4X,'HYDROGEN:')
      WRITE (iUnitOutput,1009) UBGNDH,PBGNDH,DBGNDH,TBGNDH,WBGNDH
      WRITE(iUnitOutput,1007)
1007  FORMAT(1H ,4X,'ELECTRONS:')
      WRITE (iUnitOutput,1009) UBGNDE,PBGNDE,DBGNDE,TBGNDE,WBGNDE
      WRITE (iUnitOutput,1029) ETOP1
1029  FORMAT(1H0,5X,'TOPSIDE ELECTRON HEATING RATE:',1PE10.4,
     ;' ERGS/CM**3/SEC')
      WRITE (iUnitOutput,1050) 
1050  FORMAT(1H0,5X,'ENERGY COLLISION TERM COEFFICIENTS')
      WRITE (iUnitOutput,1051) CTOXN2,CTOXO2,CTOXO,CTOXHE,CTOXH,CTOXHD,CTOXHL,
     $CTOXEL,CTHEN2,CTHEO2,CTHEO,CTHEHE,CTHEH,CTHEOX,CTHEHD,CTHEEL,
     $CTHN2,CTHO2,CTHO,CTHHE,CTHH,CTHOX,CTHHL,CTHEL,CTELN2,CTELO2,
     $CTELO,CTELHE,CTELH,CTELOX,CTELHL,CTELHD
1051  FORMAT(1H0,5X,'CTOXN2=',1PE10.4,5X,'CTOXO2=',1PE10.4,4X,
     $'CTOXO=',1PE10.4/5X,'CTOXHE=',1PE10.4,5X,'CTOXH=',1PE10.4,5X,
     $'CTOXHD=',1PE10.4,5X,'CTOXHL=',1PE10.4,5X,'CTOXEL=',1PE10.4/
     $5X,'CTHEN2=',1PE10.4,5X,'CTHEO2=',1PE10.4,4X,
     $'CTHEO=',1PE10.4/5X,'CTHEHE=',1PE10.4,5X,'CTHEH=',1PE10.4,5X,
     $'CTHEOX=',1PE10.4,5X,'CTHEHD=',1PE10.4,5X,'CTHEEL=',1PE10.4/
     $5X,'CTHN2=',1PE10.4,6X,'CTHO2=',1PE10.4,5X,'CTHO=',1PE10.4/5X,
     $'CTHHE=',1PE10.4,6X,'CTHH=',1PE10.4,6X,'CTHOX=',1PE10.4,6X,
     $'CTHHL=',1PE10.4,6X,'CTHEL=',1PE10.4/5X,
     $'CTELN2=',1PE10.4,5X,'CTELO2=',1PE10.4,4X,
     $'CTELO=',1PE10.4/5X,'CTELHE=',1PE10.4,5X,'CTELH=',1PE10.4,5X,
     $'CTELOX=',1PE10.4,5X,'CTELHL=',1PE10.4,5X,'CTELHD=',1PE10.4,5X)
      WRITE (iUnitOutput,1052) CMOXN2,CMOXO2,CMOXO,CMOXHE,CMOXH,CMOXHD,CMOXHL,
     $CMOXEL,CMHEN2,CMHEO2,CMHEO,CMHEHE,CMHEH,CMHEOX,CMHEHD,CMHEEL,
     $CMHN2,CMHO2,CMHO,CMHHE,CMHH,CMHOX,CMHHL,CMHEL,CMELN2,CMELO2,
     $CMELO,CMELHE,CMELH,CMELOX,CMELHL,CMELHD
1052  FORMAT(1H0,5X,'CMOXN2=',1PE10.4,5X,'CMOXO2=',1PE10.4,4X,
     $'CMOXO=',1PE10.4/5X,'CMOXHE=',1PE10.4,5X,'CMOXH=',1PE10.4,5X,
     $'CMOXHD=',1PE10.4,5X,'CMOXHL=',1PE10.4,5X,'CMOXEL=',1PE10.4/
     $5X,'CMHEN2=',1PE10.4,5X,'CMHEO2=',1PE10.4,4X,
     $'CMHEO=',1PE10.4/5X,'CMHEHE=',1PE10.4,5X,'CMHEH=',1PE10.4,5X,
     $'CMHEOX=',1PE10.4,5X,'CMHEHD=',1PE10.4,5X,'CMHEEL=',1PE10.4/
     $5X,'CMHN2=',1PE10.4,6X,'CMHO2=',1PE10.4,5X,'CMHO=',1PE10.4/5X,
     $'CMHHE=',1PE10.4,6X,'CMHH=',1PE10.4,6X,'CMHOX=',1PE10.4,6X,
     $'CMHHL=',1PE10.4,6X,'CMHEL=',1PE10.4/5X,
     $'CMELN2=',1PE10.4,5X,'CMELO2=',1PE10.4,4X,
     $'CMELO=',1PE10.4/5X,'CMELHE=',1PE10.4,5X,'CMELH=',1PE10.4,5X,
     $'CMELOX=',1PE10.4,5X,'CMELHL=',1PE10.4,5X,'CMELHD=',1PE10.4,5X)
      WRITE (iUnitOutput,1053)
1053  FORMAT(1H0,5X,'HEAT CONDUCTION COEFFICIENTS AT UPPER BOUNDARY')
      WRITE (iUnitOutput,1054) CZHN2,CZHO2,CZHO,CZHOX,CZHEN2,CZHEO2,CZHEHE,
     $CZHEO,CZHEH,CZHEOX,CZHEHD,XTNMAX
1054  FORMAT(1H0,5X,'CZHN2=',1PE10.4,6X,'CZHO2=',1PE10.4,6X,
     $'CZHO=',1PE10.4,7X,'CZHOX=',1PE10.4/5X,'CZHEN2=',1PE10.4,5X,
     $'CZHEO2=',1PE10.4,5X,'CZHEHE=',1PE10.4,5X,'CZHEO=',1PE10.4/
     $5X,'CZHEH=',1PE10.4,6X,'CZHEOX=',1PE10.4,5X,'CZHEHD=',
     $1PE10.4/5X,'XTNMAX=',1PE10.4)
      WRITE (iUnitOutput,1012)
1012  FORMAT(1H1,45X,'NEUTRAL ATMOSPHERE NUMBER DENSITIES')
      WRITE(iUnitOutput,1014)
1014  FORMAT(16X,'ALT',13X,'N2',13X,'O2',15X,'O',14X,'HE',
     $15X,'H',15X,'T')
      K=0
      WRITE (iUnitOutput,1022) K, ALTMIN,XNN2,XNO2,XNO,XNHE,XNH,XNT
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 230 K=1,NDMQ
         WRITE(iUnitOutput,1022) K,ALTD(K),XN2(K),XO2(K),XO(K),XHE(K),
     $        XH(K),XTN(K)
 230  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 290
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 240 K=NPT2,NDMQ,2
         WRITE(iUnitOutput,1022) K,ALTD(K),XN2(K),XO2(K),XO(K),XHE(K),
     $        XH(K),XTN(K)
 240  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 290
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 250 K=NPT4,NDMQ,5
         WRITE(iUnitOutput,1022) K,ALTD(K),XN2(K),XO2(K),XO(K),XHE(K),
     $        XH(K),XTN(K)
 250  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 290
      DO 260 K=NPT6,NDIM,10
         WRITE(iUnitOutput,1022) K,ALTD(K),XN2(K),XO2(K),XO(K),XHE(K),
     $        XH(K),XTN(K)
 260  CONTINUE
 290  CONTINUE
      K=NDIM+1
      WRITE (iUnitOutput,1022) K, ALTMAX,YNN2,YNO2,YNO,YNHE,YNH,YNT
      WRITE(iUnitOutput,1015)
1015  FORMAT(1H1,55X,'SOURCE COEFFICIENTS:')
      WRITE (iUnitOutput,1016)
1016  FORMAT(12X,'ALT',6X,'GRAVTY',5X,'FFOX1',5X,'FFOX2',5X,
     ;'FFOX3',5X,'FFOX4',5X,'FFOX5',5X,'FFOX6',4X,'FFHYD1',
     ;4X,'FFHYD2',4X,'FFHE1',5X,'FFHE2')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 291 K=1,NDMQ
      WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFOX1(K),FFOX2(K),
     $FFOX3(K),FFOX4(K),FFOX5(K),FFOX6(K),FFHYD1(K),FFHYD2(K),
     $FFHE1(K),FFHE2(K)
291   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 295
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 292 K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFOX1(K),FFOX2(K),
     $FFOX3(K),FFOX4(K),FFOX5(K),FFOX6(K),FFHYD1(K),FFHYD2(K),
     $FFHE1(K),FFHE2(K)
292   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 295
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 293 K=NPT4,NDMQ,5
      WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFOX1(K),FFOX2(K),
     $FFOX3(K),FFOX4(K),FFOX5(K),FFOX6(K),FFHYD1(K),FFHYD2(K),
     $FFHE1(K),FFHE2(K)
293   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 295
      DO 294 K=NPT6,NDIM,10
      WRITE(iUnitOutput,1019) K,ALTD(K),GRAVTY(K),FFOX1(K),FFOX2(K),
     $FFOX3(K),FFOX4(K),FFOX5(K),FFOX6(K),FFHYD1(K),FFHYD2(K),
     $FFHE1(K),FFHE2(K)
294   CONTINUE
295   CONTINUE
      WRITE(iUnitOutput,1017)
1017  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR OXYGEN')
      WRITE(iUnitOutput,1018)
1018  FORMAT(12X,'ALT',7X,'CLOXN2',6X,'CLOXO2',6X,'CLOXO',7X,
     ;'CLOXHE',6X,'CLOXH',7X,'CLOXHL',6X,'CLOXHD',6X,'CLOXEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 530 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
530   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 590
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 540 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
540   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 590
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 550 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
550   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 590
      DO 560 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),CLOXN2(K),CLOXO2(K),CLOXO(K),
     $CLOXHE(K),CLOXH(K),CLOXHL(K),CLOXHD(K),CLOXEL(K)
560   CONTINUE
590   CONTINUE
      WRITE (iUnitOutput,1217)
1217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR HELIUM')
      WRITE(iUnitOutput,1218)
1218  FORMAT(12X,'ALT',7X,'CLHEN2',6X,'CLHEO2',6X,'CLHEO',7X,
     ;'CLHEHE',6X,'CLHEH',7X,'CLHEOX',6X,'CLHEHD',6X,'CLHEEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 1230 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
1230  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 1290
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 1240 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
1240  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 1290
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 1250 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
1250  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 1290
      DO 1260 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHEN2(K),CLHEO2(K),CLHEO(K),
     $CLHEHE(K),CLHEH(K),CLHEOX(K),CLHEHD(K),CLHEEL(K)
1260  CONTINUE
1290  CONTINUE
      WRITE (iUnitOutput,2217)
2217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR HYDROGEN')
      WRITE(iUnitOutput,2218)
2218  FORMAT(12X,'ALT',7X,'CLHN2',7X,'CLHO2',7X,'CLHO',8X,
     ;'CLHHE',7X,'CLHH',8X,'CLHOX',7X,'CLHHL',7X,'CLHEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 2230 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHN2(K),CLHO2(K),CLHO(K),
     $CLHHE(K),CLHH(K),CLHOX(K),CLHHL(K),CLHEL(K)
2230  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 2290
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 2240 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHN2(K),CLHO2(K),CLHO(K),
     $CLHHE(K),CLHH(K),CLHOX(K),CLHHL(K),CLHEL(K)
2240  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 2290
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 2250 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHN2(K),CLHO2(K),CLHO(K),
     $CLHHE(K),CLHH(K),CLHOX(K),CLHHL(K),CLHEL(K)
2250  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 2290
      DO 2260 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),CLHN2(K),CLHO2(K),CLHO(K),
     $CLHHE(K),CLHH(K),CLHOX(K),CLHHL(K),CLHEL(K)
2260  CONTINUE
2290  CONTINUE
      WRITE (iUnitOutput,3217)
3217  FORMAT(1H1,50X,'COLLISION COEFFICIENTS FOR ELECTRONS')
      WRITE(iUnitOutput,3218)
3218  FORMAT(12X,'ALT',6X,'CLELN2',6X,'CLELO2',6X,'CLELO',7X,
     ;'CLELHE',6X,'CLELH',7X,'CLELOX',6X,'CLELHL',6X,'CLELHD')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 3230 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),CLELN2(K),CLELO2(K),CLELO(K),
     $CLELHE(K),CLELH(K),CLELOX(K),CLELHL(K),CLELHD(K)
3230  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 3290
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 3240 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),CLELN2(K),CLELO2(K),CLELO(K),
     $CLELHE(K),CLELH(K),CLELOX(K),CLELHL(K),CLELHD(K)
3240  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 3290
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 3250 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),CLELN2(K),CLELO2(K),CLELO(K),
     $CLELHE(K),CLELH(K),CLELOX(K),CLELHL(K),CLELHD(K)
3250  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 3290
      DO 3260 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),CLELN2(K),CLELO2(K),CLELO(K),
     $CLELHE(K),CLELH(K),CLELOX(K),CLELHL(K),CLELHD(K)
3260  CONTINUE
3290  CONTINUE
      WRITE(iUnitOutput,1047)
1047  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR OXYGEN')
      WRITE(iUnitOutput,1048)
1048  FORMAT(12X,'ALT',7X,'CFOXN2',6X,'CFOXO2',6X,'CFOXO',7X,
     ;'CFOXHE',6X,'CFOXH',7X,'CFOXHL',6X,'CFOXHD',6X,'CFOXEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 531 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),CollisionFreq_IIC(Ion1_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion3_,K),
     &  CollisionFreq_IIC(Ion1_,Ion2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion4_,K)
531   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 591
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 541 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),CollisionFreq_IIC(Ion1_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion3_,K),
     &  CollisionFreq_IIC(Ion1_,Ion2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion4_,K)
541   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 591
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 551 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),CollisionFreq_IIC(Ion1_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion3_,K),
     &  CollisionFreq_IIC(Ion1_,Ion2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion4_,K)

551   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 591
      DO 561 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),CollisionFreq_IIC(Ion1_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion1_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion3_,K),
     &  CollisionFreq_IIC(Ion1_,Ion2_,K),
     &  CollisionFreq_IIC(Ion1_,Ion4_,K)

561   CONTINUE
591   CONTINUE
      WRITE (iUnitOutput,1247)
1247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR HELIUM')
      WRITE(iUnitOutput,1248)
1248  FORMAT(12X,'ALT',7X,'CFHEN2',6X,'CFHEO2',6X,'CFHEO',7X,
     ;'CFHEHE',6X,'CFHEH',7X,'CFHEOX',6X,'CFHEHD',6X,'CFHEEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 1231 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion3_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion1_,K),
     &  CollisionFreq_IIC(Ion3_,Ion2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion4_,K)

1231  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 1291
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 1241 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion3_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion1_,K),
     &  CollisionFreq_IIC(Ion3_,Ion2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion4_,K)

1241  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 1291
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 1251 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion3_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion1_,K),
     &  CollisionFreq_IIC(Ion3_,Ion2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion4_,K)

1251  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 1291
      DO 1261 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion3_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion3_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion1_,K),
     &  CollisionFreq_IIC(Ion3_,Ion2_,K),
     &  CollisionFreq_IIC(Ion3_,Ion4_,K)

1261  CONTINUE
1291  CONTINUE
      WRITE (iUnitOutput,2247)
2247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR HYDROGEN')
      WRITE(iUnitOutput,2248)
2248  FORMAT(12X,'ALT',7X,'CFHN2',7X,'CFHO2',7X,'CFHO',8X,
     ;'CFHHE',7X,'CFHH',8X,'CFHOX',7X,'CFHHL',7X,'CFHEL')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 2231 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion2_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion2_,Ion1_,K),
     &  CollisionFreq_IIC(Ion2_,Ion3_,K),
     &  CollisionFreq_IIC(Ion2_,Ion4_,K)

2231  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 2291
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 2241 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion2_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion2_,Ion1_,K),
     &  CollisionFreq_IIC(Ion2_,Ion3_,K),
     &  CollisionFreq_IIC(Ion2_,Ion4_,K)

2241  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 2291
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 2251 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion2_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion2_,Ion1_,K),
     &  CollisionFreq_IIC(Ion2_,Ion3_,K),
     &  CollisionFreq_IIC(Ion2_,Ion4_,K)

2251  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 2291
      DO 2261 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion2_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion2_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion2_,Ion1_,K),
     &  CollisionFreq_IIC(Ion2_,Ion3_,K),
     &  CollisionFreq_IIC(Ion2_,Ion4_,K)


2261  CONTINUE
2291  CONTINUE
      WRITE (iUnitOutput,3247)
3247  FORMAT(1H1,50X,'COLLISION FREQUENCIES FOR ELECTRONS')
      WRITE(iUnitOutput,3248)
3248  FORMAT(12X,'ALT',7X,'CFELN2',6X,'CFELO2',6X,'CFELO',7X,
     ;'CFELHE',6X,'CFELH',7X,'CFELOX',6X,'CFELHL',6X,'CFELHD')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 3231 K=1,NDMQ
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion4_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion4_,Ion1_,K),
     &  CollisionFreq_IIC(Ion4_,Ion3_,K),
     &  CollisionFreq_IIC(Ion4_,Ion2_,K)

3231  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 3291
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 3241 K=NPT2,NDMQ,2
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion4_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion4_,Ion1_,K),
     &  CollisionFreq_IIC(Ion4_,Ion3_,K),
     &  CollisionFreq_IIC(Ion4_,Ion2_,K)


3241  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 3291
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 3251 K=NPT4,NDMQ,5
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion4_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion4_,Ion1_,K),
     &  CollisionFreq_IIC(Ion4_,Ion3_,K),
     &  CollisionFreq_IIC(Ion4_,Ion2_,K)


3251  CONTINUE
      IF (NDIM.LT.NPT6) GO TO 3291
      DO 3261 K=NPT6,NDIM,10
      WRITE (iUnitOutput,1180) K,ALTD(K),
     &  CollisionFreq_IIC(Ion4_,Neutral4_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral3_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral1_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral5_,K),
     &  CollisionFreq_IIC(Ion4_,Neutral2_,K),
     &  CollisionFreq_IIC(Ion4_,Ion1_,K),
     &  CollisionFreq_IIC(Ion4_,Ion3_,K),
     &  CollisionFreq_IIC(Ion4_,Ion2_,K)


3261  CONTINUE
3291  CONTINUE
      WRITE (iUnitOutput,1013)
1013  FORMAT(1H1,45X,'INITIAL OXYGEN PARAMETERS')
      WRITE(iUnitOutput,1021)
1021  FORMAT(16X,'ALT',10X,'VELOCITY',8X,'MACH NO',9X,'DENSITY',9X,
     ;'PRESSURE',6X,'TEMPERATURE',/)
      K=0
      XM=USURFO/WSURFO
      DNS1=DSURFO/XMSO
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFO,XM,DNS1,PSURFO,TSURFO
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 630 K=1,NDMQ
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
630   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 690
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 640 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
640   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 690
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 650 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
650   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 690
      DO 660 K=NPT6,NDIM,10
      US=SQRT(GAMMA*POXYG(K)/DOXYG(K))
      XM=UOXYG(K)/US
      DNS1=DOXYG(K)/XMSO
      WRITE(iUnitOutput,1022) K,ALTD(K),UOXYG(K),XM,DNS1,POXYG(K),TOXYG(K)
660   CONTINUE
690   CONTINUE
      K=NDIM1
      XM=UBGNDO/WBGNDO
      DNS1=DBGNDO/XMSO
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDO,XM,DNS1,PBGNDO,TBGNDO
      WRITE (iUnitOutput,1055)
1055  FORMAT(1H1,45X,'INITIAL HELIUM PARAMETERS')
      WRITE(iUnitOutput,1056)
1056  FORMAT(16X,'ALT',10X,'VELOCITY',8X,'MACH NO',9X,'DENSITY',9X,
     ;'PRESSURE',6X,'TEMPERATURE',/)
      K=0
      XM=USURHE/WSURHE
      DNS1=DSURHE/XMSHE
      WRITE(iUnitOutput,1022) K,ALTMIN,USURHE,XM,DNS1,PSURHE,TSURHE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 639 K=1,NDMQ
      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
      XM=UHEL(K)/US
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
639   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 699
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 649 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
      XM=UHEL(K)/US
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
649   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 699
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 659 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
      XM=UHEL(K)/US
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
659   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 699
      DO 669 K=NPT6,NDIM,10
      US=SQRT(GAMMA*PHEL(K)/DHEL(K))
      XM=UHEL(K)/US
      DNS1=DHEL(K)/XMSHE
      WRITE(iUnitOutput,1022) K,ALTD(K),UHEL(K),XM,DNS1,PHEL(K),THEL(K)
669   CONTINUE
699   CONTINUE
      K=NDIM1
      XM=UBGNHE/WBGNHE
      DNS1=DBGNHE/XMSHE
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNHE,XM,DNS1,PBGNHE,TBGNHE
      WRITE (iUnitOutput,1010)
1010  FORMAT(1H1,45X,'INITIAL HYDROGEN PARAMETERS')
      WRITE(iUnitOutput,1021)
      K=0
      XM=USURFH/WSURFH
      DNS1=DSURFH/XMSH
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFH,XM,DNS1,PSURFH,TSURFH
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 730 K=1,NDMQ
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
730   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 790
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 740 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
740   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 790
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 750 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
750   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 790
      DO 760 K=NPT6,NDIM,10
      US=SQRT(GAMMA*PHYD(K)/DHYD(K))
      XM=UHYD(K)/US
      DNS1=DHYD(K)/XMSH
      WRITE(iUnitOutput,1022) K,ALTD(K),UHYD(K),XM,DNS1,PHYD(K),THYD(K)
760   CONTINUE
790   CONTINUE
      K=NDIM1
      XM=UBGNDH/WBGNDH
      DNS1=DBGNDH/XMSH
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDH,XM,DNS1,PBGNDH,TBGNDH
      WRITE (iUnitOutput,1011)
1011  FORMAT(1H1,45X,'INITIAL ELECTRON PARAMETERS')
      WRITE(iUnitOutput,1021)
      K=0
      XM=USURFE/WSURFE
      DNS1=DSURFE/XMSE
      WRITE(iUnitOutput,1022) K,ALTMIN,USURFE,XM,DNS1,PSURFE,TSURFE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 830 K=1,NDMQ
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
830   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 890
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 840 K=NPT2,NDMQ,2
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
840   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 890
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 850 K=NPT4,NDMQ,5
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
850   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 890
      DO 860 K=NPT6,NDIM,10
      US=SQRT(GAMMA*PELECT(K)/DELECT(K))
      XM=UELECT(K)/US
      DNS1=DELECT(K)/XMSE
      WRITE(iUnitOutput,1022) K,ALTD(K),UELECT(K),XM,DNS1,PELECT(K),TELECT(K)
860   CONTINUE
890   CONTINUE
      K=NDIM1
      XM=UBGNDE/WBGNDE
      DNS1=DBGNDE/XMSE
      WRITE(iUnitOutput,1022) K,ALTMAX,UBGNDE,XM,DNS1,PBGNDE,TBGNDE
      WRITE(iUnitOutput,1024)
1024  FORMAT(1H1,40X,'INITIAL ELECTRIC FIELD AND SOURCE PARAMETERS')
      WRITE(iUnitOutput,1025)
1025  FORMAT(13X,'ALT',6X,'EFIELD',6X,'FCLSNO',6X,'ECLSNO',6X,'FCLSHE',
     ;6X,'ECLSHE',6X,'FCLSNH',6X,'ECLSNH',6X,'FCLSNE',6X,'ECLSNE')
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 930 K=1,NDMQ
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
930   CONTINUE
      IF (NDIM.LT.NPT2) GO TO 990
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 940 K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
940   CONTINUE
      IF (NDIM.LT.NPT4) GO TO 990
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 950 K=NPT4,NDMQ,5
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
950   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 990
      DO 960 K=NPT6,NDIM,10
      WRITE(iUnitOutput,1026) K,ALTD(K),EFIELD(K),FCLSNO(K),ECLSNO(K),FCLSHE(K),
     ;ECLSHE(K),FCLSNH(K),ECLSNH(K),FCLSNE(K),ECLSNE(K)
960   CONTINUE
990   CONTINUE
999   CONTINUE
      WRITE (iUnitOutput,2013)
2013  FORMAT(1H1,45X,'HEAT CONDUCTIVITIES')
      WRITE(iUnitOutput,2021)
2021  FORMAT(16X,'ALT',10X,'OXYGEN',10X,'HELIUM',9X,'HYDROGEN',9X,
     ;'ELECTRONS'/)
      K=0
      WRITE(iUnitOutput,1022) K,ALTMIN,TCSFO,TCSFHE,TCSFH,TCSFE
      NDMQ=NPT1
      IF (NDIM.LT.NPT2) NDMQ=NDIM
      DO 2630 K=1,NDMQ
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2630  CONTINUE
      IF (NDIM.LT.NPT2) GO TO 2690
      NDMQ=NPT3
      IF (NDIM.LT.NPT4) NDMQ=NDIM
      DO 2640 K=NPT2,NDMQ,2
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2640  CONTINUE
      IF (NDIM.LT.NPT4) GO TO 2690
      NDMQ=NPT5
      IF (NDIM.LT.NPT6) NDMQ=NDIM
      DO 2650 K=NPT4,NDMQ,5
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2650   CONTINUE
      IF (NDIM.LT.NPT6) GO TO 2690
      DO 2660 K=NPT6,NDIM,10
      WRITE(iUnitOutput,1022) K,ALTD(K),TCONO(K),TCONHE(K),TCONH(K),TCONE(K)
2660   CONTINUE
2690   CONTINUE
      K=NDIM1
      WRITE(iUnitOutput,1022) K,ALTMAX,TCBGO,TCBGHE,TCBGH,TCBGE
1019  FORMAT(3X,I3,0PF10.2,2X,11(1PE10.2))
1022  FORMAT(3X,I3,0PF14.2,2X,6(1PE16.5))
1026  FORMAT(3X,I3,0PF11.2,2X,9(1PE12.4))
1180  FORMAT(3X,I3,0PF10.2,2X,8(1PE12.4))
1028  FORMAT(3X,I3,0PF14.2,2X,2(1PE16.5))
1031  FORMAT(3X,I3,0PF14.2,2X,4(1PE16.5))

      endif
      RETURN
      END

      

CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     ALEX(10/11/04): I THINK THIS IS A COLD START ROUTINE FOR DEALING WITH
C     A LACK OF RESTART FILE. BASICALLY THE VELOCITY IS SET TO ZERO AND 
C     THE OTHER GRID VALUES ARE SET TO VALUES THAT WON'T CRASH.
C     (11/9/04) I also see that source terms and collision terms are set
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
      

      SUBROUTINE STRT1
      use ModCommonVariables

C     
C     
C     
C     
C     PHIOX=7.00E-7
C     
C     DEFINE THE HE PHOTOIONIZATION RATE
C     
C      PHIHE=1.30E-7
      PHIHE=3.87E-8
C     
C     C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     C
C     DEFINE THE GAS PARAMETERS AT THE LOWER BOUNDARY                  C
C     C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     C
      USURFO=0.
      USURFH=0.
      USURHE=0.
      USURFE=0.
      CALL MODATM(ALTMIN,XNO2,XNN2,XNO,XNH,XNHE,TEMP)
      TSURFO=TEMP
      TSURFH=TEMP
      TSURHE=TEMP
      TSURFE=TEMP
      TMP1=1.-1.290E-3*TEMP+6.233E-7*TEMP**2
      TMP2=1.-9.149E-4*TEMP+4.228E-7*TEMP**2-6.790E-11*TEMP**3+
     $     4.225E-15*TEMP**4
C     DSURFO=PHIOX*XMSO*XNO/(1.53E-12*XNN2*TMP1+2.82E-11*XNO2*TMP2)
      DSURFO=PHOTOTF(1)*XMSO*XNO/(1.53E-12*XNN2*TMP1+2.82E-11*XNO2*TMP2)
      DSURHE=PHIHE*XMSHE*XNHE/(1.10E-9*XNO2+1.60E-9*XNN2)
      DSURFH=1.136*(XNH/XNO)*(XMSH/XMSO)*DSURFO
      DSURFE=RTHDEL*DSURFH+RTOXEL*DSURFO+RTHEEL*DSURHE
      PSURFO=RGASO*TSURFO*DSURFO
      PSURFH=RGASH*TSURFH*DSURFH
      PSURHE=RGASHE*TSURHE*DSURHE
      PSURFE=RGASE*TSURFE*DSURFE
      WSURFO=SQRT(GAMMA*RGASO*TSURFO)
      WSURFH=SQRT(GAMMA*RGASH*TSURFH)
      WSURHE=SQRT(GAMMA*RGASHE*TSURHE)
      WSURFE=SQRT(GAMMA*RGASE*TSURFE)
C     
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C     
      DO 20 I=1,NDIM
C     FFOX1(1) BASED ON PHOTOIONIZATION FREQ FROM SUB GLOWEX;MASS OXYGEN IN GRAMS
         FFOX1(I)=PHOTOTF(I+1)*16.*1.6726E-24*XO(I)
C     FFOX1(I)=PHIOX*XMSO*XO(I)
CALEX SOURCE COEF?         
         FFOX2(I)=2.2E-11*XMSO*XO(I)/XMSH
         FFOX3(I)=-2.5E-11*XH(I)
         FFOX4(I)=-1.53E-12*XN2(I)
         FFOX5(I)=-2.73E-12*XN2(I)
         FFOX6(I)=-2.82E-11*XO2(I)
         FFHYD1(I)=2.5E-11*XMSH*XH(I)/XMSO
         FFHYD2(I)=-2.2E-11*XO(I)
         FFHE1(I)=PHIHE*XMSHE*XHE(I)
         FFHE2(I)=-(1.10E-9*XO2(I)+1.60E-9*XN2(I))


CALEX CL=COLLISION COEF, CF=collision freq ?         
CALEX cf O+ and N2         
         !CFOXN2(I)=6.82E-10*XN2(I)
         CollisionFreq_IIC(Ion1_,Neutral4_,I)=6.82E-10*XN2(I)
CALEX cf of O+ and O2         
         !CFOXO2(I)=6.64E-10*XO2(I)
         CollisionFreq_IIC(Ion1_,Neutral3_,I)=6.64E-10*XO2(I)
CALEX cf of O+ and He         
         !CFOXHE(I)=1.32E-10*XHE(I)
         CollisionFreq_IIC(Ion1_,Neutral5_,I)=1.32E-10*XHE(I)
CALEX cl for O+ and O
         CLOXO(I)=3.67E-11*XO(I)
CALEX seems like cl for O+ and H but I think the constant 4.63
CALEX is wrong. see nagy p.99         
         CLOXH(I)=4.63E-12*XH(I)
CALEX cl for O+ and H+         
         CLOXHD(I)=0.077*17.**1.5/XMSH
CALEX cl for O+ and He+         
         CLOXHL(I)=0.14*5.**1.5/XMSHE
CALEX cl for O and electrons??        
         CLOXEL(I)=1.86E-3/XMSE

CALEX cf of H+ and N2  
         !CFHN2(I)=3.36E-9*XN2(I)
         CollisionFreq_IIC(Ion2_,Neutral4_,I)=3.36E-9*XN2(I)
CALEX cf of H+ and O2
         !CFHO2(I)=3.20E-9*XO2(I)
         CollisionFreq_IIC(Ion2_,Neutral3_,I)=3.20E-9*XO2(I)
CALEX cf of H+ and He         
         !CFHHE(I)=1.06E-9*XHE(I)
         CollisionFreq_IIC(Ion2_,Neutral5_,I)=1.06E-9*XHE(I)
CALEX cl for ion neutral collsion       
         CLHO(I)=6.61E-11*XO(I)
         CLHH(I)=2.65E-10*XH(I)
CALEX cl for ion ion collision         
         CLHOX(I)=1.23*17.**1.5/XMSO
         CLHHL(I)=1.14*5.**1.5/XMSHE
         CLHEL(I)=2.97E-2/XMSE

CALEX cf of He+ and N2
         !CFHEN2(I)=1.60E-9*XN2(I)
         CollisionFreq_IIC(Ion3_,Neutral4_,I)=1.60E-9*XN2(I)
CALEX cf of He+ and O2         
         !CFHEO2(I)=1.53E-9*XO2(I)
         CollisionFreq_IIC(Ion3_,Neutral3_,I)=1.53E-9*XO2(I)
CALEX cl for He+ and He         
         CLHEHE(I)=8.73E-11*XHE(I)
CALEX cf of He+ and O         
         !CFHEO(I)=1.01E-9*XO(I)
         CollisionFreq_IIC(Ion3_,Neutral1_,I)=1.01E-9*XO(I)
CALEX cf of He+ and H         
         !CFHEH(I)=4.71E-10*XH(I)
         CollisionFreq_IIC(Ion3_,Neutral2_,I)=4.71E-10*XH(I)
CALEX these are cl for ion ion collisions
         CLHEOX(I)=0.57*5.**1.5/XMSO
         CLHEHD(I)=0.28*5.**1.5/XMSH
         CLHEEL(I)=7.43E-3/XMSE
        
CALEX cf of electrons and N2? this doesnt match nagy p 97 though?? 
         !CFELN2(I)=3.42E-9*XN2(I)
         CollisionFreq_IIC(Ion4_,Neutral4_,I)=3.42E-9*XN2(I)
         !CFELO2(I)=3.25E-9*XO2(I)
         CollisionFreq_IIC(Ion4_,Neutral3_,I)=3.25E-9*XO2(I)
         !CFELHE(I)=1.18E-9*XHE(I)
         CollisionFreq_IIC(Ion4_,Neutral5_,I)=1.18E-9*XHE(I)
         !CFELO(I)=2.26E-9*XO(I)
         CollisionFreq_IIC(Ion4_,Neutral1_,I)=2.26E-9*XO(I)
         !CFELH(I)=2.11E-9*XH(I)
         CollisionFreq_IIC(Ion4_,Neutral2_,I)=2.11E-9*XH(I)
CALEX similar to nagy p95 but I cant find the connection???         
         CLELOX(I)=54.5/XMSO
         CLELHL(I)=54.5/XMSHE
         CLELHD(I)=54.5/XMSH
         GRAVTY(I)=-3.96E20/RAD(I)**2
         Centrifugal(I)=wHorizontal**2.0*RAD(I)
 20   CONTINUE
cAlex
      NEXP=3
cendAlex      
!      CRRX=CURR(1)*RAD(1)**NEXP
!      DO 25 I=1,NDIM
!         CURR(I)=CRRX/RAD(I)**NEXP
! 25   CONTINUE
C     SGN1=1.
C     IF (CURR(1).LT.0.) SGN1=-1.
C     IF (ABS(CURR(1)).LT.1.E-4) SGN1=0.
C     DO 30 I=NDIM-250,NDIM
C     CURR(I)=SGN1*0.2998*(RAD(1)/RAD(I))**NEXP
C     30    CONTINUE
      
CALEX CT & CM = energy collision term coef?
CALEX Based on Nagy p. 83, I believe that CT is the coeff
CALEX of the term that is due to temperature difference or
CALEX heat flow between species, and CM is the term due to 
CALEX frictional heating between species moving through each other

CALEX CTOXN2 = 3*R_o*M_o/(M_o+M_{N2}) see nagy p.83
      HeatFlowCoef_II(Ion1_,Neutral4_)=3.*RGASO*XMSO/(XMSO+28.*XAMU)
      HeatFlowCoef_II(Ion1_,Neutral3_)=3.*RGASO*XMSO/(XMSO+32.*XAMU)
      HeatFlowCoef_II(Ion1_,Neutral1_)=3.*RGASO*XMSO/(XMSO+XMSO)
      HeatFlowCoef_II(Ion1_,Neutral5_)=3.*RGASO*XMSO/(XMSO+XMSHE)
      HeatFlowCoef_II(Ion1_,Neutral2_)=3.*RGASO*XMSO/(XMSO+XMSH)
      HeatFlowCoef_II(Ion1_,Ion2_) = 3.*RGASO*XMSO/(XMSO+XMSH)
      HeatFlowCoef_II(Ion1_,Ion3_) = 3.*RGASO*XMSO/(XMSO+XMSHE)
      HeatFlowCoef_II(Ion1_,Ion4_) = 3.*RGASO*XMSO/(XMSO+XMSE)
      
      MassFracCoef_II(Ion1_,:) = HeatFlowCoef_II(Ion1_,:) / (3.0*RGASO)


      HeatFlowCoef_II(Ion2_,Neutral4_)=3.*RGASH*XMSH/(XMSH+28.*XAMU)
      HeatFlowCoef_II(Ion2_,Neutral3_)=3.*RGASH*XMSH/(XMSH+32.*XAMU)
      HeatFlowCoef_II(Ion2_,Neutral5_)=3.*RGASH*XMSH/(XMSH+XMSHE)
      HeatFlowCoef_II(Ion2_,Neutral1_)=3.*RGASH *XMSH/(XMSH+XMSO)
      HeatFlowCoef_II(Ion2_,Neutral2_)=3.*RGASH*XMSH/(XMSH+XMSH)
      HeatFlowCoef_II(Ion2_,Ion1_) = 3.*RGASH *XMSH/(XMSH+XMSO)
      HeatFlowCoef_II(Ion2_,Ion3_) = 3.*RGASH*XMSH/(XMSH+XMSHE)
      HeatFlowCoef_II(Ion2_,Ion4_) =3.*RGASH*XMSH/(XMSH+XMSE)
      
      MassFracCoef_II(Ion2_,:) = HeatFlowCoef_II(Ion2_,:) / (3.0*RGASH)


      HeatFlowCoef_II(Ion3_,Neutral4_)=3.*RGASHE*XMSHE/(XMSHE+28.*XAMU)
      HeatFlowCoef_II(Ion3_,Neutral3_)=3.*RGASHE*XMSHE/(XMSHE+32.*XAMU)
      HeatFlowCoef_II(Ion3_,Neutral5_)=3.*RGASHE*XMSHE/(XMSHE+XMSHE)
      HeatFlowCoef_II(Ion3_,Neutral1_)=3.*RGASHE*XMSHE/(XMSHE+XMSO)
      HeatFlowCoef_II(Ion3_,Neutral2_)=3.*RGASHE*XMSHE/(XMSHE+XMSH)
      HeatFlowCoef_II(Ion3_,Ion1_)=3.*RGASHE*XMSHE/(XMSHE+XMSO)
      HeatFlowCoef_II(Ion3_,Ion2_)=3.*RGASHE*XMSHE/(XMSHE+XMSH)
      HeatFlowCoef_II(Ion3_,Ion4_)=3.*RGASHE*XMSHE/(XMSHE+XMSE)

      MassFracCoef_II(Ion3_,:) = HeatFlowCoef_II(Ion3_,:) / (3.0*RGASHE)

      
      HeatFlowCoef_II(Ion4_,Neutral4_)=3.*RGASE*XMSE/(28.*XAMU+XMSE)
      HeatFlowCoef_II(Ion4_,Neutral3_)=3.*RGASE*XMSE/(32.*XAMU+XMSE)
      HeatFlowCoef_II(Ion4_,Neutral5_)=3.*RGASE*XMSE/(XMSE+XMSHE)
      HeatFlowCoef_II(Ion4_,Neutral1_)=3.*RGASE*XMSE/(XMSE+XMSO)
      HeatFlowCoef_II(Ion4_,Neutral2_)=3.*RGASE*XMSE/(XMSE+XMSH)
      HeatFlowCoef_II(Ion4_,Ion1_)=3.*RGASE*XMSE/(XMSE+XMSO)
      HeatFlowCoef_II(Ion4_,Ion3_)=3.*RGASE*XMSE/(XMSE+XMSHE)
      HeatFlowCoef_II(Ion4_,Ion2_)=3.*RGASE*XMSE/(XMSE+XMSH)

      MassFracCoef_II(Ion4_,:) = HeatFlowCoef_II(Ion4_,:) / (3.0*RGASE)

CALEX CMOXN2 = M_{N2}/(M_o+M_{N2}) see nagy p.83
      FricHeatCoef_II(Ion1_,Neutral4_)=28.*XAMU/(XMSO+28.*XAMU)
      FricHeatCoef_II(Ion1_,Neutral3_)=32.*XAMU/(XMSO+32.*XAMU)
      FricHeatCoef_II(Ion1_,Neutral1_)=XMSO/(XMSO+XMSO)
      FricHeatCoef_II(Ion1_,Neutral5_)=XMSHE/(XMSO+XMSHE)
      FricHeatCoef_II(Ion1_,Neutral2_)=XMSH/(XMSO+XMSH)
      FricHeatCoef_II(Ion1_,Ion2_)=XMSH/(XMSO+XMSH)
      FricHeatCoef_II(Ion1_,Ion3_)=XMSHE/(XMSO+XMSHE)
      FricHeatCoef_II(Ion1_,Ion4_)=XMSE/(XMSE+XMSO)

      FricHeatCoef_II(Ion2_,Neutral4_)=28.*XAMU/(XMSH+28.*XAMU)
      FricHeatCoef_II(Ion2_,Neutral3_)=32.*XAMU/(XMSH+32.*XAMU)
      FricHeatCoef_II(Ion2_,Neutral5_)=XMSHE/(XMSH+XMSHE)
      FricHeatCoef_II(Ion2_,Neutral1_)=XMSO/(XMSH+XMSO)
      FricHeatCoef_II(Ion2_,Neutral2_)=XMSH/(XMSH+XMSH)
      FricHeatCoef_II(Ion2_,Ion1_)=XMSO/(XMSH+XMSO)
      FricHeatCoef_II(Ion2_,Ion3_)=XMSHE/(XMSH+XMSHE)
      FricHeatCoef_II(Ion2_,Ion4_)=XMSE/(XMSE+XMSH)

      FricHeatCoef_II(Ion3_,Neutral4_)=28.*XAMU/(XMSHE+28.*XAMU)
      FricHeatCoef_II(Ion3_,Neutral3_)=32.*XAMU/(XMSHE+32.*XAMU)
      FricHeatCoef_II(Ion3_,Neutral5_)=XMSHE/(XMSHE+XMSHE)
      FricHeatCoef_II(Ion3_,Neutral1_)=XMSO/(XMSHE+XMSO)
      FricHeatCoef_II(Ion3_,Neutral2_)=XMSH/(XMSHE+XMSH)
      FricHeatCoef_II(Ion3_,Ion1_)    =XMSO/(XMSHE+XMSO)
      FricHeatCoef_II(Ion3_,Ion2_)    =XMSH/(XMSHE+XMSH)
      FricHeatCoef_II(Ion3_,Ion4_)    =XMSE/(XMSE+XMSHE)

      FricHeatCoef_II(Ion4_,Neutral4_)=28.*XAMU/(XMSE+28.*XAMU)
      FricHeatCoef_II(Ion4_,Neutral3_)=32.*XAMU/(XMSE+32.*XAMU)
      FricHeatCoef_II(Ion4_,Neutral5_)=XMSHE/(XMSE+XMSHE)
      FricHeatCoef_II(Ion4_,Neutral1_)=XMSO/(XMSE+XMSO)
      FricHeatCoef_II(Ion4_,Neutral2_)=XMSH/(XMSE+XMSH)
      FricHeatCoef_II(Ion4_,Ion1_)    =XMSO/(XMSE+XMSO)
      FricHeatCoef_II(Ion4_,Ion2_)    =XMSH/(XMSE+XMSH)
      FricHeatCoef_II(Ion4_,Ion3_)    =XMSHE/(XMSE+XMSHE)



C     ALEX(10/11/04): 
C     TRY SETTING THE PLASMA PARAMETERS HERE TO THE SURFACE VALUES

      if(IsRestart) RETURN

      do K=1,NDIM
c         DHYD(K)=DSURFH
c         UOXYG(K)=0
c         POXYG(K)=PSURFOH
c         DOXYG(K)=DSURFOH
c         TOXYG(K)=TSURFO
c         UHYD(K)=0
c         PHYD(K)=PSURFHH
c         THYD(K)=TSURFH
c         UHEL(K)=0
c         PHEL(K)=PSURHEH
c         DHEL(K)=DSURHEH
c         THEL(K)=TSURHE
c         DELECT(K)=DSURFEH
c         UELECT(K)=0
c         PELECT(K)=PSURFEH
c         TELECT(K)=TSURFE


         DHYD(K)=1.*DSURFH*exp(-1.*real(K)/90.)
         UOXYG(K)=20.
         POXYG(K)=1.*PSURFO*exp(-1.*real(K)/90.)
         DOXYG(K)=1.*DSURFO*exp(-1.*real(K)/90.)
c         TOXYG(K)=TSURFO
         TOXYG(K)=POXYG(K)/(1.38e-16*DOXYG(K)/xmso)
         UHYD(K)=40.
         PHYD(K)=1.*PSURFH*exp(-1.*real(K)/90.)
c         THYD(K)=TSURFH*exp(-1.*real(K)/9000.)
         THYD(K)=PHYD(K)/(1.38e-16*DHYD(K)/xmsh)
         UHEL(K)=4.
         PHEL(K)=1.*PSURHE*exp(-1.*real(K)/90.)
         DHEL(K)=1.*DSURHE*exp(-1.*real(K)/90.)
c         THEL(K)=TSURHE
         THEL(K)=PHEL(K)/(1.38e-16*DHEL(K)/xmshe)
         DELECT(K)=1.*DSURFE*exp(-1.*real(K)/90.)
         UELECT(K)=1.
         PELECT(K)=1.*PSURFE*exp(-1.*real(K)/90.)
c         TELECT(K)=TSURFE
         TELECT(K)=PELECT(K)/(1.38e-16*DELECT(K)/xmse)

      enddo

      RETURN
      END
