! This file contains the top level methods for BATSRUS

subroutine BATS_setup
  use ModMpi
  use ModProcMH
  use ModIoUnit, ONLY: UNITTMP_
  use ModMain
  use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK
  use ModCT, ONLY : DoInitConstrainB               !^CFG IF CONSTRAINB
  use ModImplicit, ONLY : UsePartImplicit,n_prev   !^CFG IF IMPLICIT
  use ModIO
  use ModHdf5, ONLY : hdf5_setup
  use ModAMR, ONLY : &
       DnAmr, initial_refine_levels, nRefineLevelIC, nRefineLevel,&
       automatic_refinement
  use ModAdvance, ONLY : iTypeAdvance_B, iTypeAdvance_BP, ExplBlock_
  use ModNumConst
  use ModAdjoint, ONLY : DoAdjoint                 !ADJOINT SPECIFIC
  use ModRestartFile, ONLY : UseRestartInSeries  

  implicit none

  ! Local variables

  character(len=*), parameter :: NameSub = 'BATS_setup'
  integer :: iError 

  !---------------------------------------------------------------------------

  if (DoAdjoint)then                          !ADJOINT SPECIFIC BEGIN
     ! For adjoint, use final solution as a restart
     restart = .true.
     UseRestartInSeries = .true.
  end if                                      !ADJOINT SPECIFIC END

  ! Allocate and initialize variables dependent on number of PEs
  call allocate_vars  

  if(.not.IsStandAlone)call write_progress(0)

  call grid_setup   ! Restart reads integer only (no X_BLK or dx_BLK)

  call set_initial_conditions ! Restart reads all real data

  call find_test_cell

  call initialize_files

  call hdf5_setup

  call MPI_BARRIER(iComm,iError) ! ----------- BARRIER ------

  call write_runtime_values

  restart = .false.

contains
  !===========================================================================

  subroutine grid_setup

    ! Set up problem geometry, blocks, and grid structure.

    use ModIO, ONLY: restart
    use ModRestartFile, ONLY: read_octree_file, NameRestartInDir, &
         UseRestartInSeries, string_append_iter

    use ModMain, ONLY: UseBatl, iteration_number
    use BATL_lib, ONLY: init_grid_batl, read_tree_file
    use ModBatlInterface, ONLY: set_batsrus_grid

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = NameSub//'::grid_setup'
    character(len=100) :: NameFile
    logical :: local_refine(nBLK)

    integer:: iBlock
    !--------------------------------------------------------------------------

    if(UseBatl)then
       call set_batsrus_grid
    else
       call set_root_block_geometry
       call build_octree_roots   ! Initialize octree data structure.
       call find_neighbors       ! Get initial neighbor information.
    end if

    if (.not.restart) then
       ! Create initial solution block geometry.

       ! Perform initial refinement of mesh and solution blocks.
       do nRefineLevel = 1, initial_refine_levels

          if(UseBatl)then
             if (iProc == 0.and.lVerbose>0) then
                call write_prefix; write (iUnitOut,*) NameSub, &
                     ' starting initial refinement level, nBlockAll =', &
                     nRefineLevel, nBlockAll
             end if
             call specify_refinement(local_refine)
             call init_grid_batl(local_refine)
             call set_batsrus_grid
          else
             if (iProc == 0.and.lVerbose>0) then
                call write_prefix; write (iUnitOut,*) NameSub, &
                     ' starting initial refinement level ', nRefineLevel
             end if
             call specify_refinement(local_refine)
             call refine_grid(local_refine)
          end if
       end do
    else
       ! Read initial solution block geometry from octree restart file.

       if(UseBatl)then
          NameFile = trim(NameRestartInDir)//'octree.rst'
          if (UseRestartInSeries) call string_append_iter(NameFile,iteration_number)
          call read_tree_file(NameFile)
          call init_grid_batl
          call set_batsrus_grid
       else
          call read_octree_file
       end if
    end if

    if(.not.UseBatl)then
       ! number blocks and balance load
       call number_soln_blocks
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

    if (iProc == 0.and.lVerbose>0)then
       call write_prefix; write (iUnitOut,*) '    total blocks = ',nBlockALL
    end if

    nRefineLevel = initial_refine_levels

    if(DoSetLevels) call set_levels
  end subroutine grid_setup

  !===========================================================================

  subroutine set_initial_conditions
    use ModUser,        ONLY: user_initial_perturbation
    use ModIO,          ONLY: restart
    use ModIO,          ONLY: restart_Bface       !^CFG IF CONSTRAINB
    use ModRestartFile, ONLY: read_restart_files, &
         tSimulationRead                          !ADJOINT SPECIFIC
    use ModCovariant,   ONLY: UseVertexBasedGrid,do_fix_geometry_at_reschange 
    !\
    ! Set intial conditions for solution in each block.
    !/

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = &
         NameSub//'::set_initial_conditions'
    integer :: iLevel, iError,iBlock
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
          if (UseBatl) then
             ! Do physics based AMR with the message passing
             call amr(.true.)
          else
             ! Do physics based AMR without the message passing
             call amr_physics
             call number_soln_blocks
          end if
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
       if (DoAdjoint) time_simulation = tSimulationRead     !ADJOINT SPECIFIC
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

  end subroutine set_initial_conditions

  !============================================================================

  subroutine initialize_files
    use ModSatelliteFile, ONLY: set_satellite_file_status, nSatellite
    use ModGroundMagPerturb, ONLY: &
         save_magnetometer_data, open_magnetometer_output_file
    ! Local variables
    character(len=*), parameter :: NameSubSub = NameSub//'::initialize_files'
    logical :: delete_file
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
  use ModHallResist, ONLY: UseHallResist, init_hall_resist,test_face_current, &
       UseBiermannBattery
  use ModImplicit, ONLY: UseSemiImplicit, &                !^CFG IF IMPLICIT
       TypeSemiImplicit, UseFullImplicit                   !^CFG IF IMPLICIT
  use ModRadDiffusion, ONLY: init_rad_diffusion            !^CFG IF IMPLICIT
  use ModHeatConduction, ONLY: init_heat_conduction        !^CFG IF IMPLICIT
  use ModUser, ONLY: user_initial_perturbation
  use ModRestartFile, ONLY: UseRestartOutSeries
  use ModAdjoint, ONLY : DoAdjoint                 !ADJOINT SPECIFIC
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
  !call test_face_current

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

  !if (.not.DoAdjoint)then                      !ADJOINT SPECIFIC
  call BATS_save_files('INITIAL')

  ! save initial condition (primarily for adjoint purposes)
  if (UseRestartOutSeries)then
     call BATS_save_files('NORMAL')
  end if
  !end if                                       !ADJOINT SPECIFIC


