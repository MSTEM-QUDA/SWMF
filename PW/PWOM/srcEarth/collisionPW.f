
CALEX This subroutine calculates the collision frequencies and
CALEX then calculates the momentum and energy collision terms
      SUBROUTINE COLLIS(N)
      use ModCommonVariables
      
      real :: dT_II(nIon,nSpecies),dU2_II(nIon,nSpecies)
C     
C
C
C
      DO  I=1,N
      TOX2=State_GV(I,To_)*State_GV(I,To_)
      TOX3=TOX2*State_GV(I,To_)
      TOX4=TOX2*TOX2
      AAH=SQRT(State_GV(I,Th_)+XTN(I)/16.+1.2E-8*State_GV(I,uH_)*State_GV(I,uH_))
      BBH=SQRT(XTN(I)+State_GV(I,To_)/16.+1.2E-8*State_GV(I,uO_)*State_GV(I,uO_))
      CCH=1.-9.149E-4*State_GV(I,To_)+4.228E-7*TOX2-6.790E-11*TOX3+
     ;4.225E-15*TOX4
      IF (State_GV(I,To_).LE.1700.) then
         FFOXYG=FFOX4(I)*(1.-1.290E-3*State_GV(I,To_)+6.233E-7*TOX2)
      else
         FFOXYG=FFOX5(I)*(1.-1.410E-3*State_GV(I,To_)+6.036E-7*TOX2)
      endif
      Source_CV(I,RhoO_)=FFOX1(I)+FFOX2(I)*AAH*State_GV(I,RhoH_)+(FFOX3(I)*BBH+
     ;FFOXYG+FFOX6(I)*CCH)*State_GV(I,RhoO_)


      Source_CV(I,RhoH_)=FFHYD1(I)*BBH*State_GV(I,RhoO_)+FFHYD2(I)*AAH*State_GV(I,RhoH_)
      Source_CV(I,RhoHe_)=FFHE1(I)+FFHE2(I)*State_GV(I,RhoHe_)
      Source_CV(I,RhoE_)=MassElecIon_I(Ion2_)*Source_CV(I,RhoH_)+MassElecIon_I(Ion1_)*Source_CV(I,RhoO_)
     &     +MassElecIon_I(Ion3_)*Source_CV(I,RhoHe_)
C
      TROX=0.5*(XTN(I)+State_GV(I,To_))
      TRHYD=0.5*(XTN(I)+State_GV(I,Th_))
      TRHEL=0.5*(XTN(I)+State_GV(I,The_))
      T1OX=SQRT(XTN(I)+State_GV(I,To_)/16.)

CALEX These are (reduced temperatures) * (m1+m2) raised to the 1.5
CALEX as shown on page 86 Nagy. This is for use in collision freqs
CALEX of coulomb collisions below.       
      T1OXH=(State_GV(I,To_)+16.*State_GV(I,Th_))**1.5
      T1OXHE=(State_GV(I,To_)+4.*State_GV(I,The_))**1.5
      T1HEH=(State_GV(I,The_)+4.*State_GV(I,Th_))**1.5
      TE32=State_GV(I,Te_)**1.5
      DTE32=State_GV(I,RhoE_)/TE32
CALEX calculate collision frequencies. 

CALEX cf of O+ and O
!      CFOXO(I)=CLOXO(I)*SQRT(TROX)*(1.-0.064*ALOG10(TROX))**2
      CollisionFreq_IIC(Ion1_,Neutral1_,I)=
     &     CLOXO(I)*SQRT(TROX)*(1.-0.064*ALOG10(TROX))**2
CALEX this looks like cf of O+ and H but see comments for cloxh
!      CFOXH(I)=CLOXH(I)*T1OX
      CollisionFreq_IIC(Ion1_,Neutral2_,I)=CLOXH(I)*T1OX
CALEX cf of O+ and H+. coulomb collisions as eq 4.142 p.95 in Nagy
!      CFOXHD(I)=CLOXHD(I)*State_GV(I,RhoH_)/T1OXH
      CollisionFreq_IIC(Ion1_,Ion2_,I)=CLOXHD(I)*State_GV(I,RhoH_)/T1OXH
