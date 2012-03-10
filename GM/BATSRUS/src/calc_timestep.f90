!^CFG COPYRIGHT UM
subroutine calc_timestep
  use ModProcMH
  use ModMain
  use ModAdvance, ONLY : VdtFace_x, VdtFace_y, VdtFace_z, time_BLK, &
       DoFixAxis, rFixAxis, r2FixAxis, State_VGB, Rho_, FluxType, NormB0_CB, &
       UseElectronPressure
  use ModGeometry, ONLY: true_cell, true_BLK, vInv_CB, rMin_BLK, TypeGeometry
  use ModGeometry, ONLY: y_BLK, TypeGeometry
  use ModParallel, ONLY: NeiLEast, NeiLBot, NeiLTop, NOBLK
  use ModCoronalHeating, ONLY: UseCoronalHeating, get_block_heating, &
       CoronalHeating_C, UseAlfvenWaveDissipation, WaveDissipation_VC
  use ModRadiativeCooling, ONLY: UseRadCooling, &
       get_radiative_cooling, add_chromosphere_heating
  use ModChromosphere, ONLY: DoExtendTransitionRegion, extension_factor, &
       UseChromosphereHeating
  use ModPhysics, ONLY: inv_gm1
  implicit none

  logical :: DoTest, DoTestMe
  integer :: i, j, k, Di, Dk, iBlock
  real:: Vdt

  ! Variables for time step control due to loss terms
  real :: TeSi_C(nI,nJ,nK)
  real :: Einternal, Source, Dt_loss
  !--------------------------------------------------------------------------
  iBlock = GlobalBlk

  if(iBlock==BLKtest)then
     call set_oktest('calc_timestep',DoTest,DoTestMe)
  else
     DoTest=.false.; DoTestMe=.false.
  endif

  ! Calculate time step limit based on maximum speeds across 6 faces
  do k=1,nK; do j=1,nJ; do i=1,nI

     Vdt = max(VdtFace_x(i,j,k),VdtFace_x(i+1,j,k))
     if(nJ > 1) Vdt = Vdt + max(VdtFace_y(i,j,k), VdtFace_y(i,j+1,k))
     if(nK > 1) Vdt = Vdt + max(VdtFace_z(i,j,k), VdtFace_z(i,j,k+1))
     time_BLK(i,j,k,iBlock) = 1.0 / (vInv_CB(i,j,k,iBlock)*Vdt)

  end do; end do; end do


  ! Time step restriction due to point wise loss terms
  ! (only explicit source terms)
  if(UseAlfvenWaveDissipation .or. UseRadCooling)then
     if(UseElectronPressure) call stop_mpi( &
          'Radiative cooling time step control for single temperature only')

     if(UseRadCooling .or. (UseChromosphereHeating .and. &
          DoExtendTransitionRegion)) call get_tesi_c(iBlock, TeSi_C)

     if(UseCoronalHeating)then
        call get_block_heating(iBlock)

        if(UseChromosphereHeating .and. DoExtendTransitionRegion)then
           call add_chromosphere_heating(TeSi_C, iBlock)
           do k = 1, nK; do j = 1, nJ; do i = 1, nI
              CoronalHeating_C(i,j,k) = &
                   CoronalHeating_C(i,j,k)/extension_factor(TeSi_C(i,j,k))
           end do; end do; end do
        end if
     end if

     if(UseAlfvenWaveDissipation)then
        do k = 1, nK; do j = 1, nJ; do i = 1, nI
           Dt_loss = 0.5*minval(State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) &
                /WaveDissipation_VC(:,i,j,k))
           ! The following prevents the wave energies from becoming negative
           ! due to too large loss terms.
           time_BLK(i,j,k,iBlock) = min(time_BLK(i,j,k,iBlock), Dt_loss)
        end do; end do; end do
     end if

     if(UseRadCooling)then
        do k = 1, nK; do j = 1, nJ; do i = 1, nI
           call get_radiative_cooling(i, j, k, iBlock, TeSi_C(i,j,k), Source)

           if(UseCoronalHeating) Source = Source + CoronalHeating_C(i,j,k)
        
           ! Only limit for losses
           if(Source >= -1e-30) CYCLE

           Einternal = inv_gm1*State_VGB(p_,i,j,k,iBlock)

           Dt_loss = 0.5*Einternal/abs(Source)
           ! The following prevents the pressure from becoming negative
           ! due to too large loss terms.
           time_BLK(i,j,k,iBlock) = min(time_BLK(i,j,k,iBlock), Dt_loss)
        end do; end do; end do
     end if
  end if
  

  if(DoFixAxis .and. time_accurate)then
     ! Ignore time step constraints from supercell
     if(TypeGeometry == 'cylindrical' .and. NeiLEast(iBlock) == NOBLK)then
        Di = 1; if(r2FixAxis > 0.1) Di = 2
        time_BLK(1:Di, 1:nJ, 1:nK, iBlock) = &
             time_BLK(1:Di, 1:nJ, 1:nK, iBlock) * 10.0
     elseif(rMin_Blk(iBlock) < rFixAxis)then
        Dk = 1; if(rMin_Blk(iBlock) < r2FixAxis) Dk = 2
        if(NeiLTop(iBlock) == NOBLK) &
             time_BLK(1:nI, 1:nJ, nK+1-Dk:nK, iBlock) = &
             time_BLK(1:nI, 1:nJ, nK+1-Dk:nK, iBlock) * 10.0
        if(NeiLBot(iBlock) == NOBLK) &
             time_BLK(1:nI, 1:nJ, 1:Dk, iBlock) = &
             time_BLK(1:nI, 1:nJ, 1:Dk, iBlock) * 10.0
     end if
  end if

  if(DoTestMe)then
     write(*,*)'left  VdtFace_x,y,z=',&
          VdtFace_x(Itest,Jtest,Ktest),&
          VdtFace_y(Itest,Jtest,Ktest),&
          VdtFace_z(Itest,Jtest,Ktest)
     write(*,*)'right VdtFace_x,y,z=',&
          VdtFace_x(Itest+1,Jtest,Ktest),&
          VdtFace_y(Itest,Jtest+1,Ktest),&
          VdtFace_z(Itest,Jtest,Ktest+1)
     write(*,*)'time_BLK=',time_BLK(Itest,Jtest,Ktest,iBlock)
  end if

  !\
  ! Compute maximum stable time step for this solution block 
  !/
  if(true_BLK(iBlock)) then
     Dt_BLK(iBlock) = minval(time_BLK(:,:,:,iBlock))
  else
     ! If the block has no true cells, set Dt_BLK=1.0E20
     Dt_BLK(iBlock) = min(1e20, &
          minval(time_BLK(:,:,:,iBlock), &
          MASK=true_cell(1:nI,1:nJ,1:nK,iBlock)))
  end if

  if(DoTestMe)write(*,*)'Dt_BLK, loc=',Dt_BLK(iBlock),&
       minloc(time_BLK(:,:,:,iBlock),&
       MASK=true_cell(1:nI,1:nJ,1:nK,iBlock))

  ! Reset time_BLK for fixed time step (but Dt_BLK is kept!)
  if(UseDtFixed) time_BLK(:,:,:,iBlock) = Dt

  ! Set time step to zero inside body.
  if(.not.true_BLK(iBlock)) then
     where (.not.true_cell(1:nI,1:nJ,1:nK,iBlock))&
          time_BLK(:,:,:,iBlock) = 0.0
  end if

