! This file contains the top level methods for BATSRUS

subroutine BATS_setup

  use ModMpi
  use ModProcMH
  use ModMain
  use ModCT, ONLY : DoInitConstrainB               !^CFG IF CONSTRAINB
  use ModIO
  use ModAMR, ONLY : &
       initial_refine_levels, nRefineLevelIC, nRefineLevel
  use ModAdvance, ONLY : iTypeAdvance_B, iTypeAdvance_BP, ExplBlock_
  use ModNumConst

  implicit none

  ! Local variables

  character(len=*), parameter :: NameSub = 'BATS_setup'
  integer :: iError 

  !---------------------------------------------------------------------------

  ! Allocate and initialize variables dependent on number of PEs
  call allocate_vars  

  if(.not.IsStandAlone)call write_progress(0)

  call grid_setup   ! Restart reads integer only (no X_BLK or dx_BLK)

  call set_initial_conditions ! Restart reads all real data

  call find_test_cell

  call initialize_files


  call MPI_BARRIER(iComm,iError) ! ----------- BARRIER ------

  call write_runtime_values

  restart = .false.

contains
  !===========================================================================

  subroutine grid_setup

    ! Set up problem geometry, blocks, and grid structure.

    use ModIO, ONLY: restart
    use ModRestartFile, ONLY: NameRestartInDir, &
         UseRestartInSeries, string_append_iter

    use ModMain, ONLY: iteration_number
    use BATL_lib, ONLY: init_grid_batl, read_tree_file,set_amr_criteria,&
         set_amr_geometry, nBlock, Unused_B
    use ModBatlInterface, ONLY: set_batsrus_grid
    use ModAMR, ONLY : AmrCriteria_IB, nAmrCriteria, nCritGeo
    ! Dummy variables, to avoid array size issues with State_VGB in
    ! set_amr_criteria
    use ModAdvance, ONLY : nVar, State_VGB

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = NameSub//'::grid_setup'
    character(len=100) :: NameFile

    integer:: iBlock
    !--------------------------------------------------------------------------

    call set_batsrus_grid

    if (.not.restart) then
       ! Create initial solution block geometry.

       ! Perform initial refinement of mesh and solution blocks.
       do nRefineLevel = 1, initial_refine_levels

          if (iProc == 0.and.lVerbose>0) then
             call write_prefix; write (iUnitOut,*) NameSub, &
                  ' starting initial refinement level, nBlockAll =', &
                  nRefineLevel, nBlockAll
          end if
          if(nCritGeo > 0) then
             AmrCriteria_IB(:,1:nBlockMax) = 0.0
             call amr_criteria(AmrCriteria_IB,'geo')
             call set_amr_criteria(nVar, State_VGB,&
                  nAmrCriteria,AmrCriteria_IB,TypeAmrIn='geo')
          else   
             call set_amr_criteria(nVar,State_VGB,TypeAmrIn='geo')
          end if
          call init_grid_batl
          call set_batsrus_grid
          ! need to update node information, maybe not all
          ! of load balancing
          do iBlock = 1, nBlock
             if(Unused_B(iBlock)) CYCLE
             call set_amr_geometry(iBlock)
          end do
       end do
    else
       ! Read initial solution block geometry from octree restart file.

       NameFile = trim(NameRestartInDir)//'octree.rst'
       if (UseRestartInSeries) call string_append_iter(NameFile,iteration_number)
       call read_tree_file(NameFile)
       call init_grid_batl
       call set_batsrus_grid

    end if

    ! Set initial block types
    where(.not.UnusedBlk) iTypeAdvance_B = ExplBlock_
    call MPI_ALLGATHER(iTypeAdvance_B, MaxBlock, MPI_INTEGER, &
         iTypeAdvance_BP, MaxBlock, MPI_INTEGER, iComm, iError)

    ! Move coordinates around except for restart because the
    ! coordinate info is in the .rst files and not in the octree (1st).
    ! Do not move the data, it is not yet set (2nd false).
    ! There are new blocks (3rd true).
    call load_balance(.not.restart, .false., .true.)
    do iBlock = 1, nBlock
       if(Unused_B(iBlock)) CYCLE
       call set_amr_geometry(iBlock)
    end do

    if (iProc == 0.and.lVerbose>0)then
       call write_prefix; write (iUnitOut,*) '    total blocks = ',nBlockALL
    end if

    nRefineLevel = initial_refine_levels

    if(DoSetLevels) call set_levels
  end subroutine grid_setup

  !===========================================================================

  subroutine set_initial_conditions

    use ModUser,        ONLY: user_initial_perturbation, user_action
    use ModIO,          ONLY: restart
    use ModIO,          ONLY: restart_Bface       !^CFG IF CONSTRAINB
    use ModRestartFile, ONLY: read_restart_files
    use ModCovariant,   ONLY: UseVertexBasedGrid,do_fix_geometry_at_reschange 
    use ModMessagePass, ONLY: exchange_messages

    !\
    ! Set intial conditions for solution in each block.
    !/

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = &
         NameSub//'::set_initial_conditions'
    integer :: iLevel, iBlock
    !-------------------------------------------------------------------------
    if(.not.restart .and. nRefineLevelIC>0)then
       call timing_start('amr_ics')
       do iLevel=1,nRefineLevelIC
          call timing_start('amr_ics_set')
          do globalBLK = 1, nBlockMax
             call set_ICs
          end do
          call timing_stop('amr_ics_set')

          ! Allow the user to add a perturbation and use that 
          ! for physical refinement.
          if (UseUserPerturbation)then
             call timing_start('amr_ics_perturb')
             call user_initial_perturbation
             call timing_stop('amr_ics_perturb')
          end if

          call timing_start('amr_ics_amr')
          ! Do physics based AMR with the message passing
          call amr(.true.,'phy')

          call timing_stop('amr_ics_amr')
       end do

       ! Move coordinates, but not data (?), there are new blocks
       call timing_start('amr_ics_balance')
       call load_balance(.true.,.false.,.true.)
       call timing_stop('amr_ics_balance')

       call timing_stop('amr_ics')
    end if
    ! nRefineLevelIC has done its work, reset to zero
    nRefineLevelIC = 0


    !\
    ! Read initial data for solution blocks
    ! from restart files as necessary.
    !/
    if(restart)then
       call read_restart_files
       !Vertex based geometry at the resolution interfaces 
       !should be fixed while setting the block geometry
       if(UseVertexBasedGrid)then
          Do iBlock=1,nBlockMax
             if(do_fix_geometry_at_reschange(iBlock))&
                  call fix_geometry_at_reschange(iBlock)
          end Do
       end if
    end if

    do globalBLK = 1, nBlockMax
       !\
       ! Initialize solution block.
       !/
       call set_ICs
    end do

    call user_action('initial condition done')

    !\
    ! Allow the user to add a perturbation to the initial condition.
    !/
    if (UseUserPerturbation) then
       call user_initial_perturbation
       UseUserPerturbation=.false.
    end if

    if (restart) then
       if(iProc==0)then
          call write_prefix; write(iUnitOut,*)&
               NameSub,' restarts at n_step,Time_Simulation=',&
               n_step,Time_Simulation
       end if
       ! Load balance for the inner blocks:
       ! move coords, move data, there are new blocks
       call load_balance(.true.,.true.,.true.)

       ! Redo the AMR level constraints for fixed body level
       ! The coordinates of the blocks are only known now
       if(DoSetLevels) call set_levels
    end if

    !^CFG IF CONSTRAINB BEGIN
    ! Ensure zero divergence for the CT scheme
    if(UseConstrainB)then
       if(restart_Bface)then
          DoInitConstrainB=.false.
       else
          call BATS_init_constrain_b
       end if
    end if
    !^CFG END CONSTRAINB

    call exchange_messages(.false.)

  end subroutine set_initial_conditions

  !============================================================================

  subroutine initialize_files
    use ModSatelliteFile, ONLY: set_satellite_file_status, nSatellite
    use ModGroundMagPerturb, ONLY: &
         save_magnetometer_data, open_magnetometer_output_file
    ! Local variables
    character(len=*), parameter :: NameSubSub = NameSub//'::initialize_files'
    integer :: iSat

    if (iProc == 0) then
       do iSat = 1, nSatellite
          call set_satellite_file_status(iSat,'open')
          call set_satellite_file_status(iSat,'close')
       end do
    end if

    if (save_magnetometer_data .and. iProc == 0) then
       call open_magnetometer_output_file
    end if

    plot_type(restart_)='restart'
    plot_type(logfile_)='logfile'

  end subroutine initialize_files