CALEX cf of O+ and He+. coulomb collisions as eq 4.142 p.95 in Nagy      
!      CFOXHL(I)=CLOXHL(I)*State_GV(I,RhoHe_)/T1OXHE
      CollisionFreq_IIC(Ion1_,Ion3_,I)=CLOXHL(I)*State_GV(I,RhoHe_)/T1OXHE
!      CFOXEL(I)=CLOXEL(I)*DTE32
      CollisionFreq_IIC(Ion1_,Ion4_,I)=CLOXEL(I)*DTE32
CALEX  cf of H+ and O      
!      CFHO(I)=CLHO(I)*SQRT(State_GV(I,Th_))*(1.-0.047*ALOG10(State_GV(I,Th_)))**2
      CollisionFreq_IIC(Ion2_,Neutral1_,I)=
     &     CLHO(I)*SQRT(State_GV(I,Th_))*(1.-0.047*ALOG10(State_GV(I,Th_)))**2

CALEX cf of H+ and H      
!      CFHH(I)=CLHH(I)*SQRT(TRHYD)*(1.-0.083*ALOG10(TRHYD))**2
      CollisionFreq_IIC(Ion2_,Neutral2_,I)=
     &     CLHH(I)*SQRT(TRHYD)*(1.-0.083*ALOG10(TRHYD))**2
CALEX cf of H+ and O+. coulomb collisions as eq 4.142 p.95 in Nagy      
!      CFHOX(I)=CLHOX(I)*State_GV(I,RhoO_)/T1OXH
      CollisionFreq_IIC(Ion2_,Ion1_,I)=CLHOX(I)*State_GV(I,RhoO_)/T1OXH
CALEX cf of H+ and He+. coulomb collisions as eq 4.142 p.95 in Nagy      
!      CFHHL(I)=CLHHL(I)*State_GV(I,RhoHe_)/T1HEH
      CollisionFreq_IIC(Ion2_,Ion3_,I)=CLHHL(I)*State_GV(I,RhoHe_)/T1HEH
!      CFHEL(I)=CLHEL(I)*DTE32
      CollisionFreq_IIC(Ion2_,Ion4_,I)=CLHEL(I)*DTE32
CALEX cf of He+ and HE      
!      CFHEHE(I)=CLHEHE(I)*SQRT(TRHEL)*(1.-0.093*ALOG10(TRHEL))**2
      CollisionFreq_IIC(Ion3_,Neutral5_,I)=
     &     CLHEHE(I)*SQRT(TRHEL)*(1.-0.093*ALOG10(TRHEL))**2
CALEX cf of He+ and O+      
!      CFHEOX(I)=CLHEOX(I)*State_GV(I,RhoO_)/T1OXHE
      CollisionFreq_IIC(Ion3_,Ion1_,I)=CLHEOX(I)*State_GV(I,RhoO_)/T1OXHE
CALEX cf of He+ and H+      
!      CFHEHD(I)=CLHEHD(I)*State_GV(I,RhoH_)/T1HEH
      CollisionFreq_IIC(Ion3_,Ion2_,I)=CLHEHD(I)*State_GV(I,RhoH_)/T1HEH
CALEX cfheel=7.43E-3/M_e * n_e / T_e^1.5, this seems like it should be
CALEX the cf between He and electrons but the formula does not match 4.144
!      CFHEEL(I)=CLHEEL(I)*DTE32
      CollisionFreq_IIC(Ion3_,Ion4_,I)=CLHEEL(I)*DTE32
CALEX cf for electrons and O, same as 4.144      
!      CFELOX(I)=CLELOX(I)*State_GV(I,RhoO_)/TE32
      CollisionFreq_IIC(Ion4_,Ion1_,I)=CLELOX(I)*State_GV(I,RhoO_)/TE32
CALEX cf for electrons and He      
!      CFELHL(I)=CLELHL(I)*State_GV(I,RhoHe_)/TE32
      CollisionFreq_IIC(Ion4_,Ion3_,I)=CLELHL(I)*State_GV(I,RhoHe_)/TE32
CALEX cf for el and H      
!      CFELHD(I)=CLELHD(I)*State_GV(I,RhoH_)/TE32
      CollisionFreq_IIC(Ion4_,Ion2_,I)=CLELHD(I)*State_GV(I,RhoH_)/TE32
