
SUBROUTINE PW_print_plot
  use ModCommonVariables
  real MO,MH,MHe,Me
  
  !----------------------------------------------------------------------------

  !write the plot header
  
  write (iUnitGraphics,"(a79)") 'Polarwind output_var11'
  write (iUnitGraphics,"(i8,1pe13.5,3i3)") nint(time/dt),time,1,1,20
  write (iUnitGraphics,"(3i4)") nDim+2
  write (iUnitGraphics,"(100(1pe13.5))") Gamma
  write (iUnitGraphics,"(a79)")&
       'r Lat Lon uO uHe uH ue lgnO lgnHe lgnH lgne TO THe TH Te MO MH MHe Me Ef Pe g'
  
  ! write out lower ghost cell values
  
  QS1=State_GV(0,uO_)/1.E5
  QS3=State_GV(0,uH_)/1.E5
  QS4=State_GV(0,uE_)/1.E5
  QS5=alog10_check(State_GV(0,RhoO_)/Mass_I(Ion1_))

  ! helium not considered at saturn so we need a selector
  if (namePlanet .eq. 'Earth ') then
     QS2=State_GV(0,uHe_)/1.E5
     QS6=alog10_check(State_GV(0,RhoHe_)/Mass_I(Ion3_))
     MHe=State_GV(0,uHe_)/sqrt(gamma*State_GV(0,pHe_)/State_GV(0,RhoHe_))
  endif
  
  if (namePlanet .eq. 'Saturn') then
     QS2=0.0
     QS6=0.
     MHe=0.
  endif

  QS7=alog10_check(State_GV(0,RhoH_)/Mass_I(Ion2_))
  QS8=alog10_check(State_GV(0,RhoE_)/Mass_I(nIon))
  MO=State_GV(0,uO_)/sqrt(gamma*State_GV(0,pO_)/State_GV(0,RhoO_))
  MH=State_GV(0,uH_)/sqrt(gamma*State_GV(0,pH_)/State_GV(0,RhoH_))
  Me=State_GV(0,uE_)/sqrt(gamma*State_GV(0,pE_)/State_GV(0,RhoE_))
                    
  WRITE (iUnitGraphics,"(100(1pe18.10))") &
       AltMin,GmLat, GmLong,QS1,QS2,QS3,QS4,QS5,QS6,QS7,QS8,&
       State_GV(0,To_),State_GV(0,The_),State_GV(0,Th_),State_GV(0,Te_),&
       MO,MH,MHe,Me,Efield(1),State_GV(0,pE_)
    
  ! Write out for the middle of the grid
  
  DO K=1,NDIM
     QS1=State_GV(K,uO_)/1.E5
     QS3=State_GV(K,uH_)/1.E5
     QS4=State_GV(K,uE_)/1.E5
     QS5=alog10_check(State_GV(K,RhoO_)/Mass_I(Ion1_))
     ! helium not considered at saturn so we need a selector
     if (namePlanet .eq. 'Earth ') then
        QS2=State_GV(K,uHe_)/1.E5
        QS6=alog10_check(State_GV(K,RhoHe_)/Mass_I(Ion3_))
        MHe=State_GV(K,uHe_)/sqrt(gamma*State_GV(K,pHe_)/State_GV(K,RhoHe_))
     endif
     
     if (namePlanet .eq. 'Saturn') then
        QS2=0.0
        QS6=0.
        MHe=0.
     endif
     
     QS7=alog10_check(State_GV(K,RhoH_)/Mass_I(Ion2_))
     QS8=alog10_check(State_GV(K,RhoE_)/Mass_I(nIon))
     MO =State_GV(K,uO_)/sqrt(gamma*State_GV(K,pO_)/State_GV(K,RhoO_))
     MH =State_GV(K,uH_)/sqrt(gamma*State_GV(K,pH_)/State_GV(K,RhoH_))
     Me =State_GV(K,uE_)/sqrt(gamma*State_GV(K,pE_)/State_GV(K,RhoE_))
     
     
     WRITE (iUnitGraphics,"(100(1pe18.10))")& 
          ALTD(K),GmLat, GmLong,QS1,QS2,QS3,QS4,QS5,QS6,QS7,QS8,&
          State_GV(K,To_),State_GV(K,The_),State_GV(K,Th_),State_GV(K,Te_),&
          MO,MH,MHe,Me,Efield(k),State_GV(K,pE_)
  enddo
    
  ! Write out the upper ghost cell
  
  QS1=State_GV(nDim+1,uO_)/1.E5
  QS3=State_GV(nDim+1,uH_)/1.E5
  QS4=State_GV(nDim+1,uE_)/1.E5
  QS5=alog10_check(State_GV(nDim+1,RhoO_)/Mass_I(Ion1_))
  ! helium not considered at saturn so we need a selector
  if (namePlanet .eq. 'Earth ') then
     QS2=State_GV(nDim+1,uHe_)/1.E5
     QS6=alog10_check(State_GV(nDim+1,RhoHe_)/Mass_I(Ion3_))
     MHe= & 
          State_GV(nDim+1,uHe_)/sqrt(gamma*State_GV(nDim+1,pHe_)&
          /State_GV(nDim+1,RhoHe_))
  endif
  
  if (namePlanet .eq. 'Saturn') then
     QS2=0.0
     QS6=0.
     MHe=0.
  endif
  
  QS7=alog10_check(State_GV(nDim+1,RhoH_)/Mass_I(Ion2_))
  QS8=alog10_check(State_GV(nDim+1,RhoE_)/Mass_I(nIon))
  MO=State_GV(nDim+1,uO_)/sqrt(gamma*State_GV(nDim+1,pO_)/State_GV(nDim+1,RhoO_))
  MH=State_GV(nDim+1,uH_)/sqrt(gamma*State_GV(nDim+1,pH_)/State_GV(nDim+1,RhoH_))
  Me=State_GV(nDim+1,uE_)/sqrt(gamma*State_GV(nDim+1,pE_)/State_GV(nDim+1,RhoE_))
    
  WRITE (iUnitGraphics,"(100(1pe18.10))")& 
       AltMax,GmLat, GmLong, QS1,QS2,QS3,QS4,QS5,QS6,QS7,QS8,&
       State_GV(nDim+1,To_),State_GV(nDim+1,The_),State_GV(nDim+1,Th_),&
       State_GV(nDim+1,Te_), MO,MH,MHe,Me,Efield(nDim),State_GV(nDim+1,pE_)
    
  RETURN
END SUBROUTINE PW_print_plot

!========================================================================
real function alog10_check(x)

  implicit none
  real, intent(in) :: x

 !---------------------------------------------------------------------- 

  if(x < 0.0) then
     write(*,*)'negative argument for alog10_check:',x
     call CON_stop('PWOM ERROR: negative argument for alog10')
  endif
  alog10_check=alog10(x)
  
end function alog10_check