end subroutine BATS_init_session

!============================================================================

subroutine BATS_advance(TimeSimulationLimit)
  !\
  ! Advance solution with one time step
  !/
  use ModKind
  use ModProcMH
  use ModMain
  use ModIO, ONLY: iUnitOut, write_prefix, save_plots_amr
  use ModAmr, ONLY: DnAmr, DoAmr
  use ModPhysics, ONLY : No2Si_V, UnitT_
  use ModAdvance, ONLY: UseNonConservative, nConservCrit, UseAnisoPressure, State_VGB
  use ModPartSteady, ONLY: UsePartSteady, IsSteadyState, &
       part_steady_select, part_steady_switch
  use ModImplicit, ONLY: UseImplicit, UseFullImplicit, &   !^CFG IF IMPLICIT
       UseSemiImplicit                                     !^CFG IF IMPLICIT
  use ModIonoVelocity, ONLY: apply_iono_velocity
  use ModTimeStepControl, ONLY: UseTimeStepControl, control_time_step
  use ModLaserHeating,    ONLY: add_laser_heating
  use ModAdjoint, ONLY: DoAdjoint                          !ADJOINT SPECIFIC
  use ModMessagePass, ONLY: exchange_messages

  implicit none

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_advance'

  integer      :: iBlock

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

  call exchange_messages

  if(UseSemiImplicit .and. Dt>0) call advance_impl   !^CFG IF IMPLICIT

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

  if (.not.DoAdjoint) then             !ADJOINT SPECIFIC
     call BATS_save_files('NORMAL')
  end if                               !ADJOINT SPECIFIC

end subroutine BATS_advance