C
CALEX velocity difference needed for source terms
      UHDOX=State_GV(I,uH_)-State_GV(I,uO_)
      UHDHL=State_GV(I,uH_)-State_GV(I,uHe_)
      UHDEL=State_GV(I,uH_)-State_GV(I,uE_)
      UHEOX=State_GV(I,uHe_)-State_GV(I,uO_)
      UHEEL=State_GV(I,uHe_)-State_GV(I,uE_)
      UOXEL=State_GV(I,uO_)-State_GV(I,uE_)

CALEX This calculates collision source terms: 
CALEX fclsn1=n*((u2-u1)*cf12+(u3-u1)*cf13+...)
      Source_CV(I,uO_) = State_GV(I,RhoO_)*(
     &       UHDOX*CollisionFreq_IIC(Ion1_,Ion2_,I)
     &     + UHEOX*CollisionFreq_IIC(Ion1_,Ion3_,I)
     &     - UOXEL*CollisionFreq_IIC(Ion1_,Ion4_,I)
     &     -State_GV(I,uO_) * (
     &       CollisionFreq_IIC(Ion1_,Neutral1_,I)
     &     + CollisionFreq_IIC(Ion1_,Neutral2_,I)
     &     + CollisionFreq_IIC(Ion1_,Neutral3_,I)
     &     + CollisionFreq_IIC(Ion1_,Neutral4_,I)
     &     + CollisionFreq_IIC(Ion1_,Neutral5_,I)))
      
      Source_CV(I,uH_) = State_GV(I,RhoH_)*(
     &     - UHDOX*CollisionFreq_IIC(Ion2_,Ion1_,I)
     &     - UHDHL*CollisionFreq_IIC(Ion2_,Ion3_,I)
     &     - UHDEL*CollisionFreq_IIC(Ion2_,Ion4_,I)
     &     -State_GV(I,uH_) * (
     &       CollisionFreq_IIC(Ion2_,Neutral1_,I)
     &     + CollisionFreq_IIC(Ion2_,Neutral2_,I)
     &     + CollisionFreq_IIC(Ion2_,Neutral3_,I)
     &     + CollisionFreq_IIC(Ion2_,Neutral4_,I)
     &     + CollisionFreq_IIC(Ion2_,Neutral5_,I)))

      Source_CV(I,uHe_) = State_GV(I,RhoHe_)*(
     &       UHDHL*CollisionFreq_IIC(Ion3_,Ion2_,I)
     &     - UHEOX*CollisionFreq_IIC(Ion3_,Ion1_,I)
     &     - UHEEL*CollisionFreq_IIC(Ion3_,Ion4_,I)
     &     -State_GV(I,uHe_)*(
     &       CollisionFreq_IIC(Ion3_,Neutral1_,I)
     &     + CollisionFreq_IIC(Ion3_,Neutral2_,I)
     &     + CollisionFreq_IIC(Ion3_,Neutral3_,I)
     &     + CollisionFreq_IIC(Ion3_,Neutral4_,I)
     &     + CollisionFreq_IIC(Ion3_,Neutral5_,I)))

CALEX UHLEL is not defined anywhere in this program!!! based on
CALEX UOXEL I assume it is the relative velocity between helium
CALEX and electrionsand so I define it as such below
      UHLEL=UHEEL
      

CALEX     $UHDEL,CFELHD(I),State_GV(I,uE_),CFELN2(I),CFELO2(I),CFELO(I),
CALEX     $CFELHE(I),CFELH(I)',
CALEX     $ State_GV(I,RhoE_),UOXEL,CFELOX(I)
     

      Source_CV(I,uE_)=State_GV(I,RhoE_)*(
     &       UOXEL*CollisionFreq_IIC(Ion4_,Ion1_,I)
     &     + UHLEL*CollisionFreq_IIC(Ion4_,Ion3_,I)
     &     + UHDEL*CollisionFreq_IIC(Ion4_,Ion2_,I)
     &     -State_GV(I,uE_)*(
     &       CollisionFreq_IIC(Ion4_,Neutral1_,I)
     &     + CollisionFreq_IIC(Ion4_,Neutral2_,I)
     &     + CollisionFreq_IIC(Ion4_,Neutral3_,I)
     &     + CollisionFreq_IIC(Ion4_,Neutral4_,I)
     &     + CollisionFreq_IIC(Ion4_,Neutral5_,I)))