end subroutine calc_timestep

!==============================================================================

subroutine set_global_timestep(TimeSimulationLimit)
  use ModProcMH
  use ModMain
  use ModAdvance,  ONLY: time_BLK,State_VGB,rho_,Bx_,By_,Bz_,P_,&
       iTypeAdvance_B, ExplBlock_
  use ModAdvance,  ONLY: B0_DGB
  use ModGeometry, ONLY: true_cell,true_BLK,dx_BLK,XyzStart_BLK
  use ModGeometry, ONLY: x_BLK,y_BLK,z_BLK
  use ModImplicit, ONLY: UsePartImplicit                 !^CFG IF IMPLICIT
  use ModPhysics,  ONLY: No2Si_V,Si2No_V,UnitX_,UnitU_,UnitT_,UnitB_,UnitRho_,g
  use ModNumConst
  use ModMpi
  implicit none

  real, intent(in) :: TimeSimulationLimit ! Simulation time not to be exceeded

  integer :: iBlock
  integer :: iError, Ijk_D(3), i, j, k
  real    :: DtMinPe, Cmax, Cmax_C(nI,nJ,nK)

  logical :: DoTest, DoTestMe
  !--------------------------------------------------------------------------

  call set_oktest('calc_timestep',DoTest,DoTestMe)
  if(DoTestMe)write(*,*)'Starting set_global_timestep'

  if(UseDtFixed)then
     Dt = DtFixed
  else
     !\
     ! Impose global time step for time-accurate calculations as required
     !/
     if(UsePartImplicit)then                          !^CFG IF IMPLICIT BEGIN
        ! Implicit blocks are not taken into account for partially implicit run
        DtMinPE = minval(Dt_BLK(1:nBlock),&
             MASK=iTypeAdvance_B(1:nBlock) == ExplBlock_)
     else                                             !^CFG END IMPLICIT
        DtMinPE = minval(Dt_BLK(1:nBlock), MASK=.not.UnusedBlk(1:nBlock))
     end if                                           !^CFG IF IMPLICIT

     ! Set Dt to minimum time step over all the PE-s
     call MPI_allreduce(DtMinPE, Dt, 1, MPI_REAL, MPI_MIN, iComm, iError)

     if(DoTest .and. DtMinPE==Dt)then
        do iBlock = 1, nBlock
           if(UnusedBlk(iBlock)) CYCLE
           if(Dt_BLK(iBlock)==Dt)then
              write(*,*)'Time step Dt=',Dt,'=', Dt*No2Si_V(UnitT_),&
                   ' s  is comtrolled by block with PE, iBlock=', iProc, iBlock
              write(*,*)'The coordinates of (1,1,1) cell center are ',&
                   XyzStart_BLK(:,iBlock)
              write(*,*)'Cell size Dx in normalized and SI units:',&
                   Dx_BLK(iBlock), ', ', Dx_BLK(iBlock)*No2Si_V(UnitX_),' m'
              do k=1,nK; do j=1,nJ; do i=1,nI
                 Cmax_C(i,j,k) = g*State_VGB(P_,i,j,k,iBlock)
                 if(UseB)CMax_C(i,j,k)=CMax_C(i,j,k)+&
                      sum(State_VGB(Bx_:Bz_,i,j,k,iBlock)**2) 
                 if(UseB0)CMax_C(i,j,k)=CMax_C(i,j,k)+&
                      sum(B0_DGB(Bx_:Bz_,i,j,k,iBlock)**2) 
                 CMax_C(i,j,k)=CMax_C(i,j,k)/&
                     State_VGB(rho_,i,j,k,iBlock)
              end do; end do; end do
              Ijk_D = maxloc(Cmax_C, MASK=true_cell(1:nI,1:nJ,1:nK,iBlock))
              i=Ijk_D(1); j=Ijk_D(2); k=Ijk_D(3)
              Cmax = sqrt(Cmax_C(i,j,k))
              write(*,*)'Maximum perturbation speed =',Cmax*No2Si_V(UnitU_),&
                     ' m/s is reached at X,Y,Z=',&
                     x_BLK(i,j,k,iBlock), &
                     y_BLK(i,j,k,iBlock), &
                     z_BLK(i,j,k,iBlock)
              if(UseB0)write(*,*)'State variables at this point: B0:',&
                     B0_DGB(:,i,j,k,iBlock)*No2Si_V(UnitB_),&
                     ' T'
              if(UseB)write(*,*)'State variables at this point: B1:',&
                     State_VGB(Bx_:Bz_,i,j,k,iBlock)*No2Si_V(UnitB_),&
                     ' T'
              write(*,*)'State variables at this point: Density=',&
                     State_VGB(Rho_,i,j,k,iBlock)*No2Si_V(UnitRho_),&
                     ' kg/m3'
              EXIT
           end if
        end do
     end if

  end if

  ! Limit Dt such that the simulation time cannot exceed TimeSimulationLimit
  ! and infinitesimal timesteps are avoided. Also avoid real overflow when
  ! TimeSimulationLimit = Huge(0.0)

  if(Time_Simulation + Cfl*Dt*No2Si_V(UnitT_)*(1+cTiny) > TimeSimulationLimit)&
       Dt = (1+cTiny)*(TimeSimulationLimit-Time_Simulation)*Si2No_V(UnitT_)/Cfl

  do iBlock = 1, nBlock
     if (UnusedBlk(iBlock)) CYCLE

     time_BLK(:,:,:,iBlock) = Dt

     !\
     ! Reset time step to zero inside body.
     !/
     if(.not.true_BLK(iBlock))then
        where(.not.true_cell(1:nI,1:nJ,1:nK,iBlock)) &
             time_BLK(:,:,:,iBlock) = 0.0
     end if

  end do

  ! Set global time step to the actual time step used
  Dt = Cfl*Dt

  if(DoTestMe)write(*,*)'Finished set_global_timestep with Dt=',Dt

end subroutine set_global_timestep
