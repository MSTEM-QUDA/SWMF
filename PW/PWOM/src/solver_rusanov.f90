!\
! -----------------------------------------------------------------------------
! Here we update using the rusanov method
! ----------------------------------------------------------------------------
!/

subroutine rusanov_solver(iIon, nCell,&
     Rgas, DtIn,&
     OldState_GV,&
     RhoSource_C, RhoUSource_C, eSource_C, &
     UpdateState_GV)
  
  use ModCommonVariables
  implicit none

  integer, intent(in)      :: iIon,nCell
  real, intent(in)         :: Rgas,DtIn
  real, intent(in)         :: OldState_GV(-1:nCell+2,3)
  real, dimension(nCell), intent(in)  :: RhoSource_C, RhoUSource_C, eSource_C
  real, intent(out)        :: UpdateState_GV(-1:nCell+2,3)

  integer,parameter    :: Rho_=1,U_=2,P_=3,T_=4
  real, allocatable    :: LeftRho_F(:), LeftU_F(:), LeftP_F(:)
  real, allocatable    :: RightRho_F(:), RightU_F(:), RightP_F(:)
  real, allocatable    :: RhoFlux_F(:), RhoUFlux_F(:), eFlux_F(:)
  real, allocatable    :: T_C(:)
  integer :: i
  !---------------------------------------------------------------------------


  if (.not.allocated(LeftRho_F)) then
     allocate(LeftRho_F(nCell+1), LeftU_F(nCell+1), LeftP_F(nCell+1),&
          RightRho_F(nCell+1), RightU_F(nCell+1), RightP_F(nCell+1),&
          RhoFlux_F(nCell+1), RhoUFlux_F(nCell+1), eFlux_F(nCell+1),&
          T_C(nCell))
  endif
  
  T_C(1:nCell)=OldState_GV(1:nCell,3)/Rgas/OldState_GV(1:nCell,1)

  UpdateState_GV=OldState_GV

  ! get the face values
  call calc_facevalues(nCell, OldState_GV(-1:nCell+2,Rho_), LeftRho_F, RightRho_F)

  call calc_facevalues(nCell, OldState_GV(-1:nCell+2,U_), LeftU_F, RightU_F)

  call calc_facevalues(nCell, OldState_GV(-1:nCell+2,P_), LeftP_F, RightP_F)

  !get the rusanov flux
  call rusanov_flux( DtIn,nCell,&
       LeftRho_F, LeftU_F, LeftP_F, &
       RightRho_F, RightU_F, RightP_F, &
       RhoFlux_F, RhoUFlux_F, eFlux_F)

  ! update the cells one timestep 
  call update_state( iIon,nCell,&
       Rgas, DtIn,&
       OldState_GV(1:nCell,Rho_), OldState_GV(1:nCell,U_), &
       OldState_GV(1:nCell,P_), T_C(1:nCell), &
       LeftRho_F, RightRho_F,LeftU_F, RightU_F,LeftP_F, RightP_F, &
       RhoFlux_F, RhoUFlux_F, eFlux_F, &
       RhoSource_C, RhoUSource_C, eSource_C, &
       UpdateState_GV(1:nCell,Rho_), UpdateState_GV(1:nCell,U_), &
       UpdateState_GV(1:nCell,P_), T_C)

      deallocate(LeftRho_F, LeftU_F, LeftP_F,&
          RightRho_F, RightU_F, RightP_F,&
          RhoFlux_F, RhoUFlux_F, eFlux_F,T_C)

end subroutine rusanov_solver

!==============================================================================

subroutine rusanov_flux( DtIn, nCell,&
     LeftRho_F, LeftU_F, LeftP_F, &
     RightRho_F, RightU_F, RightP_F, &
     RhoFlux_F, RhoUFlux_F, eFlux_F)

  use ModCommonVariables
  implicit none

  real, intent(in)   :: DtIn
  integer,intent(in) :: nCell
  real, dimension(nCell+1), intent(in) :: LeftRho_F, LeftU_F, LeftP_F, &
                                          RightRho_F, RightU_F, RightP_F
  real, dimension(nCell+1), intent(out) :: RhoFlux_F, RhoUFlux_F, eFlux_F
  real    :: GammaOverGammaMinus1, InvGammaMinus1, RightE, LeftE, Coeff
  integer :: i
  !----------------------------------------------------------------------------

  InvGammaMinus1       = 1.0/(Gamma - 1.0)
  GammaOverGammaMinus1 = Gamma/(Gamma - 1.0)

  Coeff = 0.47*DRBND/DtIn
!  Coeff = 0.5/dtr1
  
  do i=1,nCell+1
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