C
CALEX calculate square of velocity differences for use in the
CALEX energy collision term
      dU2_II(Ion2_,Ion1_)=UHDOX*UHDOX
      dU2_II(Ion1_,Ion2_)=dU2_II(Ion2_,Ion1_)

      dU2_II(Ion2_,Ion3_)=UHDHL*UHDHL
      dU2_II(Ion3_,Ion2_)=dU2_II(Ion2_,Ion3_)
      
      dU2_II(Ion2_,Ion4_)=UHDEL*UHDEL
      dU2_II(Ion4_,Ion2_)=dU2_II(Ion2_,Ion4_)
      
      dU2_II(Ion3_,Ion1_)=UHEOX*UHEOX
      dU2_II(Ion1_,Ion3_)=dU2_II(Ion3_,Ion1_)

      dU2_II(Ion3_,Ion4_)=UHEEL*UHEEL
      dU2_II(Ion4_,Ion3_)=dU2_II(Ion3_,Ion4_)

      dU2_II(Ion1_,Ion4_)=UOXEL*UOXEL
      dU2_II(Ion4_,Ion1_)=dU2_II(Ion1_,Ion4_)
      
      dU2_II(Ion1_,Neutral1_:Neutral5_)=State_GV(I,uO_)**2
      dU2_II(Ion2_,Neutral1_:Neutral5_)=State_GV(I,uH_)**2
      dU2_II(Ion3_,Neutral1_:Neutral5_)=State_GV(I,uHe_)**2
      dU2_II(Ion4_,Neutral1_:Neutral5_)=State_GV(I,uE_)**2
      

CALEX these are temperature differences needed in order to calculate
CALEX the energy collision term 
      dT_II(Ion2_,Ion1_)=State_GV(I,Th_)-State_GV(I,To_)
      dT_II(Ion2_,Ion3_)=State_GV(I,Th_)-State_GV(I,The_)
      dT_II(Ion2_,Ion4_)=State_GV(I,Th_)-State_GV(I,Te_)
      dT_II(Ion2_,Neutral1_:Neutral5_)=State_GV(I,Th_)-XTN(I)
      
      dT_II(Ion1_,Ion2_)=State_GV(I,To_)-State_GV(I,Th_)
      dT_II(Ion1_,Ion3_)=State_GV(I,To_)-State_GV(I,The_)
      dT_II(Ion1_,Ion4_)=State_GV(I,To_)-State_GV(I,Te_)
      dT_II(Ion1_,Neutral1_:Neutral5_)=State_GV(I,To_)-XTN(I)

      dT_II(Ion3_,Ion2_)=State_GV(I,The_)-State_GV(I,Th_)
      dT_II(Ion3_,Ion1_)=State_GV(I,The_)-State_GV(I,To_)
      dT_II(Ion3_,Ion4_)=State_GV(I,The_)-State_GV(I,Te_)
      dT_II(Ion3_,Neutral1_:Neutral5_)=State_GV(I,The_)-XTN(I)

      dT_II(Ion4_,Ion2_)=State_GV(I,Te_)-State_GV(I,Th_)
      dT_II(Ion4_,Ion1_)=State_GV(I,Te_)-State_GV(I,To_)
      dT_II(Ion4_,Ion3_)=State_GV(I,Te_)-State_GV(I,The_)
      dT_II(Ion4_,Neutral1_:Neutral5_)=State_GV(I,Te_)-XTN(I)


