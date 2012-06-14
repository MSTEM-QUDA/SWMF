module ModTimeStepControl

  implicit none

  SAVE

  private ! except

  ! Public methods
  public:: read_time_step_control_param
  public:: calc_timestep
  public:: set_global_timestep
  public:: control_time_step

  logical, public:: UseTimeStepControl   = .false.
  real,    public:: TimeStepControlInit  = 1.0

  ! Local variables
  integer             :: nVarControl = -1
  integer, allocatable:: iVarControl_I(:)
  real,    allocatable:: VarRatio_I(:)

  real :: &
       RejectStepLevel1   = 0.3, &
       RejectStepLevel2   = 3.0, &
       RejectStepFactor   = 0.50, &
       ReduceStepLevel1   = 0.6, &
       ReduceStepLevel2   = 1.5, &
       ReduceStepFactor   = 0.95, &
       IncreaseStepLevel1 = 0.8, &
       IncreaseStepLevel2 = 1.2, &
       IncreaseStepFactor = 1.05

contains

  !===========================================================================
  subroutine read_time_step_control_param(NameCommand)

    use ModReadParam
    use ModVarIndexes, ONLY: nVar, NameVar_V
    use ModUtilities,  ONLY: lower_case, split_string

    character(len=*), intent(in):: NameCommand

    integer :: iControl, iVar
    character(len=100):: NameVar, NameVarControl
    character(len=20) :: NameVarControl_I(nVar)

    character(len=*), parameter:: NameSub='read_time_step_control_param'
    !------------------------------------------------------------------------
    select case(NameCommand)
    case("#CONTROLTIMESTEP", "#TIMESTEPCONTROL")
       call read_var('UseTimeStepControl', UseTimeStepControl)
    case("#CONTROLINIT")
       call read_var('TimeStepControlInit', TimeStepControlInit)
    case("#CONTROLDECREASE")
       call read_var('RejectStepLevel1' ,  RejectStepLevel1)
       call read_var('ReduceStepLevel1' ,  ReduceStepLevel1)
       call read_var('IncreaseStepLevel1', IncreaseStepLevel1)
    case("#CONTROLINCREASE")
       call read_var('RejectStepLevel2' ,  RejectStepLevel2)
       call read_var('ReduceStepLevel2' ,  ReduceStepLevel2)
       call read_var('IncreaseStepLevel2', IncreaseStepLevel2)
    case("#CONTROLFACTOR")
       call read_var('RejectStepFactor',   RejectStepFactor)
       call read_var('ReduceStepFactor',   ReduceStepFactor)
       call read_var('IncreaseStepFactor', IncreaseStepFactor)
    case("#CONTROLVAR")
       call read_var('NameVarControl', NameVarControl, IsLowerCase=.true.)
       ! Split list of variables and match with NameVar_V
       call split_string(NameVarControl, nVar, NameVarControl_I, nVarControl)
       if(allocated(iVarControl_I)) deallocate(iVarControl_I, VarRatio_I)
       allocate( iVarControl_I(nVarControl), VarRatio_I(nVarControl) )
       do iControl=1, nVarControl
          do iVar = 1, nVar
             NameVar = NameVar_V(iVar)
             call lower_case(NameVar)
             if( NameVar == NameVarControl_I(iControl) ) EXIT
          end do
          if(iVar > nVar)call stop_mpi(NameSub//' invalid NameVarControl='//&
               NameVarControl)
          iVarControl_I(iControl) = iVar
       end do
    case default
       call stop_mpi(NameSub//' invalid NameCommand='//NameCommand)
    end select

  end subroutine read_time_step_control_param

  !===========================================================================

  subroutine calc_timestep(iBlock)

    use ModProcMH
    use ModMain
    use ModAdvance, ONLY : VdtFace_x, VdtFace_y, VdtFace_z, time_BLK, &
         DoFixAxis, rFixAxis, r2FixAxis, State_VGB, &
         UseElectronPressure
    use ModGeometry, ONLY: true_cell, true_BLK, rMin_BLK, TypeGeometry
    use ModGeometry, ONLY: TypeGeometry
    use ModParallel, ONLY: NeiLEast, NeiLBot, NeiLTop, NOBLK
    use ModCoronalHeating, ONLY: UseCoronalHeating, get_block_heating, &
         CoronalHeating_C, UseAlfvenWaveDissipation, WaveDissipation_VC
    use ModRadiativeCooling, ONLY: UseRadCooling, &
         get_radiative_cooling, add_chromosphere_heating
    use ModCalcSource, ONLY: get_tesi_c
    use ModChromosphere, ONLY: DoExtendTransitionRegion, extension_factor, &
         UseChromosphereHeating
    use ModPhysics, ONLY: inv_gm1
    use BATL_lib, ONLY: CellVolume_GB

    integer, intent(in) :: iBlock

    logical :: DoTest, DoTestMe
    integer :: i, j, k, Di, Dk
    real:: Vdt

    ! Variables for time step control due to loss terms
    real :: TeSi_C(nI,nJ,nK)
    real :: Einternal, Source, Dt_loss
    !--------------------------------------------------------------------------

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
       time_BLK(i,j,k,iBlock) = CellVolume_GB(i,j,k,iBlock) / Vdt

    end do; end do; end do


    ! Time step restriction due to point wise loss terms
    ! (only explicit source terms)
    if(UseAlfvenWaveDissipation .or. UseRadCooling)then
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
             if(.not. true_cell(i,j,k,iBlock)) CYCLE

             Dt_loss = 0.5*minval(State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock)&
                  /WaveDissipation_VC(:,i,j,k))
             ! The following prevents the wave energies from becoming negative
             ! due to too large loss terms.
             time_BLK(i,j,k,iBlock) = min(time_BLK(i,j,k,iBlock), Dt_loss)
          end do; end do; end do
       end if

       ! No time step restriction yet if the electron pressure is used
       if(UseRadCooling .and. .not.UseElectronPressure)then
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
       write(*,*)'VdtFace_x(iTest:iTest+1)=', &
            VdtFace_x(Itest:Itest+1,jTest,kTest)
       if(nJ>1) write(*,*)'VdtFace_y(jTest:jTest+1)=', &
            VdtFace_y(Itest,Jtest:jTest+1,kTest)
       if(nK>1) write(*,*)'VdtFace_z(kTest:kTest+1)=', &
            VdtFace_z(Itest,Jtest,kTest:kTest+1)
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

  !============================================================================

  subroutine set_global_timestep(TimeSimulationLimit)

    use ModProcMH
    use ModMain
    use ModAdvance,  ONLY: time_BLK, State_VGB, rho_, Bx_, Bz_, P_, &
         iTypeAdvance_B, ExplBlock_
    use ModAdvance,  ONLY: B0_DGB
    use ModGeometry, ONLY: true_cell, true_BLK, XyzStart_BLK
    use ModImplicit, ONLY: UsePartImplicit                 !^CFG IF IMPLICIT
    use ModPhysics,  ONLY: No2Si_V, Si2No_V, UnitX_, UnitU_, UnitT_, UnitB_, &
         UnitRho_, g
    use ModNumConst
    use ModMpi
    use BATL_lib,    ONLY: Xyz_DGB, CellSize_DB

    real, intent(in) :: TimeSimulationLimit !Simulation time not to be exceeded

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
          ! Implicit blocks are not taken into account for partially implicit
          ! run
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
                     ' s  is controlled by block with PE, iBlock=', &
                     iProc, iBlock
                write(*,*)'The coordinates of (1,1,1) cell center are ',&
                     XyzStart_BLK(:,iBlock)
                write(*,*)'Cell size Dx in normalized and SI units:',&
                     CellSize_DB(x_,iBlock), ', ', &
                     CellSize_DB(x_,iBlock)*No2Si_V(UnitX_),' m'
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
                     Xyz_DGB(:,i,j,k,iBlock)
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

    if(Time_Simulation+Cfl*Dt*No2Si_V(UnitT_)*(1+cTiny) > TimeSimulationLimit)&
         Dt=(1+cTiny)*(TimeSimulationLimit-Time_Simulation)*Si2No_V(UnitT_)/Cfl

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

  !===========================================================================

  subroutine control_time_step

    use ModMain,    ONLY: nBlock, nI, nJ, nK, UnusedBlk, Dt, Cfl, CflOrig, &
         DtFixed, DtFixedOrig, UseDtFixed, Time_Simulation
    use ModAdvance, ONLY: Rho_, p_, &
         State_VGB, StateOld_VCB, Energy_GBI, EnergyOld_CBI, time_BLK
    use ModPhysics, ONLY: No2Si_V, UnitT_
    use ModProcMH,  ONLY: nProc, iComm
    use ModMpi

    integer:: iBlock, i, j, k, iError
    real   :: RelativeChangeMin,  RelativeChangeMax, Tmp, Factor

    logical:: DoTest, DoTestMe
    character(len=*), parameter:: NameSub='control_time_step'
    !-------------------------------------------------------------------------
    call set_oktest(NameSub, DoTest, DoTestMe)

    ! Use density and pressure as control variables by default
    if(nVarControl < 0)then
       nVarControl = 2
       allocate( iVarControl_I(nVarControl), VarRatio_I(nVarControl) )
       iVarControl_I = (/Rho_, p_/)
    end if

    ! Calculate the largest relative drop in the control variables
    RelativeChangeMin = 1e+6
    RelativeChangeMax = 1e-6

    do iBlock = 1, nBlock
       if(UnusedBlk(iBlock)) CYCLE
       do k = 1, nK; do j = 1, nJ; do i = 1, nI
          VarRatio_I = State_VGB(iVarControl_I,i,j,k,iBlock) &
               /    StateOld_VCB(iVarControl_I,i,j,k,iBlock)
          RelativeChangeMin = min(RelativeChangeMin, minval(VarRatio_I))
          RelativeChangeMax = max(RelativeChangeMax, maxval(VarRatio_I))
       end do; end do; end do
    end do

    if(nProc > 1)then
       ! Take minimum and maximum over all the processors
       Tmp = RelativeChangeMin
       call MPI_allreduce(Tmp, RelativeChangeMin, 1, MPI_REAL, MPI_MIN, &
            iComm, iError)
       Tmp = RelativeChangeMax
       call MPI_allreduce(Tmp, RelativeChangeMax, 1, MPI_REAL, MPI_MAX, &
            iComm, iError)
    end if

    ! Figure out time step reduction factor
    if(       RelativeChangeMin < RejectStepLevel1  &
         .or. RelativeChangeMax > RejectStepLevel2 )then
       ! Redo step if change is outside [RejectStepLevel1, RejectStepLevel2]
       Time_Simulation = Time_Simulation - Dt*No2Si_V(UnitT_)
       Dt = 0.0
       ! Do not use previous step in BDF2 scheme
