!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!This code is a copyright protected software (c) 2002- University of Michigan
!==============================================================================
module ModUser
  use ModSize,      ONLY: x_, y_, z_
  use ModUserEmpty,                                     &
       IMPLEMENTED2 => user_init_session,               &
       IMPLEMENTED3 => user_set_ics,                    &
       IMPLEMENTED4 => user_initial_perturbation,       &
       IMPLEMENTED5 => user_set_face_boundary,                   &
       IMPLEMENTED6 => user_get_log_var,                &
       IMPLEMENTED7 => user_get_b0,                     &
       IMPLEMENTED8 => user_update_states

  include 'user_module.h' !list of public methods

  real, parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: &
       NameUserModule = 'EMPIRICAL SC - Cohen, Sokolov'

contains

  !============================================================================

  subroutine user_init_session
    use EEE_ModMain,    ONLY: EEE_initialize
    use ModIO,          ONLY: write_prefix, iUnitOut
    use ModPhysics,     ONLY: BodyNDim_I,BodyTDim_I,Gamma
    use ModProcMH,      ONLY: iProc
    !--------------------------------------------------------------------------
    if(iProc == 0)then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session:'
       call write_prefix; write(iUnitOut,*) ''
    end if

    call EEE_initialize(BodyNDim_I(1),BodyTDim_I(1),Gamma)

    if(iProc == 0)then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session finished'
       call write_prefix; write(iUnitOut,*) ''
    end if

  end subroutine user_init_session

  !============================================================================
  subroutine user_set_face_boundary(VarsGhostFace_V)
    use EEE_ModMain,   ONLY: EEE_get_state_BC
    use ModSize,       ONLY: MaxDim
    use ModMain,       ONLY:x_,y_,z_, UseRotatingFrame, &
         n_step, Iteration_Number,body2_
    use ModVarIndexes, ONLY: nVar,Ew_,rho_,Ux_,Uy_,Uz_,Bx_,Bz_,P_
    use ModPhysics,    ONLY: InvGammaMinus1,OmegaBody,Si2No_V, &
         UnitB_,UnitU_,UnitRho_,UnitP_, No2Si_V, UnitX_, &
         UseBody2Orbit, xBody2, yBody2, OrbitPeriod, FaceState_VI
    use ModNumConst,   ONLY:cTwoPi, cZero
    use ModFaceBoundary, ONLY: FaceCoords_D, VarsTrueFace_V, TimeBc, &
         iFace, jFace, kFace, iSide, iBlockBc,iBoundary

    real, intent(out):: VarsGhostFace_V(nVar)

    integer:: iCell,jCell,kCell

    real:: DensCell,PresCell,GammaCell,TBase,B1dotR  
    real, dimension(3):: RFace_D,B1_D,U_D,B1t_D,B1n_D

    real :: RhoCME,UCME_D(MaxDim),BCME_D(MaxDim),pCME
    real :: BCMEn,BCMEn_D(MaxDim),UCMEn,UCMEn_D(MaxDim),UCMEt_D(MaxDim)
    !--------------------------------------------------------------------------

    RFace_D  = FaceCoords_D/sqrt(sum(FaceCoords_D**2))

    U_D (x_:z_)  = VarsTrueFace_V(Ux_:Uz_)
    B1_D(x_:z_)  = VarsTrueFace_V(Bx_:Bz_)
    B1dotR       = dot_product(RFace_D,B1_D)
    B1n_D(x_:z_) = B1dotR*RFace_D(x_:z_)
    B1t_D        = B1_D-B1n_D

    VarsGhostFace_V(:) = 1.0e-31
    !\
    ! Update BCs for velocity and induction field::
    !/
    VarsGhostFace_V(Ux_:Uz_) = -U_D(x_:z_)
    VarsGhostFace_V(Bx_:Bz_) = B1t_D(x_:z_)!-B1n_D(x_:z_)

    ! BCs for second body in SC
    if (iBoundary == body2_) then
       VarsGhostFace_V(Rho_)=FaceState_VI(Rho_, body2_)
       VarsGhostFace_V(P_)=FaceState_VI(P_, body2_)
       ! If use orbital motion
       if(UseBody2Orbit) then
          VarsGhostFace_V(Ux_) = &
               -(cTwoPi*yBody2/OrbitPeriod)*No2Si_V(UnitX_)*Si2No_V(UnitU_) 
          VarsGhostFace_V(Uy_) = &
               (cTwoPi*xBody2/OrbitPeriod)*No2Si_V(UnitX_)*Si2No_V(UnitU_)
          VarsGhostFace_V(Uz_) =  0.0
       end if
       RETURN
    end if

    !\
    ! Compute the perturbed state of the eruptive event at RFace_D::
    !/
    call EEE_get_state_BC(RFace_D,RhoCME,UCME_D,BCME_D,pCME,TimeBc, &
         n_step,iteration_number)

    RhoCME = RhoCME*Si2No_V(UnitRho_)
    UCME_D = UCME_D*Si2No_V(UnitU_)
    BCME_D = BCME_D*Si2No_V(UnitB_)
    pCME = pCME*Si2No_V(UnitP_)

    !\
    ! Fix the normal component of the CME field to BCMEn_D at the Sun::
    !/
    BCMEn   = dot_product(RFace_D,BCME_D)
    BCMEn_D = BCMEn*RFace_D
    VarsGhostFace_V(Bx_:Bz_) = VarsGhostFace_V(Bx_:Bz_) + BCMEn_D

    !\
    ! Fix the tangential components of the CME velocity at the Sun
    !/
    UCMEn   = dot_product(RFace_D,UCME_D)
    UCMEn_D = UCMEn*RFace_D
    UCMEt_D = UCME_D-UCMEn_D   
    VarsGhostFace_V(Ux_:Uz_) = VarsGhostFace_V(Ux_:Uz_) + 2.0*UCMEt_D

    !\
    ! Update BCs for the mass density, EnergyRL,
    ! and pressure::
    !/
    iCell = iFace; jCell = jFace; kCell = kFace
    select case(iSide)
    case(1)
       iCell  = iFace
    case(2)
       iCell  = iFace-1
    case(3)
       jCell  = jFace
    case(4)
       jCell  = jFace-1
    case(5)
       kCell  = kFace
    case(6)
       kCell  = kFace-1
    case default
       write(*,*)'ERROR: iSide = ',iSide
       call stop_mpi('incorrect iSide value in user_set_face_boundary')
    end select

    call get_plasma_parameters_cell(iCell,jCell,kCell,iBlockBc,&
         DensCell,PresCell,GammaCell)
    VarsGhostFace_V(Rho_) = &
         max(-VarsTrueFace_V(Rho_) + 2.0*(DensCell+RhoCME), &
         VarsTrueFace_V(Rho_))
    TBase = (PresCell+pCME)/(DensCell+RhoCME)
    VarsGhostFace_V(P_) = &
         max(VarsGhostFace_V(Rho_)*TBase, &
         VarsTrueFace_V(P_))
    VarsGhostFace_V(Ew_) = &!max(-VarsTrueFace_V(Ew_)+ &
         VarsGhostFace_V(Rho_)*TBase &
         *(1.0/(GammaCell-1.0)-InvGammaMinus1)

    !\
    ! Apply corotation
    !/
    if (.not.UseRotatingFrame) then
       VarsGhostFace_V(Ux_) = VarsGhostFace_V(Ux_) &
            - 2*OmegaBody*FaceCoords_D(y_)
       VarsGhostFace_V(Uy_) = VarsGhostFace_V(Uy_) &
            + 2*OmegaBody*FaceCoords_D(x_)
    end if
  end subroutine user_set_face_boundary

  !============================================================================

  subroutine get_plasma_parameters_cell(iCell,jCell,kCell,iBlock,&
       DensCell,PresCell,GammaCell)

    ! This subroutine computes the cell values for density and pressure 
    ! assuming an isothermal atmosphere
    
    use ModGeometry,   ONLY: Xyz_DGB,R_BLK
    use ModNumConst
    use ModPhysics,    ONLY: GBody,BodyRho_I,Si2No_V,UnitTemperature_
    use ModExpansionFactors,  ONLY: UMin,CoronalT0Dim
    use BATL_lib,      ONLY: Xyz_DGB

    integer, intent(in)  :: iCell,jCell,kCell,iBlock
    real, intent(out)    :: DensCell,PresCell,GammaCell
    real :: UFinal       !The solar wind speed at the far end of the 
                         !Parker spiral, which originates from the given cell
    real :: URatio       !The coronal based values for temperature density 
                         !are scaled as functions of UFinal/UMin ratio
    real :: Temperature
    !--------------------------------------------------------------------------

    call get_gamma_emp( &
         Xyz_DGB(x_,iCell,jCell,kCell,iBlock), &
         Xyz_DGB(y_,iCell,jCell,kCell,iBlock), &
         Xyz_DGB(z_,iCell,jCell,kCell,iBlock), &
         GammaCell)
    call get_bernoulli_integral(Xyz_DGB(:,iCell,jCell,kCell,iBlock) &
         /r_BLK(iCell,jCell,kCell,iBlock), UFinal)
    URatio = UFinal/UMin

    ! In coronal holes the temperature is reduced 
    Temperature = CoronalT0Dim*Si2No_V(UnitTemperature_) / (min(URatio,2.0))

    DensCell  = ((1.0/URatio)**2) &          !This is the density variation
         *BodyRho_I(1)*exp(-GBody/Temperature &
         *(1.0/max(R_BLK(iCell,jCell,kCell,iBlock),0.90)-1.0))

    PresCell = DensCell*Temperature

  end subroutine get_plasma_parameters_cell

  !============================================================================

  subroutine user_initial_perturbation
    use EEE_ModMain,  ONLY: EEE_get_state_init
    use ModMain, ONLY: nI,nJ,nK,nBLK,Unused_B,x_,y_,z_,n_step,iteration_number
    use ModVarIndexes
    use ModAdvance,   ONLY: State_VGB 
    use ModPhysics,   ONLY: Si2No_V,UnitRho_,UnitP_,UnitB_
    use ModGeometry
    use ModEnergy,    ONLY: calc_energy_cell
    use BATL_lib, ONLY: CellVolume_GB

    integer :: i,j,k,iBLK
    logical :: oktest,oktest_me
    real :: x_D(MaxDim),Rho,B_D(MaxDim),p

    real :: Mass=0.0
    !--------------------------------------------------------------------------
    call set_oktest('user_initial_perturbation',oktest,oktest_me)

    do iBLK=1,nBLK
       if(Unused_B(iBLK))CYCLE
       do k=1,nK; do j=1,nJ; do i=1,nI

          x_D(x_) = Xyz_DGB(x_,i,j,k,iBLK)
          x_D(y_) = Xyz_DGB(y_,i,j,k,iBLK)
          x_D(z_) = Xyz_DGB(z_,i,j,k,iBLK)

          call EEE_get_state_init(x_D,Rho,B_D,p, &
               n_step,iteration_number)

          Rho = Rho*Si2No_V(UnitRho_)
          B_D = B_D*Si2No_V(UnitB_)
          p = p*Si2No_V(UnitP_)

          !\
          ! Add the eruptive event state to the solar wind
          !/
          State_VGB(Rho_,i,j,k,iBLK) = State_VGB(Rho_,i,j,k,iBLK) + Rho
          State_VGB(Bx_:Bz_,i,j,k,iBLK) = State_VGB(Bx_:Bz_,i,j,k,iBLK) + B_D
          State_VGB(P_,i,j,k,iBLK) = State_VGB(P_,i,j,k,iBLK) + p

          !\
          ! Calculate the mass added to the eruptive event
          !/
          Mass = Mass + Rho*CellVolume_GB(i,j,k,iBLK)
       end do; end do; end do

       !\
       ! Update the total energy::
       !/
       call calc_energy_cell(iBLK)

    end do

  end subroutine user_initial_perturbation

  !============================================================================

  subroutine user_set_ics(iBlock)

    use ModMain,      ONLY: nI,nJ,nK
    use ModVarIndexes
    use ModAdvance,   ONLY: State_VGB 
    use ModPhysics,   ONLY: InvGammaMinus1,BodyTDim_I
    use ModGeometry
    use ModNumConst,  ONLY: cTolerance
    use BATL_lib, ONLY: IsCartesianGrid, CoordMax_D

    integer, intent(in) :: iBlock

    integer :: i,j,k
    logical :: oktest,oktest_me
    real :: Dens_BLK,Pres_BLK,Gamma_BLK
    real :: x,y,z,R,ROne,Rmax,U0
    !--------------------------------------------------------------------------
    call set_oktest('user_set_ics',oktest,oktest_me)

    if(IsCartesianGrid)then
       Rmax = max(21.0, sqrt(sum(CoordMax_D**2)))
    else
       Rmax = max(21.0, RadiusMax)
    end if

    ! The sqrt is for backward compatibility with older versions of the Sc
    U0 = 4.0*sqrt(2.0E+6/BodyTDim_I(1))

    State_VGB(:,1:nI,1:nJ,1:nK,iBlock) = 1.0e-31
    do k=1,nK; do j=1,nJ; do i=1,nI

       x = Xyz_DGB(x_,i,j,k,iBlock)
       y = Xyz_DGB(y_,i,j,k,iBlock)
       z = Xyz_DGB(z_,i,j,k,iBlock)
       R = max(R_BLK(i,j,k,iBlock),cTolerance)
       ROne = max(1.0,R)
       State_VGB(Bx_:Bz_,i,j,k,iBlock) = 0.0
       call get_plasma_parameters_cell(i,j,k,iBlock,&
            Dens_BLK,Pres_BLK,Gamma_BLK)
       State_VGB(rho_,i,j,k,iBlock) = Dens_BLK
       State_VGB(P_,i,j,k,iBlock)   = Pres_BLK
       State_VGB(RhoUx_,i,j,k,iBlock) = Dens_BLK &
            *U0*((ROne-1.0)/(Rmax-1.0))*x/R
       State_VGB(RhoUy_,i,j,k,iBlock) = Dens_BLK &
            *U0*((ROne-1.0)/(Rmax-1.0))*y/R
       State_VGB(RhoUz_,i,j,k,iBlock) = Dens_BLK &
            *U0*((ROne-1.0)/(Rmax-1.0))*z/R
       State_VGB(Ew_,i,j,k,iBlock) = Pres_BLK &
            *(1.0/(Gamma_BLK-1.0)-InvGammaMinus1) 
    end do; end do; end do

  end subroutine user_set_ics

  !============================================================================
  subroutine user_get_b0(xInput,yInput,zInput,B0_D)

    use EEE_ModMain,    ONLY: EEE_get_B0
    use ModPhysics,     ONLY:Si2No_V,UnitB_
    use ModMagnetogram, ONLY: get_magnetogram_field

    real, intent(in):: xInput,yInput,zInput
    real, intent(out), dimension(3):: B0_D

    real :: x_D(3),B_D(3)
    !--------------------------------------------------------------------------

    call get_magnetogram_field(xInput,yInput,zInput,B0_D)
    B0_D = B0_D*Si2No_V(UnitB_)

    x_D = (/ xInput, yInput, zInput /)
    call EEE_get_B0(x_D,B_D)
    B0_D = B0_D + B_D*Si2No_V(UnitB_)

  end subroutine user_get_b0

  !============================================================================

  subroutine user_update_states(iBlock)

    use ModVarIndexes
    use ModSize
    use ModAdvance, ONLY: State_VGB
    use ModB0,      ONLY: B0_DGB
    use ModPhysics, ONLY: InvGammaMinus1
    use ModGeometry,ONLY: R_BLK
    use ModEnergy,  ONLY: calc_energy_cell
    use ModExpansionFactors, ONLY: gammaSS,Rs_PFSSM

    integer,intent(in):: iBlock
    integer:: i,j,k
    real:: DensCell,PresCell,GammaCell
    !------------------------------------------------------------------------
    call update_states_MHD(iBlock)

    ! Update pressure and relaxation energy

    do k = 1, nK; do j = 1, nJ; do i = 1, nI
       call get_plasma_parameters_cell(i,j,k,iBlock,&
            DensCell,PresCell,GammaCell)
       if(R_BLK(i,j,k,iBlock)>Rs_PFSSM)&
            GammaCell=GammaCell-(GammaCell-gammaSS)*max(0.0, &
            -1.0 + 2*State_VGB(P_,i,j,k,iBlock)/&
            (State_VGB(P_   ,i,j,k,iBlock)+sum(&
            (State_VGB(Bx_:Bz_ ,i,j,k,iBlock)+B0_DGB(:,i,j,k,iBlock))**2)&
            *0.25*(R_BLK(i,j,k,iBlock)/Rs_PFSSM)**1.50))
       State_VGB(P_   ,i,j,k,iBlock)=(GammaCell-1.0)*      &
            (InvGammaMinus1*State_VGB(P_,i,j,k,iBlock) + State_VGB(Ew_,i,j,k,iBlock))
       State_VGB(Ew_,i,j,k,iBlock)= State_VGB(P_,i,j,k,iBlock) &
            *(1.0/(GammaCell-1.0)-InvGammaMinus1)
    end do; end do; end do

    call calc_energy_cell(iBlock)

  end subroutine user_update_states

  !========================================================================
  subroutine user_get_log_var(VarValue,TypeVar,Radius)

    use ModIO,         ONLY: write_myname
    use ModMain,       ONLY: Unused_B,nBLK,x_,y_,z_
    use ModVarIndexes, ONLY: Ew_,Bx_,By_,Bz_,rho_,rhoUx_,rhoUy_,rhoUz_,P_ 
    use ModGeometry,   ONLY: R_BLK
    use ModAdvance,    ONLY: State_VGB,tmp1_BLK
    use ModB0,         ONLY: B0_DGB
    use ModPhysics,    ONLY: InvGammaMinus1,&
         No2Si_V,UnitEnergydens_,UnitX_,UnitRho_

    real, intent(out):: VarValue
    character (LEN=10), intent(in):: TypeVar 
    real, intent(in), optional :: Radius

    integer:: iBLK
    real:: unit_energy,unit_mass
    real, external:: integrate_BLK
    !--------------------------------------------------------------------------
    unit_energy = 1.0e7*No2Si_V(UnitEnergydens_)*No2Si_V(UnitX_)**3
    unit_mass   = 1.0e3*No2Si_V(UnitRho_)*No2Si_V(UnitX_)**3
    !\
    ! Define log variable to be saved::
    !/
    select case(TypeVar)
    case('em_t','Em_t','em_r','Em_r')
       do iBLK=1,nBLK
          if (Unused_B(iBLK)) CYCLE
          tmp1_BLK(:,:,:,iBLK) = & 
               (B0_DGB(x_,:,:,:,iBLK)+State_VGB(Bx_,:,:,:,iBLK))**2+&
               (B0_DGB(y_,:,:,:,iBLK)+State_VGB(By_,:,:,:,iBLK))**2+&
               (B0_DGB(z_,:,:,:,iBLK)+State_VGB(Bz_,:,:,:,iBLK))**2
       end do
       VarValue = unit_energy*0.5*integrate_BLK(1,tmp1_BLK)
    case('ek_t','Ek_t','ek_r','Ek_r')
       do iBLK=1,nBLK
          if (Unused_B(iBLK)) CYCLE
          tmp1_BLK(:,:,:,iBLK) = &
               (State_VGB(rhoUx_,:,:,:,iBLK)**2 +&
               State_VGB(rhoUy_,:,:,:,iBLK)**2 +&
               State_VGB(rhoUz_,:,:,:,iBLK)**2)/&
               State_VGB(rho_  ,:,:,:,iBLK)             
       end do
       VarValue = unit_energy*0.5*integrate_BLK(1,tmp1_BLK)
    case('et_t','Et_t','et_r','Et_r')
       do iBLK=1,nBLK
          if (Unused_B(iBLK)) CYCLE
          tmp1_BLK(:,:,:,iBLK) = State_VGB(P_,:,:,:,iBLK)
       end do
       VarValue = unit_energy*InvGammaMinus1*integrate_BLK(1,tmp1_BLK)
    case('ew_t','Ew_t','ew_r','Ew_r')
       do iBLK=1,nBLK
          if (Unused_B(iBLK)) CYCLE
          tmp1_BLK(:,:,:,iBLK) = State_VGB(Ew_,:,:,:,iBLK)
       end do
       VarValue = unit_energy*integrate_BLK(1,tmp1_BLK)
    case('ms_t','Ms_t')
       do iBLK=1,nBLK
          if (Unused_B(iBLK)) CYCLE
          tmp1_BLK(:,:,:,iBLK) = &
               State_VGB(rho_,:,:,:,iBLK)/R_BLK(:,:,:,iBLK)
       end do
       VarValue = unit_mass*integrate_BLK(1,tmp1_BLK)
    case('vol','Vol')
       tmp1_BLK(:,:,:,iBLK) = 1.0
       VarValue = integrate_BLK(1,tmp1_BLK)
    case default
       VarValue = -7777.
       call write_myname;
       write(*,*) 'Warning in set_user_logvar: unknown logvarname = ',TypeVar
    end select
  end subroutine user_get_log_var
end module ModUser