!ADJOINT SPECIFIC BEGIN
!===========================================================================
subroutine BATS_advance_adjoint                 
  !\
  ! Advance adjoint solution with one time step
  !/
  use ModKind
  use ModProcMH
  use ModMain
  use ModIO, ONLY: iUnitOut, write_prefix, save_plots_amr
  use ModImplicit, ONLY:  UseSemiImplicit                 !^CFG IF IMPLICIT
  use ModAdvance, ONLY: State_VGB
  use ModAdjoint
  !use ModMessagePass, ONLY: exchange_messages

  implicit none

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_advance_adjoint'

  logical :: DoTest, DoTestMe
  !-------------------------------------------------------------------------

  call set_oktest(NameSub,DoTest,DoTestMe)

  ! We are advancing in time
  time_loop = .true.

  ! initialize adjoint if on first iteration
  if (iteration_number == nIter)then
     call init_adjoint_solution
     call adjoint_fill_buffer
     iteration_number = iteration_number-1
     n_step = n_step - 1
     RETURN
  end if

  ! position in buffer
  iBuffer = mod(iteration_number+1, nBuffer-1)

  write(*,*)' In advance_adjoint: iBuffer pre-fill  = ',iBuffer

  ! fill buffer if necessary
  if (iBuffer <= 0)then
     call adjoint_fill_buffer
     iBuffer = nBuffer-1
  end if

  write(*,*)' In advance_adjoint: iBuffer post-fill  = ',iBuffer

  ! Now, current state is in iBuffer, future is in iBuffer+1

  ! decrement iteration
  n_step = n_step - 1
  iteration_number = iteration_number-1

  ! current time and time step (future minus current)
  time_simulation = Buffer_time_simulation(iBuffer)
  dt = Buffer_time_simulation(iBuffer+1) - time_simulation

  write(*,*)' In advance_adjoint: time_simulation = ',time_simulation

  call timing_start('advance_adjoint')

  ! TODO:
  ! if(UseSemiImplicit) call advance_impl   !^CFG IF IMPLICIT
  ! call exchange_messages
  ! call advance_expl(.true., -1)
  ! add source ... another exchange_messages?

  ! TEMPORARY: for now, just set adjoint to state (debug mode)
  Adjoint_VGB(:,:,:,:,:) = Buffer_State_VGB(:,:,:,:,:,iBuffer)

  call timing_stop('advance_adjoint')

  if(DoTest)write(*,*)NameSub,' iProc,new n_step,Time_Simulation=',&
       iProc,n_step,Time_Simulation

  ! save adjoint files
  ! TODO: use DnSaveAdjoint, DtSaveAdjoint, adjoint directory
  !State_VGB(:,:,:,:,:) = Adjoint_VGB(:,:,:,:,:)
  !call BATS_save_files('NORMAL')

end subroutine BATS_advance_adjoint
!ADJOINT SPECIFIC END

!ADJOINT SPECIFIC BEGIN
!=============================================================================
subroutine adjoint_fill_buffer

  use ModRestartFile, ONLY: UseRestartInSeries, read_restart_files, &
       tSimulationRead, string_append_iter
  use ModMain,        ONLY: time_simulation, t_max
  use ModAdvance,     ONLY: State_VGB
  use ModAdjoint
  use ModMessagePass, ONLY: exchange_messages

  character(len=*), parameter:: NameSub = 'adjoint_fill_buffer'
  integer :: ibuf, iteration_number_orig
  real :: told

  !\
  ! Read checkpoint, advance solution to fill buffer
  !/
  write(*,*)'reading checkpoint in advance_fill_buffer'
  UseRestartInSeries = .true.
  iteration_number_orig = iteration_number
  iteration_number = (nBuffer-1)*int(iteration_number/(nBuffer-1))
  call read_restart_files
  ! need simulation time ... already read in as part of restart file
  !told = time_simulation
  !time_simulation = tSimulationRead
  ! new approach: parse restart header
  call parse_restart_header
  ! Update ghost cells, etc.
  call exchange_messages
  !call BATS_init_session

  Buffer_State_VGB(:,:,:,:,:,1) = State_VGB(:,:,:,:,:)
  Buffer_time_simulation(1) = time_simulation
  do ibuf=2, nBuffer
     call BATS_advance(t_max)
     write(*,*)' after advancing buffer, iteration_number=',iteration_number
     Buffer_State_VGB(:,:,:,:,:,ibuf) = State_VGB(:,:,:,:,:)
     Buffer_time_simulation(ibuf) = time_simulation
  end do

  write(*,*)' after filling buffer, told,time(nbuffer) = ', &
       told,Buffer_time_simulation(nBuffer)

  ! reset iteration number to original
  iteration_number = iteration_number_orig