!!! n_prev = -1
       ! Reset the state variable, the energy and set time_BLK variable to 0
       do iBlock = 1, nBlock
          if(UnusedBlk(iBlock)) CYCLE
          State_VGB(:,1:nI,1:nJ,1:nK,iBlock)  = StateOld_VCB(:,:,:,:,iBlock)
          Energy_GBI(1:nI,1:nJ,1:nK,iBlock,:) = EnergyOld_CBI(:,:,:,iBlock,:)
          time_BLK(1:nI,1:nJ,1:nK,iBlock)     = 0.0
       end do
       ! Reduce next time step
       Factor = RejectStepFactor

       !if (RelativeChangeMax > 100.0) then
       !   Factor = 0.1
       !endif

    elseif(   RelativeChangeMin < ReduceStepLevel1 &
         .or. RelativeChangeMax > ReduceStepLevel2 )then
       ! Reduce next time step if change exceeded ReduceStepLevel
       Factor = ReduceStepFactor

    elseif(    RelativeChangeMin > IncreaseStepLevel1  &
         .and. RelativeChangeMax < IncreaseStepLevel2 )then
       ! Increase next time step if change is within IncreaseStepLevel
       Factor = IncreaseStepFactor
    else
       Factor = 1.0
    end if

    if(UseDtFixed)then
       ! Do not exceed DtFixedOrig
       DtFixed = min(DtFixedOrig, DtFixed*Factor)
    else
       ! Do not exceed CflOrig
       Cfl     = min(CflOrig, Cfl*Factor)
    end if

    if(DoTestMe)then
       write(*,*) NameSub,': RelativeChangeMin,Max,Factor=', &
            RelativeChangeMin, RelativeChangeMax, Factor
       if(UseDtFixed)then
          write(*,*) NameSub,': Dt, DtFixed, Cfl=',&
               Dt*No2Si_V(UnitT_), DtFixed*No2Si_V(UnitT_), Cfl
       else
          write(*,*) NameSub,': Dt, Cfl=', Dt*No2Si_V(UnitT_), Cfl
       end if
    end if

  end subroutine control_time_step

end module ModTimeStepControl