end subroutine BATS_setup

!==============================================================================

subroutine BATS_init_session

  use ModMain, ONLY: DoTransformToHgi, UseUserPerturbation, &
       UseRadDiffusion, UseHeatConduction, UseIonHeatConduction
  use ModMain, ONLY: UseProjection                 !^CFG IF PROJECTION
  use ModMain, ONLY: UseConstrainB                 !^CFG IF CONSTRAINB
  use ModCT,   ONLY: DoInitConstrainB              !^CFG IF CONSTRAINB
  use ModHallResist, ONLY: UseHallResist, init_hall_resist, &
       UseBiermannBattery
  use ModImplicit, ONLY: UseSemiImplicit, &                !^CFG IF IMPLICIT
       TypeSemiImplicit, UseFullImplicit                   !^CFG IF IMPLICIT
  use ModRadDiffusion, ONLY: init_rad_diffusion            !^CFG IF IMPLICIT
  use ModHeatConduction, ONLY: init_heat_conduction        !^CFG IF IMPLICIT
  use ModUser, ONLY: user_initial_perturbation
  use ModRestartFile, ONLY: UseRestartOutSeries
  use ModMessagePass, ONLY: exchange_messages

  implicit none

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_init_session '
  !---------------------------------------------------------------------------
  ! Find the test cell defined by #TESTIJK or #TESTXYZ commands
  call find_test_cell

  !\
  ! Allow the user to add a perturbation to the initial condition.
  !/
  if (UseUserPerturbation) then
     call user_initial_perturbation
     UseUserPerturbation=.false.
  end if

  ! Set number of explicit and implicit blocks !^CFG IF  IMPLICIT BEGIN
  ! Partially implicit/local selection will be done in each time step
  call select_stepping(.false.)                !^CFG END IMPLICIT 

  ! Transform velocities from a rotating system to the HGI system if required
  if(DoTransformToHgi)then
     call transform_to_hgi
     DoTransformToHgi = .false.
  end if

  ! Ensure zero divergence for the CT scheme   !^CFG IF CONSTRAINB
  if(UseConstrainB .and. DoInitConstrainB)&    !^CFG IF CONSTRAINB
       call BATS_init_constrain_b              !^CFG IF CONSTRAINB

  if(UseHallResist .or. UseBiermannBattery)call init_hall_resist

  if(UseHeatConduction .or. UseIonHeatConduction) & !^CFG IF  IMPLICIT BEGIN
       call init_heat_conduction
  if(UseSemiImplicit)then
     select case(TypeSemiImplicit)
     case('radiation', 'radcond', 'cond')
        call init_rad_diffusion
     end select
  elseif(UseFullImplicit.and.UseRadDiffusion)then
     call init_rad_diffusion
  end if                                            !^CFG END IMPLICIT

  ! Make sure that ghost cells are up to date
  call exchange_messages

  if(UseProjection)call project_B              !^CFG IF PROJECTION

  call BATS_save_files('INITIAL')

  ! save initial condition
  if (UseRestartOutSeries)then
     call BATS_save_files('NORMAL')
  end if