contains

  ! parses n**_restart.H for simulation time
  subroutine parse_restart_header

    use ModProcMH, ONLY: iComm, iProc, nProc
    use ModIoUnit, ONLY: UNITTMP_

    character(len=*), parameter :: NameSub='parse_restart_header'
    character(len=100) :: NameFile='restart.H', StringLine
    logical :: IsFound
    integer :: i, iReadError, iError

    ! include iteration number
    call string_append_iter(NameFile,iteration_number)

    ! root reads and broadcasts
    if(iProc==0)then
       inquire(file=NameFile,EXIST=IsFound)
       if(.not.IsFound)call stop_mpi(NameSub//trim(NameFile)//" cannot be found")
       open(UNITTMP_,file=NameFile,status="old")
       IsFound = .false.
       do
          read(UNITTMP_,'(a)',ERR=100,END=100) StringLine
          if(StringLine=='#TIMESIMULATION')then
             ! Include text from file following the command
             read(UNITTMP_,'(a)')StringLine
             ! Remove anything after a space or TAB
             i=index(StringLine,' ');     if(i>0)StringLine(i:len(StringLine))=' '
             i=index(StringLine,char(9)); if(i>0)StringLine(i:len(StringLine))=' '
             ! Read time_simulation (real) from string
             read(StringLine,*,iostat=iReadError) time_simulation
             if(iReadError/=0) call stop_mpi(NameSub//trim(NameFile)//&
                  " error parsing line after #TIMESIMULATION")
             IsFound = .true.
          end if
100       continue
          close (UNITTMP_)
          ! The file ended, stop reading
          EXIT
       end do
       if (.not.IsFound)then
          call stop_mpi(NameSub//trim(NameFile)//&
               " TIMESIMULATION not found in restart header")
       end if
    end if

    ! Broadcast time_simulation to all processors
    call MPI_Bcast(time_simulation,1,MPI_REAL,0,iComm,iError)

  end subroutine parse_restart_header

end subroutine adjoint_fill_buffer

!ADJOINT SPECIFIC END


!=============================================================================
subroutine BATS_amr_refinement
  !\
  ! Adaptive Mesh Refinement (AMR):
  ! Refine and coarsen the solution grid (on the fly) as needed.
  !/

  use ModProcMH
  use ModIO, ONLY: iUnitOut, write_prefix
  use ModMain, ONLY: lVerbose, x_, y_, z_
  use ModMain, ONLY: UseConstrainB                 !^CFG IF CONSTRAINB
  use ModCT, ONLY : DoInitConstrainB               !^CFG IF CONSTRAINB
  use ModImplicit, ONLY : UsePartImplicit,n_prev   !^CFG IF IMPLICIT
  use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK
  use ModAMR, ONLY : nRefineLevel, automatic_refinement
  use ModNumConst, ONLY: cTiny
  use ModAdvance, ONLY : tmp1_BLK

  implicit none

  !LOCAL VARIABLES:
  character(len=*), parameter :: NameSub = 'BATS_amr_refinement '
  real    :: divbmax_now
  real, external :: maxval_loc_abs_BLK
  integer :: ifile
  integer :: iLoc_I(5)  ! full location index
  !--------------------------------------------------------------------------

  !\
  ! Perform the AMR.
  !/
  if (.not. automatic_refinement) nRefineLevel = nRefineLevel + 1

  ! BDF2 scheme should not use previous step after AMR  !^CFG IF IMPLICIT
  n_prev = -100                                         !^CFG IF IMPLICIT

  if(UseConstrainB)call b_face_fine_pass     !^CFG IF CONSTRAINB

  ! Do AMR without full initial message passing
  call amr(.false.)

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
  use ModAdvance, ONLY : Bx_,By_,Bz_,State_VGB,tmp1_BLK
  use ModMessagePass, ONLY: message_pass_dir
  use ModIO, ONLY: write_prefix, iUnitOut
  implicit none

  ! Local variables
  character(len=*), parameter :: NameSub ='BATS_init_constrain_b '
  real, external :: maxval_loc_abs_BLK
  integer :: iBlock
  integer :: iLoc_I(5)  ! full location index
  real    :: divbmax_now
  !--------------------------------------------------------------------------
  DoInitConstrainB=.false.

  call message_pass_dir( &
       1,3,1,.false.,1,3,Sol_VGB=State_VGB(Bx_:Bz_,:,:,:,:), &
       restrictface=.true.)

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
  use ModMain, ONLY: lVerbose
  use ModImplicit, ONLY : UsePartImplicit !^CFG IF IMPLICIT
  use ModPartSteady, ONLY: UsePartSteady, IsNewSteadySelect
  implicit none

  !LOCAL VARIABLES:
  character(len=*), parameter :: NameSub = 'BATS_select_blocks'
  integer :: iError
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
  use ModAdjoint, ONLY : DoAdjoint          !ADJOINT SPECIFIC
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
          if (DoAdjoint) then                     !ADJOINT SPECIFIC BEGIN
             DoSave = .false.
             if(t_output_current < t_output_last(ifile)) DoSave = .true.
          end if                                  !ADJOINT SPECIFIC BEGIN
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

    integer :: iFileLoop, iSat

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
  use ModAdjoint,  ONLY: clean_mod_adjoint
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
  call clean_mod_adjoint
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
