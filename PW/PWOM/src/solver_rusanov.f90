!\
! -----------------------------------------------------------------------------
! Here we update using the rusanov method
! ----------------------------------------------------------------------------
!/

subroutine rusanov_solver(iIon, &
     Rgas, &
     OldRho_C, OldU_C, OldP_C, OldT_C, &
     RhoBottom, UBottom, PBottom, &
     RhoTop, UTop, Ptop, &
     RhoTop2, UTop2, Ptop2, &
     RhoSource_C, RhoUSource_C, eSource_C, &
     NewRho_C, NewU_C, NewP_C, NewT_C)
  
  use ModCommonVariables
  implicit none

  integer, intent(in)          :: iIon
  real, intent(in)                      :: Rgas
  real, dimension(MaxGrid), intent(in)  :: OldRho_C, OldU_C, OldP_C, OldT_C
  real, intent(in)                      :: RhoBottom, UBottom, PBottom
  real, intent(in)                      :: RhoTop, UTop, PTop
  real, intent(in)                      :: RhoTop2, UTop2, PTop2
  real, dimension(MaxGrid), intent(in)  :: RhoSource_C, RhoUSource_C, eSource_C
  real, dimension(MaxGrid), intent(out) :: NewRho_C, NewU_C, NewP_C, NewT_C
  
  real, dimension(-1:MaxGrid+2) :: OldRho_G, OldU_G, OldP_G
  real, dimension(MaxGrid+1)    :: LeftRho_F, LeftU_F, LeftP_F
  real, dimension(MaxGrid+1)    :: RightRho_F, RightU_F, RightP_F
  real, dimension(MaxGrid+1)    :: RhoFlux_F, RhoUFlux_F, eFlux_F



  !---------------------------------------------------------------------------







!  write(*,*)'rusanov solver starting for variable ',NameVariable, DoTest,DoTest2,DoTest3
 
  ! add real ghost cells for use in getting face values
  OldRho_G(1:nDim)      = OldRho_C(1:nDim)
  OldRho_G(-1:0)        = RhoBottom
  OldRho_G(nDim+1)      = RhoTop
  OldRho_G(nDim+2)      = RhoTop2

  OldU_G(1:nDim)        = OldU_C(1:nDim)
  OldU_G(-1:0)          = UBottom
  OldU_G(nDim+1)        = UTop
  OldU_G(nDim+2)        = UTop2

  OldP_G(1:nDim)        = OldP_C(1:nDim)
  OldP_G(-1:0)          = PBottom
  OldP_G(nDim+1)        = PTop
  OldP_G(nDim+2)        = PTop2


  ! get the face values
  call calc_facevalues(nDim, OldRho_G, LeftRho_F, RightRho_F)
  call calc_facevalues(nDim, OldU_G, LeftU_F, RightU_F)
  call calc_facevalues(nDim, OldP_G, LeftP_F, RightP_F)

  
  
  !get the rusanov flux
  call rusanov_flux( &
       LeftRho_F, LeftU_F, LeftP_F, &
       RightRho_F, RightU_F, RightP_F, &
       RhoFlux_F, RhoUFlux_F, eFlux_F)




  ! update the cells one timestep 
  call update_state( iIon,&
       Rgas, &
       OldRho_C, OldU_C, OldP_C, OldT_C, &
       LeftRho_F, RightRho_F,LeftU_F, RightU_F,LeftP_F, RightP_F, &
       RhoFlux_F, RhoUFlux_F, eFlux_F, &
       RhoSource_C, RhoUSource_C, eSource_C, &
       NewRho_C, NewU_C, NewP_C, NewT_C)


end subroutine rusanov_solver

!==============================================================================

subroutine rusanov_flux( &
     LeftRho_F, LeftU_F, LeftP_F, &
     RightRho_F, RightU_F, RightP_F, &
     RhoFlux_F, RhoUFlux_F, eFlux_F)

  use ModCommonVariables
  implicit none


  real, dimension(MaxGrid+1), intent(in) :: &
       LeftRho_F, LeftU_F, LeftP_F, &
       RightRho_F, RightU_F, RightP_F
  real, dimension(MaxGrid+1), intent(out) :: RhoFlux_F, RhoUFlux_F, eFlux_F
  real    :: GammaOverGammaMinus1, InvGammaMinus1, RightE, LeftE, Coeff
  integer :: i
  !----------------------------------------------------------------------------
  InvGammaMinus1       = 1.0/(Gamma - 1.0)
  GammaOverGammaMinus1 = Gamma/(Gamma - 1.0)

  Coeff = 0.47/dtr1
!  Coeff = 0.5/dtr1
  
  do i=1,nDim+1
     RhoFlux_F(i)  = 0.5*(LeftRho_F(i) *LeftU_F(i) &
          +               RightRho_F(i)*RightU_F(i))  &
          - Coeff * (RightRho_F(i) - LeftRho_F(i))

     RhoUFlux_F(i) = 0.5*(LeftRho_F(i) *LeftU_F(i)**2  + LeftP_F(i) &
          +               RightRho_F(i)*RightU_F(i)**2 + RightP_F(i))  &
          - Coeff * (RightRho_F(i)*RightU_F(i) - LeftRho_F(i)*LeftU_F(i))

     
     RightE = 0.5*RightRho_F(i)*RightU_F(i)**2 + InvGammaMinus1*RightP_F(i)
     LeftE  = 0.5*LeftRho_F(i)*LeftU_F(i)**2   + InvGammaMinus1*LeftP_F(i)

     eFlux_F(i)    = 0.5*(0.5*LeftRho_F(i) *LeftU_F(i)**3  &
          + GammaOverGammaMinus1*LeftU_F(i)* LeftP_F(i) &
          +               0.5*RightRho_F(i)*RightU_F(i)**3 &
          + GammaOverGammaMinus1*RightU_F(i)*RightP_F(i))  &
          - Coeff * (RightE - LeftE)
  end do