end subroutine BATS_init_session

!============================================================================

subroutine BATS_advance(TimeSimulationLimit)

  ! Advance solution with one time step

  use ModKind
  use ModProcMH
  use ModMain
  use ModIO, ONLY: iUnitOut, write_prefix, save_plots_amr
  use ModAmr, ONLY: DnAmr, DoAmr
  use ModPhysics, ONLY : No2Si_V, UnitT_
  use ModAdvance, ONLY: UseNonConservative, nConservCrit, UseAnisoPressure
  use ModPartSteady, ONLY: UsePartSteady, IsSteadyState, &
       part_steady_select, part_steady_switch
  use ModImplicit, ONLY: UseImplicit, UseSemiImplicit    !^CFG IF IMPLICIT
  use ModIonoVelocity, ONLY: apply_iono_velocity
  use ModTimeStepControl, ONLY: UseTimeStepControl, control_time_step
  use ModLaserHeating,    ONLY: add_laser_heating
  use ModVarIndexes, ONLY: Te0_
  use ModMessagePass, ONLY: exchange_messages

  implicit none

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_advance'

  logical :: DoTest, DoTestMe
  !---------------------------------------------------------------------------
  !Eliminate non-positive timesteps
  if(Time_Simulation>=TimeSimulationLimit)return 

  ! Check if steady state is achieved
  if(.not.time_accurate .and. UsePartSteady .and. IsSteadyState)then
     ! Create stop condition for stand alone mode
     nIter = iteration_number
     ! There is nothing to do, simply return
     RETURN
  end if

  call set_oktest(NameSub,DoTest,DoTestMe)

  ! We are advancing in time
  time_loop = .true.

  ! Select block types and load balance blocks
  call BATS_select_blocks

  ! Switch off steady blocks to reduce calculation
  if(UsePartSteady) call part_steady_switch(.true.)

  n_step = n_step + 1
  iteration_number = iteration_number+1

  ! Calculate time step dt
  if (time_accurate) call set_global_timestep(TimeSimulationLimit)

  call timing_start('advance')

  if(UseNonConservative .and. nConservCrit > 0)&
       call select_conservative

  if(UseImplicit.and.nBlockImplALL>0)then !^CFG IF IMPLICIT BEGIN
     call advance_impl
  else                                    !^CFG END IMPLICIT
     call advance_expl(.true., -1)
  endif                                   !^CFG IF IMPLICIT  

  if(UseIM)call apply_im_pressure         !^CFG IF RCM

  if(UseAnisoPressure)call fix_anisotropy

  if(UseIE)call apply_iono_velocity

  if(UseDivBDiffusion)call clean_divb     !^CFG IF DIVBDIFFUSE

  if(UseLaserHeating) call add_laser_heating

  !Calculate temperature at the end of time step
  if(Te0_>1)call update_te0
  
  call exchange_messages

  if(UseSemiImplicit .and. (Dt>0 .or. .not.time_accurate)) & !^CFG IF IMPLICIT
       call advance_impl                                     !^CFG IF IMPLICIT

  if(UseTimeStepControl .and. time_accurate .and. Dt>0) call control_time_step

  if(UsePartSteady) then
     ! Select steady and unsteady blocks
     if(.not. (Time_Accurate .and. Time_Simulation == 0.0))then
        call timing_start('part_steady')
        call part_steady_select
        call timing_stop('part_steady')
     end if

     ! Switch on steady blocks to be included in AMR, plotting, etc.
     call part_steady_switch(.false.)
  end if

  call advect_all_points

  call timing_stop('advance')

  if(time_accurate)&
       call update_lagrangian_grid(&
       Time_Simulation - Dt*No2Si_V(UnitT_),Time_Simulation)

  if(DoTest)write(*,*)NameSub,' iProc,new n_step,Time_Simulation=',&
       iProc,n_step,Time_Simulation

  if (DoUpdateB0) then
     ! dB0/dt term is added at the dt_updateB0 frequency

     if ( int(Time_Simulation/dt_UpdateB0) >  &
          int((Time_Simulation - Dt*No2Si_V(UnitT_))/dt_UpdateB0)) &
          call update_b0
  end if

  if ( DoAmr .and. mod(n_step, DnAmr) == 0 )then

     ! Write plotfiles before AMR if required
     if(save_plots_amr)call BATS_save_files('PLOTS')

     call timing_start(NameThisComp//'_amr')
     if(iProc==0 .and. lVerbose > 0 .and. DnAmr > 1)then
        call write_prefix; write(iUnitOut,*) &
             '>>>>>>>>>>>>>>>>>>>> AMR <<<<<<<<<<<<<<<<<<<<'
        if (time_accurate) call write_timeaccurate
     end if

     call BATS_amr_refinement

     ! Output timing after AMR.
     call timing_stop(NameThisComp//'_amr')
     if(iProc == 0 .and. lVerbose > 0 .and. DnAmr > 1)then
        call timing_show(NameThisComp//'_amr',1)
        call timing_show('load_balance',1)
        call write_prefix; write(iUnitOut,*) &
             '>>>>>>>>>>>>>>>>>>>> AMR <<<<<<<<<<<<<<<<<<<<'
     end if

  end if

  if (UseProjection) call project_B    !^CFG IF PROJECTION

  call BATS_save_files('NORMAL')

end subroutine BATS_advance

!=============================================================================
subroutine BATS_amr_refinement

  ! Adaptive Mesh Refinement (AMR):
  ! Refine and coarsen the solution grid (on the fly) as needed.

  use ModProcMH
  use ModIO, ONLY: iUnitOut, write_prefix
  use ModMain, ONLY: lVerbose, x_, y_, z_
  use ModMain, ONLY: UseConstrainB                 !^CFG IF CONSTRAINB
  use ModImplicit, ONLY : n_prev                   !^CFG IF IMPLICIT
  use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK
  use ModAMR, ONLY : nRefineLevel, automatic_refinement
  use ModNumConst, ONLY: cTiny
  use ModAdvance, ONLY : tmp1_BLK

  implicit none

  !LOCAL VARIABLES:
  character(len=*), parameter :: NameSub = 'BATS_amr_refinement '
  real    :: divbmax_now
  real, external :: maxval_loc_abs_BLK
  integer :: iLoc_I(5)  ! full location index
  !--------------------------------------------------------------------------

  !\
  ! Perform the AMR.
  !/
  if (.not. automatic_refinement) nRefineLevel = nRefineLevel + 1

  ! BDF2 scheme should not use previous step after AMR  !^CFG IF IMPLICIT
  n_prev = -100                                         !^CFG IF IMPLICIT

  !if(UseConstrainB)call b_face_fine_pass     !^CFG IF CONSTRAINB

  ! Do AMR without full initial message passing
  call amr(.false.,'all')

  !^CFG IF CONSTRAINB BEGIN
  if(UseConstrainB)then
     !Check for divb
     call proj_get_divb(tmp1_BLK)

     divbmax_now=maxval_loc_abs_BLK(nProc,tmp1_BLK,iLoc_I)
     if(iProc == 0.and.lVerbose>0)then
        call write_prefix; write(iUnitOut,*)
        call write_prefix; write(iUnitOut,*) NameSub, &
             ' maximum of |div B| after AMR=',divbmax_now
        call write_prefix; write(iUnitOut,*)
     end if
     if(iProc==iLoc_I(5).and.divbmax_now>cTiny)write(*,*)&
          NameSub,' WARNING divB,loc,x,y,z=',divbmax_now,iLoc_I,&
          x_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
          y_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
          z_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4))
  end if
  !^CFG END CONSTRAINB

end subroutine BATS_amr_refinement

!^CFG IF CONSTRAINB BEGIN
!============================================================================

subroutine BATS_init_constrain_b
  use ModProcMH
  use ModMain, ONLY: lVerbose, x_, y_, z_, nBlock
  use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK
  use ModCT, ONLY : DoInitConstrainB
  use ModNumConst, ONLY: cTiny
  use ModAdvance, ONLY : Bx_, Bz_, State_VGB, tmp1_BLK
  use ModIO, ONLY: write_prefix, iUnitOut
  use BATL_lib, ONLY: message_pass_cell
  implicit none

  ! Local variables
  character(len=*), parameter :: NameSub ='BATS_init_constrain_b '
  real, external :: maxval_loc_abs_BLK
  integer :: iBlock
  integer :: iLoc_I(5)  ! full location index
  real    :: divbmax_now
  !--------------------------------------------------------------------------
  DoInitConstrainB=.false.

  call message_pass_cell(3,State_VGB(Bx_:Bz_,:,:,:,:), nWidthIn=1, &
       nProlongOrderIn=1, DoSendCornerIn=.false., DoRestrictFaceIn=.true.)

  do iBlock=1, nBlock
     ! Estimate Bface from the centered B values
     call Bcenter2Bface(iBlock)
     ! Calculate energy (it is not set in set_ICs)
     ! because the projection scheme will need it
!!! call calc_energy(iBlock)
  end do

  call proj_get_divb(tmp1_BLK)
  divbmax_now=maxval_loc_abs_BLK(nProc,tmp1_BLK,iLoc_I)
  if(iProc == 0.and.lVerbose>0)then
     call write_prefix; write(iUnitOut,*)
     call write_prefix; write(iUnitOut,*) NameSub, &
          ' maximum of |div B| before projection=',divbmax_now
     call write_prefix; write(iUnitOut,*)
  end if
  if(divbmax_now>cTiny)then
     if(iProc==iLoc_I(5))then
        call write_prefix; write(iUnitOut,*) NameSub, &
             ' divB,loc,x,y,z=',divbmax_now,iLoc_I,&
             x_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
             y_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
             z_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4))
     end if

     if(iProc == 0.and.lVerbose>0)then
        call write_prefix; write(iUnitOut,*)
        call write_prefix; write(iUnitOut,*) &
             NameSub,' projecting B for CT scheme...'
     end if

     ! Do the projection with UseConstrainB true
     call project_B

     ! Check and report the accuracy of the projection
     call proj_get_divb(tmp1_BLK)
     divbmax_now=maxval_loc_abs_BLK(nProc,tmp1_BLK,iLoc_I)
     if(iProc == 0.and.lVerbose>0)then
        call write_prefix; write(iUnitOut,*)
        call write_prefix; write(iUnitOut,*) NameSub, &
             ' maximum of |div B| after projection=',divbmax_now
        call write_prefix; write(iUnitOut,*)
     end if
     if(iProc==iLoc_I(5).and.divbmax_now>cTiny)then
        call write_prefix; write(iUnitOut,*) NameSub, &
             ' divB,loc,x,y,z=',divbmax_now,iLoc_I,&
             x_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
             y_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4)),&
             z_BLK(iLoc_I(x_),iLoc_I(y_),iLoc_I(z_),iLoc_I(4))
     end if
  end if

