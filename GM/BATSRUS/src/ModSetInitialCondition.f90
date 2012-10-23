!This code is a copyright protected software (c) 2002- University of Michigan
subroutine set_ics(iBlock)

  use ModMain
  use ModAdvance
  use ModB0, ONLY: set_b0_cell
  use ModGeometry, ONLY: true_cell, R2_BLK
  use ModIO, ONLY : restart
  use ModPhysics
  use ModUser, ONLY: user_set_ics
  use ModMultiFluid
  use ModEnergy, ONLY: calc_energy_ghost
  use ModConserveFlux, ONLY: init_cons_flux
  use BATL_lib, ONLY: Xyz_DGB

  implicit none

  integer, intent(in) :: iBlock

  real   :: SinSlope, CosSlope, Rot_II(2,2)
  real   :: ShockLeft_V(nVar), ShockRight_V(nVar)
  integer:: i, j, k, iVar

  character(len=*), parameter:: NameSub = 'set_ics'
  logical :: DoTest, DoTestMe
  !----------------------------------------------------------------------------

  if(iProc == ProcTest .and. iBlock == BlkTest)then
     call set_oktest(NameSub, DoTest, DoTestMe)
  else
     DoTest = .false.; DoTestMe = .false.
  end if

  time_BLK(:,:,:,iBlock) = 0.00

  Flux_VX = 0.0
  Flux_VY = 0.0
  Flux_VZ = 0.0

  call init_cons_flux(iBlock)

  if(Unused_B(iBlock))then  
     do iVar=1,nVar
        State_VGB(iVar,:,:,:,iBlock) = DefaultState_V(iVar)
     end do
  else
     !\
     ! If used, initialize solution variables and parameters.
     !/
     if(UseB0)call set_b0_cell(iBlock)

     if(.not.restart)then

        if(UseShockTube)then
           ! Calculate sin and cos from the tangent = ShockSlope
           SinSlope=ShockSlope/sqrt(cOne+ShockSlope**2)
           CosSlope=      cOne/sqrt(cOne+ShockSlope**2)
           ! Set rotational matrix
           Rot_II = reshape( (/CosSlope, SinSlope, -SinSlope, CosSlope/), &
                (/2,2/) )
           ! calculate normalized left and right states
           ShockLeft_V  = ShockLeftState_V /UnitUser_V(1:nVar)
           ShockRight_V = ShockRightState_V/UnitUser_V(1:nVar)

           ! fix the units for the velocities
           do iFluid = 1, nFluid
              call select_fluid
              ShockLeft_V(iUx:iUz)  = ShockLeftState_V(iUx:iUz) *Io2No_V(Ux_)
              ShockRight_V(iUx:iUz) = ShockRightState_V(iUx:iUz)*Io2No_V(Ux_)
           end do

        end if

        ! Loop through all the cells
        do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
           if(.not.true_cell(i,j,k,iBlock))then
              State_VGB(:,i,j,k,iBlock)   = CellState_VI(:,body1_)
              if(UseBody2)then
                 if(R2_BLK(i,j,k,iBlock) < rBody2) &
                      State_VGB(:,i,j,k,iBlock)   = CellState_VI(:,body2_)
              end if
           elseif(.not.UseShockTube)then
              State_VGB(:,i,j,k,iBlock)   = CellState_VI(:,1)
           else
              if( (Xyz_DGB(x_,i,j,k,iBlock)-ShockPosition) &
                   < -ShockSlope*Xyz_DGB(y_,i,j,k,iBlock))then
                 ! Set all variables first
                 State_VGB(:,i,j,k,iBlock)   = ShockLeft_V

                 ! Rotate vector variables
                 do iFluid = 1, nFluid
                    call select_fluid
                    State_VGB(iUx:iUy,i,j,k,iBlock) = &
                         matmul(Rot_II,ShockLeft_V(iUx:iUy))
                 end do
                 if(UseB) State_VGB(Bx_:By_,i,j,k,iBlock) = &
                      matmul(Rot_II,ShockLeft_V(Bx_:By_))
              else
                 ! Set all variables first
                 State_VGB(:,i,j,k,iBlock)   = ShockRight_V
                 ! Set vector variables
                 do iFluid = 1, nFluid
                    call select_fluid
                    State_VGB(iUx:iUy,i,j,k,iBlock) = &
                         matmul(Rot_II,ShockRight_V(iUx:iUy))
                 end do
                 if(UseB) State_VGB(Bx_:By_,i,j,k,iBlock) = &
                      matmul(Rot_II,ShockRight_V(Bx_:By_))
              end if
              ! Convert velocity to momentum
              do iFluid = 1, nFluid
                 call select_fluid
                 State_VGB(iRhoUx:iRhoUz,i,j,k,iBlock) = &
                      State_VGB(iRho,i,j,k,iBlock) * &
                      State_VGB(iUx:iUz,i,j,k,iBlock)
              end do
              if(.not.UseB0)CYCLE
              ! Remove B0 from B (if any)
              State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
                   State_VGB(Bx_:Bz_,i,j,k,iBlock) - B0_DGB(:,i,j,k,iBlock)
           end if

        end do; end do; end do

        if(index(test_string,'ADDROTATIONALVELOCITY') > 0)then
           ! For testing purposes add rotational velocity
           do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
              do iFluid = 1, nFluid
                 call select_fluid
                 State_VGB(iRhoUx,i,j,k,iBlock) = &
                      State_VGB(iRhoUx,i,j,k,iBlock) &
                      + State_VGB(iRho,i,j,k,iBlock) &
                      *OmegaBody*Xyz_DGB(y_,i,j,k,iBlock)
                 State_VGB(iRhoUy,i,j,k,iBlock) = &
                      State_VGB(iRhoUy,i,j,k,iBlock) &
                      - State_VGB(iRho,i,j,k,iBlock) &
                      *OmegaBody*Xyz_DGB(x_,i,j,k,iBlock)
              end do
           end do; end do; end do
        end if

        if(UseConstrainB)call constrain_ics(iBlock)

        if(UseUserICs) call user_set_ics(iBlock)

     end if ! not restart

  end if ! Unused_B
  !\
  ! Compute energy from set values above.
  !/
  call calc_energy_ghost(iBlock)

  if(DoTestMe)write(*,*) &
       NameSub, 'State(test)=',State_VGB(:,iTest,jTest,kTest,BlkTest)

end subroutine set_ics