CALEX These are the energy collision terms as seen in eq 4.86 in Nagy

      Source_CV(I,pO_) = 0.0
      Source_CV(I,pH_) = 0.0
      Source_CV(I,pHe_) = 0.0
      Source_CV(I,pE_) = 0.0
      do jSpecies=1,nSpecies
         if(Ion1_ /= jSpecies) Source_CV(I,pO_) = Source_CV(I,pO_) - dT_II(Ion1_,jSpecies)
     &  *HeatFlowCoef_II(Ion1_,jSpecies)*CollisionFreq_IIC(Ion1_,jSpecies,I)
     & + dU2_II(Ion1_,jSpecies)
     &  *FricHeatCoef_II(Ion1_,jSpecies)*CollisionFreq_IIC(Ion1_,jSpecies,I)
      enddo
      Source_CV(I,pO_) =State_GV(I,RhoO_)*Source_CV(I,pO_)

      do jSpecies=1,nSpecies
         if(Ion2_ /= jSpecies) Source_CV(I,pH_) = Source_CV(I,pH_) - dT_II(Ion2_,jSpecies)
     &  *HeatFlowCoef_II(Ion2_,jSpecies)*CollisionFreq_IIC(Ion2_,jSpecies,I)
     & + dU2_II(Ion2_,jSpecies)
     &  *FricHeatCoef_II(Ion2_,jSpecies)*CollisionFreq_IIC(Ion2_,jSpecies,I)
      enddo
      Source_CV(I,pH_) =State_GV(I,RhoH_)*Source_CV(I,pH_)

      do jSpecies=1,nSpecies
         if(Ion3_ /= jSpecies) Source_CV(I,pHe_) = Source_CV(I,pHe_) - dT_II(Ion3_,jSpecies)
     &  *HeatFlowCoef_II(Ion3_,jSpecies)*CollisionFreq_IIC(Ion3_,jSpecies,I)
     & + dU2_II(Ion3_,jSpecies)
     &  *FricHeatCoef_II(Ion3_,jSpecies)*CollisionFreq_IIC(Ion3_,jSpecies,I)
      enddo
      Source_CV(I,pHe_) =State_GV(I,RhoHe_)*Source_CV(I,pHe_)

      do jSpecies=1,nSpecies
         if(Ion4_ /= jSpecies) Source_CV(I,pE_) = Source_CV(I,pE_) - dT_II(Ion4_,jSpecies)
     &  *HeatFlowCoef_II(Ion4_,jSpecies)*CollisionFreq_IIC(Ion4_,jSpecies,I)
     & + dU2_II(Ion4_,jSpecies)
     &  *FricHeatCoef_II(Ion4_,jSpecies)*CollisionFreq_IIC(Ion4_,jSpecies,I)
      enddo
      Source_CV(I,pE_) =State_GV(I,RhoE_)*Source_CV(I,pE_)

C
CALEX calculate heat conductivities
      HeatCon_GI(I,Ion1_)=HLPO*(State_GV(I,RhoO_)/State_GV(I,RhoE_))*State_GV(I,To_)**2.5
      HeatCon_GI(I,Ion4_)=HLPE*State_GV(I,Te_)**2.5
      HeatCon_GI(I,Ion2_)=HLPH*(State_GV(I,RhoH_)/State_GV(I,RhoE_))*State_GV(I,Th_)**2.5
      HeatCon_GI(I,Ion2_)=HeatCon_GI(I,Ion2_)/(1.+(0.7692*
     &(CollisionFreq_IIC(Ion2_,Neutral4_,I)
     & + CollisionFreq_IIC(Ion2_,Neutral3_,I) )
     &+ 1.0962*CollisionFreq_IIC(Ion2_,Neutral1_,I) )
     & /CollisionFreq_IIC(Ion2_,Ion1_,I))

      HeatCon_GI(I,Ion3_)=HLPHE*(State_GV(I,RhoHe_)/Mass_I(Ion3_))*State_GV(I,The_)

      HeatCon_GI(I,Ion3_)=HeatCon_GI(I,Ion3_)/(0.99*CollisionFreq_IIC(Ion3_,Neutral4_,I)
     & +0.99*CollisionFreq_IIC(Ion3_,Neutral3_,I)
     & +1.02*CollisionFreq_IIC(Ion3_,Neutral1_,I)
     & +1.48*CollisionFreq_IIC(Ion3_,Neutral5_,I)
     & +2.22*CollisionFreq_IIC(Ion3_,Neutral2_,I)
     & +1.21*CollisionFreq_IIC(Ion3_,Ion1_,I)
     & +2.23*CollisionFreq_IIC(Ion3_,Ion2_,I))      


      enddo
      RETURN
      END