end subroutine rusanov_flux

!==============================================================================

subroutine update_state( iIon,&
     Rgas,&
     OldRho_C, OldU_C, OldP_C, OldT_C, &
     LeftRho_F, RightRho_F,LeftU_F, RightU_F,LeftP_F, RightP_F, &
     RhoFlux_F, RhoUFlux_F, eFlux_F, &
     RhoSource_C, RhoUSource_C, eSource_C, &
     NewRho_C, NewU_C, NewP_C, NewT_C)

  use ModCommonVariables
  implicit none
  integer, intent(in)                   :: iIon  
  real, intent(in)                      :: Rgas 
  real, dimension(MaxGrid), intent(in)  :: OldRho_C, OldU_C, OldP_C, OldT_C
  real, dimension(MaxGrid+1), intent(in):: LeftRho_F, LeftU_F, LeftP_F
  real, dimension(MaxGrid+1), intent(in):: RightRho_F, RightU_F, RightP_F
  real, dimension(MaxGrid+1), intent(in):: RhoFlux_F, RhoUFlux_F, eFlux_F
  real, dimension(MaxGrid), intent(in)  :: RhoSource_C, RhoUSource_C, eSource_C
  real, dimension(MaxGrid), intent(out) :: NewRho_C, NewU_C, NewP_C,NewT_C
  real, dimension(MaxGrid) :: NewRhoU, NewE
  real :: InvGammaMinus1,SumCollisionFreq,SumHTxCol,SumMFxCol
  real, dimension(MaxGrid) :: NewRhoUSource_C, ExplicitRhoU_C
  real :: CollisionNeutral1, CollisionNeutral2, &
          CollisionNeutral3,Collisionneutral4
  real :: CollisionCoefT1, CollisionCoefM1, CollisionCoefT2, CollisionCoefM2,&
          CollisionCoefT3, CollisionCoefM3, CollisionCoefT4, CollisionCoefM4
  real :: ModifyESource
  integer :: i,iSpecies,MinSpecies
  !----------------------------------------------------------------------------
  InvGammaMinus1 = 1.0/(Gamma - 1.0)

  do i=1,nDim
 !    ImpliciteSource_C(i)=0.0
     NewRho_C(i) = OldRho_C(i) &
          - Dt * (Ar23(i)*RhoFlux_F(i+1)-Ar12(i)*RhoFlux_F(i)) &
          / CellVolume_C(i) &
          + Dt*RhoSource_C(i)
     NewRhoU(i) = OldRho_C(i)*OldU_C(i) &
          - Dt * (Ar23(i)*RhoUFlux_F(i+1)-Ar12(i)*RhoUFlux_F(i)) &
          / CellVolume_C(i) &
          + Dt*Darea(i)*OldP_C(i) &
          + Dt*RhoUSource_C(i)

     NewE(i) = 0.5*OldRho_C(i)*OldU_C(i)**2 + InvGammaMinus1*OldP_C(i) &
          - Dt * (Ar23(i)*eFlux_F(i+1)-Ar12(i)*eFlux_F(i)) &
          / CellVolume_C(i) &
          + Dt*eSource_C(i) 
 
     NewU_C(i) = NewRhoU(i)/NewRho_C(i)

     NewP_C(i) = gMin1*(NewE(i) - 0.5 * NewU_C(i)**2 * NewRho_C(i))

     If (IsImplicit) then
        !If is ImplictAll = T then treat ions and neutral contributions
        !with point implicit. Else Just treat neutrals with point implicit
        If (IsImplicitAll) then
           MinSpecies = 1
        else
           MinSpecies = 5
        endif
        SumCollisionFreq = 0.0
        SumHTxCol        = 0.0
        SumMFxCol        = 0.0
        do iSpecies=MinSpecies,nSpecies
           if (iSpecies /= iIon) then
              SumCollisionFreq = &
                   SumCollisionFreq+CollisionFreq_IIC(iIon,iSpecies,i)
              SumHTxCol        = SumHTxCol &
                   + HeatFlowCoef_II(iIon,iSpecies)*CollisionFreq_IIC(iIon,iSpecies,i)
              SumMFxCol        = SumMFxCol &
                   + MassFracCoef_II(iIon,iSpecies)*CollisionFreq_IIC(iIon,iSpecies,i)
           endif
        enddo
        
        !eliminate contribution of implicit sources in RhoU
        ExplicitRhoU_C(i) = &
             NewRhoU(i)+Dt*OldU_C(i)*OldRho_C(i)*SumCollisionFreq
        

        NewRhoU(i)= ExplicitRhoU_C(i) / &
             (1+Dt*SumCollisionFreq)
        
        NewU_C(i) = NewRhoU(i)/NewRho_C(i)

        !When making p implicit we have to take the cf*cm*Ti term out of 
        !esource. Do this by adding ModifyEsource*dt to esource.
        ModifyESource = OldRho_C(i)* &
             SumHTxCol*OldT_C(i)

        NewE(i)   = NewE(i) + Dt*ModifyESource

        NewP_C(i) = gMin1*(NewE(i) - 0.5 * NewU_C(i)**2 * NewRho_C(i))
        
        NewP_C(i) = NewP_C(i) / (1+Dt*2.*SumMFxCol)

     endif
     
     
     NewT_C(i)=NewP_C(i)/Rgas/NewRho_C(i)
  end do

end subroutine update_state