subroutine update_state( iIon,nCell,&
     Rgas,DtIn,&
     OldRho_C, OldU_C, OldP_C, OldT_C, &
     LeftRho_F, RightRho_F,LeftU_F, RightU_F,LeftP_F, RightP_F, &
     RhoFlux_F, RhoUFlux_F, eFlux_F, &
     RhoSource_C, RhoUSource_C, eSource_C, &
     NewRho_C, NewU_C, NewP_C, NewT_C)

  use ModCommonVariables
  use ModPWOM, ONLY: IsPointImplicit, IsPointImplicitAll
  implicit none

  integer, intent(in)                   :: iIon,nCell  
  real, intent(in)                      :: Rgas,DtIn 
  real, dimension(nCell), intent(in)  :: OldRho_C, OldU_C, OldP_C, OldT_C
  real, dimension(nCell+1), intent(in):: LeftRho_F, LeftU_F, LeftP_F
  real, dimension(nCell+1), intent(in):: RightRho_F, RightU_F, RightP_F
  real, dimension(nCell+1), intent(in):: RhoFlux_F, RhoUFlux_F, eFlux_F
  real, dimension(nCell), intent(in)  :: RhoSource_C, RhoUSource_C, eSource_C
  real, dimension(nCell), intent(out) :: NewRho_C, NewU_C, NewP_C,NewT_C
  real, allocatable :: NewRhoU(:), NewE(:)
  real :: InvGammaMinus1,SumCollisionFreq,SumHTxCol,SumMFxCol
  real, allocatable :: NewRhoUSource_C(:), ExplicitRhoU_C(:)
  real :: CollisionNeutral1, CollisionNeutral2, &
          CollisionNeutral3,Collisionneutral4
  real :: CollisionCoefT1, CollisionCoefM1, CollisionCoefT2, CollisionCoefM2,&
          CollisionCoefT3, CollisionCoefM3, CollisionCoefT4, CollisionCoefM4
  real :: ModifyESource
  integer :: i,iSpecies,MinSpecies
  !----------------------------------------------------------------------------
  
  if (.not. allocated(NewRhoU)) then
     allocate(NewRhoU(nCell), NewE(nCell),NewRhoUSource_C(nCell), ExplicitRhoU_C(nCell))
  endif
  

  InvGammaMinus1 = 1.0/(Gamma - 1.0)

  do i=1,nCell
 !    ImpliciteSource_C(i)=0.0
     NewRho_C(i) = OldRho_C(i) &
          - DtIn * (Ar23(i)*RhoFlux_F(i+1)-Ar12(i)*RhoFlux_F(i)) &
          / CellVolume_C(i) &
          + DtIn*RhoSource_C(i)
     NewRhoU(i) = OldRho_C(i)*OldU_C(i) &
          - DtIn * (Ar23(i)*RhoUFlux_F(i+1)-Ar12(i)*RhoUFlux_F(i)) &
          / CellVolume_C(i) &
          + DtIn*Darea(i)*OldP_C(i) &
          + DtIn*RhoUSource_C(i)

     NewE(i) = 0.5*OldRho_C(i)*OldU_C(i)**2 + InvGammaMinus1*OldP_C(i) &
          - DtIn * (Ar23(i)*eFlux_F(i+1)-Ar12(i)*eFlux_F(i)) &
          / CellVolume_C(i) &
          + DtIn*eSource_C(i) 
 
     NewU_C(i) = NewRhoU(i)/NewRho_C(i)

     NewP_C(i) = gMin1*(NewE(i) - 0.5 * NewU_C(i)**2 * NewRho_C(i))

     If (IsPointImplicit) then
        !If is ImplictAll = T then treat ions and neutral contributions
        !with point implicit. Else Just treat neutrals with point implicit
        If (IsPointImplicitAll) then
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
             NewRhoU(i)+DtIn*OldU_C(i)*OldRho_C(i)*SumCollisionFreq
        

        NewRhoU(i)= ExplicitRhoU_C(i) / &
             (1+DtIn*SumCollisionFreq)
        
        NewU_C(i) = NewRhoU(i)/NewRho_C(i)

        !When making p implicit we have to take the cf*cm*Ti term out of 
        !esource. Do this by adding ModifyEsource*dt to esource.
        ModifyESource = OldRho_C(i)* &
             SumHTxCol*OldT_C(i)

        NewE(i)   = NewE(i) + DtIn*ModifyESource

        NewP_C(i) = gMin1*(NewE(i) - 0.5 * NewU_C(i)**2 * NewRho_C(i))
        
        NewP_C(i) = NewP_C(i) / (1+DtIn*2.*SumMFxCol)

     endif
     
     
     NewT_C(i)=NewP_C(i)/Rgas/NewRho_C(i)
  end do
  deallocate(NewRhoU, NewE,NewRhoUSource_C, ExplicitRhoU_C)
end subroutine update_state