end subroutine BATS_init_constrain_b

!^CFG END CONSTRAINB

!============================================================================
subroutine BATS_select_blocks

  use ModProcMH
  use ModImplicit, ONLY : UsePartImplicit !^CFG IF IMPLICIT
  use ModPartSteady, ONLY: UsePartSteady, IsNewSteadySelect
  implicit none

  !LOCAL VARIABLES:
  character(len=*), parameter :: NameSub = 'BATS_select_blocks'
  !--------------------------------------------------------------------------

  ! Select and load balance blocks for partially implicit/steady scheme
  if( UsePartSteady .and. IsNewSteadySelect &
       .or. UsePartImplicit &                !^CFG IF IMPLICIT
       )then

     !Redo load balancing: move coordinates and data, there are no new blocks
     call load_balance(.true.,.true.,.false.)

     IsNewSteadySelect = .false.
  end if

end subroutine BATS_select_blocks

!===========================================================================

subroutine BATS_save_files(TypeSaveIn)

  use ModProcMH
  use ModMain
  use ModIO
  use ModUtilities, ONLY : upper_case
  use ModMessagePass, ONLY: exchange_messages
  implicit none
  character(len=*), intent(in) :: TypeSaveIn

  character(len=len(TypeSaveIn)) :: TypeSave
  logical :: DoExchangeAgain, DoAssignNodeNumbers, IsFound, DoSaveRestartTmp
  integer :: iFile

  character(len=*), parameter :: NameSub='BATS_save_files'
  !--------------------------------------------------------------------------

  DoExchangeAgain     = .false.
  DoAssignNodeNumbers = .true.
  TypeSave = TypeSaveIn
  call upper_case(TypeSave)
  select case(TypeSave)
  case('INITIAL')
     ! Do not save current step or time
     n_output_last = n_step

     ! Initialize last save times
     where(dt_output>0.) &
          t_output_last=int(time_simulation/dt_output)

     ! DoSaveInitial may be set to true in the #SAVEINITIAL command
     if(DoSaveInitial .or. (time_accurate .and. time_simulation == 0.0))then
        if(DoSaveInitial)then
           ! Save all (except restart files)
           n_output_last = -1
           t_output_last = -1.0
        else
           ! Save only those with a positive time frequency
           where(dt_output>0.)
              n_output_last = -1
              t_output_last = -1.0
           end where
        end if
        ! Do not save restart file in any case
        n_output_last(restart_) = n_step
        call save_files
     end if
     ! Set back to default value (for next session)
     DoSaveInitial = .false.
  case('FINAL')
     save_restart_file = .false.
     call save_files_final
  case('FINALWITHRESTART')
     call save_files_final
  case('NORMAL')
     call save_files
  case('PLOT','PLOTS')
     do iFile=plot_+1, plot_+nPlotFile
        call save_file
     end do
  case('RESTART')
     DoSaveRestartTmp = save_restart_file
     save_restart_file = .true.
     iFile = restart_
     call save_file
     save_restart_file = DoSaveRestartTmp
  case default
     call stop_mpi(NameSub//' ERROR incorrect TypeSave='//TypeSave)
  end select

contains

  subroutine save_files

    logical :: DoSave = .false.
    integer :: t_output_current

    do ifile=1,nfile
       if(dn_output(ifile)>=0)then
          if(dn_output(ifile)==0)then
             call save_file
          else if(mod(n_step,dn_output(ifile))==0)then
             call save_file
          end if
       else if(time_accurate .and. dt_output(ifile)>0.)then
          t_output_current = int(time_simulation/dt_output(ifile))
          DoSave = .false.
          if(t_output_current>t_output_last(ifile)) DoSave = .true.
          if(DoSave)then
             t_output_last(ifile)=t_output_current
             call save_file
          end if
       end if
    end do
    ! If message passing with corners was done in save_file for tecplot plots,
    ! then do exchange_messages over again to get expected values 
    ! in ghost cells.

    if(DoExchangeAgain)then
       if(iProc==0.and.lVerbose>0)then
          call write_prefix; write(iUnitOut,*)&
               'Calling exchange_messages to reset ghost cells ...'
       end if
       call exchange_messages(DoResChangeOnlyIn=.true.)
    end if

  end subroutine save_files

  !==========================================================================

  subroutine save_file
    use ModRestartFile, ONLY: write_restart_files
    use ModSatelliteFile, ONLY: &
         nSatellite, set_satellite_file_status, set_satellite_flags, &
         TimeSatStart_I, TimeSatEnd_I, iCurrent_satellite_position
    use ModGroundMagPerturb, ONLY: save_magnetometer_data, write_magnetometers
    use ModGmGeoindices, ONLY: DoWriteIndices, write_geoindices
    use ModMessagePass, ONLY: exchange_messages

    integer :: iSat

    ! Backup location for the Time_Simulation variable.
    ! Time_Simulation is used in steady-state runs as a loop parameter
    ! in the save_files subroutine, where set_satellite_flags and 
    ! write_logfile are called with different Time_Simulation values
    ! spanning all the satellite trajectory cut. Old Time_Simulation value
    ! is saved here before and it is restored after the loop.
    !
    real :: tSimulationBackup = 0.0
    !---------------------------------------------------------------------

    if(n_step<=n_output_last(ifile) .and. dn_output(ifile)/=0 &
         .and. (n_step/=0 .or. ifile/=restart_) ) return

    if(ifile==restart_) then
       ! Case for restart file
       if(.not.save_restart_file)return
       call write_restart_files

    elseif(ifile==logfile_) then
       ! Case for logfile 

       if(.not.save_logfile)return
       call timing_start('save_logfile')
       call write_logfile(0,ifile)
       call timing_stop('save_logfile')

    elseif(ifile>plot_ .and. ifile<=plot_+nplotfile) then
       ! Case for plot files
       IsFound=.false.

       if(.not.DoExchangeAgain .and. ( &
            index(plot_type(iFile),'lin')==1 .or. &    !^CFG IF RAYTRACE
            index(plot_type(iFile),'eqr')==1 .or. &    !^CFG IF RAYTRACE
            index(plot_type(iFile),'ieb')==1 .or. &    !^CFG IF RAYTRACE
            index(plot_type(iFile),'lcb')==1 .or. &    !^CFG IF RAYTRACE
            index(plot_type(iFile),'los')==1 .or. &
            index(plot_type(iFile),'sph')==1 .or. &
            plot_form(iFile) == 'tec')) then

          if(iProc==0.and.lVerbose>0)then
             call write_prefix; write(iUnitOut,*)&
                  ' Message passing for plot files ...'
          end if
          call exchange_messages(UseOrder2In=.true.)
          DoExchangeAgain = .true.
       end if

       if(index(plot_type(iFile),'los')>0) then
          IsFound = .true.
          call write_plot_los(iFile)
       end if

       if(index(plot_type(iFile),'rfr')>0) then
          IsFound = .true.
          call write_plot_radiowave(iFile)
       end if

       !^CFG IF RAYTRACE BEGIN
       if(index(plot_type(iFile),'lin')>0) then
          IsFound = .true.
          call write_plot_line(iFile)
       end if

       if(index(plot_type(iFile),'eqr')>0) then
          IsFound = .true.
          call plot_ray_equator(iFile)
       end if

       if(index(plot_type(iFile),'ieb')>0) then
          IsFound = .true.
          call ieb_plot(iFile)
       end if

       if(index(plot_type(iFile),'lcb')>0) then
          IsFound = .true.
          call lcb_plot(iFile)
       end if

       !^CFG END RAYTRACE

       if(plot_type(ifile)/='nul' .and. .not.IsFound ) then
          ! Assign node numbers for tec plots
          if( index(plot_form(ifile),'tec')>0 .and. DoAssignNodeNumbers)then
             call assign_node_numbers
             DoAssignNodeNumbers = .false.
          end if

          !^CFG IF RAYTRACE BEGIN
          if(  index(plot_type(ifile),'ray')>0 .or. &
               index(plot_vars(ifile),'status')>0) call ray_trace
          !^CFG END RAYTRACE
          call timing_start('save_plot')
          call write_plot_common(ifile)
          call timing_stop('save_plot')
       end if
    elseif(iFile > Satellite_ .and. iFile <= Satellite_ + nSatellite) then

       ! Case for satellite files
       iSat = iFile - Satellite_
       call timing_start('save_satellite')
       if(iProc==0)call set_satellite_file_status(iSat,'append')
       !
       ! Distinguish between time_accurate and .not. time_accurate:
       !

       if (time_accurate) then
          call set_satellite_flags(iSat)
          ! write one line for a single trajectory point
          call write_logfile(iSat,ifile)
       else
          tSimulationBackup = Time_Simulation    ! Save ...
          Time_Simulation = TimeSatStart_I(iSat)
          do while (Time_Simulation <= TimeSatEnd_I(iSat))
             call set_satellite_flags(iSat)
             ! write for ALL the points of trajectory cut
             call write_logfile(iSat,ifile)  
             Time_Simulation = Time_Simulation + dt_output(iSat+Satellite_)
          end do
          Time_Simulation = tSimulationBackup    ! ... Restore
          icurrent_satellite_position(iSat) = 1
          if(iProc==0)call set_satellite_file_status(iSat,'close')
       end if
       call timing_stop('save_satellite')

    elseif(ifile == magfile_) then
       !Cases for magnetometer files

       if(time_accurate) then  
          if(.not.save_magnetometer_data)return 
          call timing_start('save_magnetometer')
          call write_magnetometers   
          call timing_stop('save_magnetometer')  
       end if

    elseif(ifile == indexfile_) then
       ! Write geomagnetic index file.
       if(time_accurate .and. DoWriteIndices) call write_geoindices
    end if

    n_output_last(ifile)=n_step

    if(iProc==0 .and. lVerbose>0 .and. &
         ifile /= logfile_ .and. iFile /= magfile_ .and. iFile /= indexfile_ &
         .and. (iFile <= satellite_ .or. iFile > satellite_ + nSatellite))then
       if(time_accurate)then
          call write_prefix; 
          write(iUnitOut,'(a,i2,a,a,a,i7,a,i4,a,i2.2,a,i2.2,a)') &
               'saved ifile=',ifile,' type=',plot_type(ifile),&
               ' at n_step=',n_step,' time=', &
               int(                            Time_Simulation/3600.),':', &
               int((Time_Simulation-(3600.*int(Time_Simulation/3600.)))/60.),':', &
               int( Time_Simulation-(  60.*int(Time_Simulation/  60.))), &
               ' h:m:s'
       else
          call write_prefix; write(iUnitOut,'(a,i2,a,a,a,i7)') &
               'saved ifile=',ifile,' type=',plot_type(ifile), &
               ' at n_step=',n_step
       end if
    end if

  end subroutine save_file

  !===========================================================================

  subroutine save_files_final
    use ModSatelliteFile, ONLY: set_satellite_file_status, nSatellite
    use ModGmGeoindices,  ONLY: DoWriteIndices, finalize_geoindices
    use ModGroundMagPerturb, ONLY:save_magnetometer_data, close_magnetometer_output_file
    implicit none

    integer :: iSat

    do iFile = 1, plot_ + nPlotFile
       call save_file
    end do

    !\
    ! Close files
    !/
    if (iProc==0) then
       do iSat = 1, nSatellite
          call set_satellite_file_status(iSat,'close')
       end do
    end if

    if (DoWriteIndices) call finalize_geoindices()
    if (save_magnetometer_data .and. iProc==0) call close_magnetometer_output_file   

    if (save_logfile.and.iProc==0.and.unit_log>0) close(unit_log)

  end subroutine save_files_final

end subroutine BATS_save_files

!=============================================================================
subroutine BATSRUS_finalize

  use ModAdvance,  ONLY: clean_mod_advance
  use ModGeometry, ONLY: clean_mod_geometry
  use ModNodes,    ONLY: clean_mod_nodes
  use ModCT,       ONLY: clean_mod_ct                  !^CFG IF CONSTRAINB
  use ModRaytrace, ONLY: clean_mod_raytrace            !^CFG IF RAYTRACE
  use ModImplicit, ONLY: clean_mod_implicit            !^CFG IF IMPLICIT
  use BATL_lib,    ONLY: clean_batl

  implicit none

  integer:: iError
  !---------------------------------------------------------------------------
  call clean_batl
  call clean_mod_advance
  call clean_mod_ct                          !^CFG IF CONSTRAINB
  call clean_mod_implicit                    !^CFG IF IMPLICIT
  call clean_mod_geometry
  call clean_mod_nodes
  call clean_mod_raytrace                    !^CFG IF RAYTRACE

  ! call clean_mod_boundary_cells !!! to be implemented
  ! call clean_mod_resistivity !!! to be implemented

  call error_report('PRINT',0.,iError,.true.)

end subroutine BATSRUS_finalize
