!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~!
!               Space Weather Modeling Framework (SWMF)                !
!    Center for Space Environment Modeling, The University of Michigan !
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!BOI
! !TITLE:
! !AUTHORS:
! !AFFILIATION:
! !DATE:
! !INTRODUCTION:
!EOI
!-------------------------------------------------------------------------

subroutine BATS_setup
  use ModMpi
  use ModProcMH
  use ModIoUnit, ONLY: UNITTMP_
  use ModMain
  use ModGeometry, ONLY: x_BLK, y_BLK, z_BLK
  use ModCT, ONLY : DoInitConstrainB               !^CFG IF CONSTRAINB
  use ModImplicit, ONLY : UsePartImplicit,n_prev   !^CFG IF IMPLICIT
  use ModIO
  use ModAMR, ONLY : &
       dn_refine,initial_refine_levels,nRefineLevelIC,nRefineLevel,&
       automatic_refinement
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

contains
  !===========================================================================

  subroutine grid_setup

    use ModIO, ONLY: restart
    use ModRestartFile, ONLY: read_octree_file
    !\
    ! Set up problem geometry, blocks, and grid structure.
    !/

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = NameSub//'::grid_setup'
    logical :: local_refine(nBLK)


    !--------------------------------------------------------------------------

    call set_root_block_geometry
    call build_octree_roots   ! Initialize octree data structure.
    call find_neighbors       ! Get initial neighbor information.

    if (.not.restart) then
       ! Create initial solution block geometry.

       ! Perform initial refinement of mesh and solution blocks.
       do nRefineLevel = 1, initial_refine_levels
          if (iProc == 0.and.lVerbose>0) then
             call write_prefix; write (iUnitOut,*) NameSub, &
                  ' starting initial refinement level ',nRefineLevel
          end if
          call specify_initial_refinement(local_refine, nRefineLevel)
          call refine_grid(local_refine)
          call fixRefinementLevels
       end do
    else
       ! Read initial solution block geometry from octree restart file.

       ! Read restart header file only if old type.
       call read_octree_file     ! Read octree restart file.

    end if
    ! number blocks and balance load
    call number_soln_blocks

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
    use ModRestartFile, ONLY: read_restart_files

    !\
    ! Set intial conditions for solution in each block.
    !/

    !LOCAL VARIABLES:
    character(len=*), parameter :: NameSubSub = &
         NameSub//'::set_initial_conditions'
    integer :: iLevel, iError
    !-------------------------------------------------------------------------
    if(.not.restart .and. nRefineLevelIC>0)then
       do iLevel=1,nRefineLevelIC
          do globalBLK = 1, nBlockMax
             call set_ICs
          end do

          !\
          ! Allow the user to add a perturbation and use that for
          ! physical refinement.
          !/
          if (UseUserPerturbation) &
               call user_initial_perturbation

          call amr_physics
          call fixRefinementLevels
          call number_soln_blocks
       end do
       ! Move coordinates, but not data (?), there are new blocks
       call load_balance(.true.,.false.,.true.)
    end if

    !\
    ! Read initial data for solution blocks
    ! from restart files as necessary.
    !/
    if(restart)call read_restart_files

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
       ! move coords, move data, there are no new blocks
       call load_balance(.true.,.true.,.false.)

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

    ! Local variables
    character(len=*), parameter :: NameSubSub = NameSub//'::initialize_files'
    logical :: delete_file
    integer :: iSat

    if (save_satellite_data .and. iProc == 0) then
       do iSat = 1, nSatellite
          call open_satellite_output_files(iSat)
       end do
    end if

    plot_type(restart_)='restart'
    plot_type(logfile_)='logfile'

  end subroutine initialize_files

end subroutine BATS_setup

!=============================================================================

subroutine BATS_init_session

  use ModMain, ONLY: DoTransformToHgi
  use ModMain, ONLY: UseProjection                 !^CFG IF PROJECTION
  use ModMain, ONLY: UseConstrainB                 !^CFG IF CONSTRAINB
  use ModCT,   ONLY: DoInitConstrainB              !^CFG IF CONSTRAINB
  use ModHallResist, ONLY: UseHallResist, init_hall_resist,test_face_current
  implicit none

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_init_session '
  !--------------------------------------------------------------------------
  ! Find the test cell defined by #TESTIJK or #TESTXYZ commands
  call find_test_cell

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

  if(UseHallResist)call init_hall_resist
  !call test_face_current

  ! Make sure that ghost cells are up to date
  call exchange_messages

  if(UseProjection)call project_B              !^CFG IF PROJECTION

  call BATS_save_files('INITIAL')

end subroutine BATS_init_session

!===========================================================================

subroutine BATS_advance(TimeSimulationLimit)
  !\
  ! Advance solution with one time step
  !/
  use ModKind
  use ModProcMH
  use ModMain
  use ModIO, ONLY: iUnitOut, write_prefix, save_plots_amr
  use ModAmr, ONLY: dn_refine
  use ModPhysics, ONLY : No2Si_V, Si2No_V, UnitT_
  use ModAdvance, ONLY: UseNonConservative, nConservCrit
  use ModPartSteady, ONLY: UsePartSteady, IsSteadyState, &
       part_steady_select, part_steady_switch

  implicit none

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  ! Local variables
  character(len=*), parameter :: NameSub = 'BATS_advance'

  integer      :: iBlock

  logical :: DoTest, DoTestMe
  !-------------------------------------------------------------------------
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
  if (time_accurate) &
       call set_global_timestep((TimeSimulationLimit-Time_Simulation)*Si2No_V(UnitT_))

  ! Calculate unsplit dB0Dt term for every time step
  if(DoUpdateB0 .and. .not.DoSplitDb0Dt)then
     call timing_start('update_B0')
     call calc_db0_dt(dt)
     call timing_stop('update_B0')
  end if

  call timing_start('advance')

  if(UseNonConservative .and. nConservCrit > 0)&
       call select_conservative

  if(UseImplicit.and.nBlockImplALL>0)then !^CFG IF IMPLICIT BEGIN
     call advance_impl
  else                                    !^CFG END IMPLICIT
     call advance_expl(.true.)
  endif                                   !^CFG IF IMPLICIT  
  
  if(UseIM)call apply_im_pressure         !^CFG IF RCM

  Time_Simulation = Time_Simulation + Dt*No2Si_V(UnitT_)
  if(UseDivBDiffusion)call clean_divb     !^CFG IF DIVBDIFFUSE
  call exchange_messages
  
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
     ! Unsplit dB0/dt term is added every time step
     ! Split dB0/dt term is added at the dt_updateB0 frequency
     if (.not.DoSplitDb0Dt .or. &
          int(Time_Simulation/dt_UpdateB0) >  &
          int((Time_Simulation - Dt*No2Si_V(UnitT_))/dt_UpdateB0)) &
          call update_b0
  end if

  if ( dn_refine > 0 .and. mod(n_step,dn_refine)==0 )then

     !\
     ! Output time before AMR.
     !/
     !if(IsStandAlone)then
     !   Due to the ordering this reset and report does not work well
     !   It may not be so important anyway to reset timing before the amr
     !   if (dn_timing > -2) call timing_report
     !   call timing_reset_all
     !end if
     call timing_start(NameThisComp//'_amr')
     if(iProc==0 .and.lVerbose>0)then
        call write_prefix; write(iUnitOut,*) &
             '>>>>>>>>>>>>>>>>>>>> AMR <<<<<<<<<<<<<<<<<<<<'
        if (time_accurate) call write_timeaccurate
     end if
     !\
     ! Write plotfiles before AMR?
     !/
     if(save_plots_amr)call BATS_save_files('PLOTS')
     call BATS_amr_refinement

     !\
     ! Output timing after AMR.
     !/
     call timing_stop(NameThisComp//'_amr')
     if(iProc == 0.and.lVerbose>0)then
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
  !----------------------------------------------------------------------------

  !\
  ! Perform the AMR.
  !/
  if (.not. automatic_refinement) nRefineLevel = nRefineLevel + 1

  ! BDF2 scheme should not use previous step after AMR  !^CFG IF IMPLICIT
  n_prev = -100                                         !^CFG IF IMPLICIT

  if(UseConstrainB)call b_face_fine_pass     !^CFG IF CONSTRAINB

  call amr(nRefineLevel)

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
!=============================================================================

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
  !---------------------------------------------------------------------------
  DoInitConstrainB=.false.

  call message_pass_dir(1,3,1,.false.,1,3,Sol_VGB=State_VGB(Bx_:Bz_,:,:,:,:), &
       restrictface=.true.)

  do iBlock=1, nBlock
     ! Estimate Bface from the centered B values
     call Bcenter2Bface(iBlock)
     ! Calculate energy (it is not set in set_ICs)
     ! because the projection scheme will need it
     call calc_energy(iBlock)
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

!=============================================================================
subroutine BATS_select_blocks

  use ModProcMH
  use ModMain, ONLY: UsePartLocal         !^CFG IF IMPLICIT
  use ModMain, ONLY: lVerbose
  use ModImplicit, ONLY : UsePartImplicit !^CFG IF IMPLICIT
  use ModPartSteady, ONLY: UsePartSteady, IsNewSteadySelect
  implicit none

  !LOCAL VARIABLES:
  character(len=*), parameter :: NameSub = 'BATS_select_blocks'
  integer :: iError
  !----------------------------------------------------------------------------

  ! Select blocks for partially local time stepping

  if(UsePartLocal)call select_stepping(.true.) !^CFG IF IMPLICIT

  ! Select and load balance blocks for partially implicit/steady scheme
  if( UsePartSteady .and. IsNewSteadySelect &
       .or. UsePartImplicit &                !^CFG IF IMPLICIT
       )then

     ! Redo load balancing: move coordinates and data, there are no new blocks
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
  implicit none
  character(len=*), intent(in) :: TypeSaveIn

  character(len=len(TypeSaveIn)) :: TypeSave
  logical :: DoExchangeAgain, DoAssignNodeNumbers, IsFound
  integer :: iFile
  
  character(len=*), parameter :: NameSub='BATS_save_files'
  logical :: DoSaveRestartTmp
  logical :: IsTimeAccuratePrevious = .false.
  !--------------------------------------------------------------------------

  DoExchangeAgain     = .false.
  DoAssignNodeNumbers = .true.
  TypeSave = TypeSaveIn
  call upper_case(TypeSave)
  select case(TypeSave)
  case('INITIAL')
     ! Do not save for current time step (unless next if statement is true)
     n_output_last=n_step
     if(time_accurate .and. .not.IsTimeAccuratePrevious)then

        ! Save plot and log files at the beginning of a time accurate session

        where(dt_output>0.)
           ! The -1 allows a plot file to be written at the beginning 
           ! of the first time accurate session
           t_output_last=int(time_simulation/dt_output)-1
           n_output_last=n_step-1
        end where

        DoSaveRestartTmp = save_restart_file
        save_restart_file = .false.
        call save_files
        save_restart_file = DoSaveRestartTmp
     else
        ! Do not save for current time
        where(dt_output>0.) t_output_last=int(time_simulation/dt_output)
     end if
     IsTimeAccuratePrevious = time_accurate
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

    do ifile=1,nfile
       if(dn_output(ifile)>=0)then
          if(dn_output(ifile)==0)then
             call save_file
          else if(mod(n_step,dn_output(ifile))==0)then
             call save_file
          end if
       else if(time_accurate .and. dt_output(ifile)>0.)then
          if(int(time_simulation/dt_output(ifile))>t_output_last(ifile))then
             t_output_last(ifile)=int(time_simulation/dt_output(ifile))
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
       call exchange_messages
    end if

  end subroutine save_files

  !===========================================================================

  subroutine save_file
    use ModRestartFile, ONLY: write_restart_files
    use ModParallel, ONLY : UsePlotMessageOptions
    integer :: iFileLoop, iSat

    !
    ! Backup location for the Time_Simulation variable.
    ! Time_Simulation is used in steady-state runs as a loop parameter
    ! in the save_files subroutine, where set_satellite_flags and 
    ! write_logfile are called with different Time_Simulation values
    ! spanning all the satellite trajectory cut. Old Time_Simulation value
    ! is saved here before and it is restored after the loop.
    !
    real :: tSimulationBackup = 0.0


    if(n_step<=n_output_last(ifile) .and. dn_output(ifile)/=0) return

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
       if(index(plot_type(ifile),'ion')>0)then
          if (iProc == 0) then
             call write_myname
             write(*,*)NameSub//' WARNING: only IE can write ion files!'
          end if
          RETURN
       end if

       if(.not.DoExchangeAgain .and. ( &
            index(plot_type(iFile),'lin')==1 .or. &    !^CFG IF RAYTRACE
            index(plot_type(iFile),'los')==1 .or. &
            plot_form(iFile) == 'tec')) then

          if(iProc==0.and.lVerbose>0)then
             call write_prefix; write(iUnitOut,*)&
                  ' Message passing for plot files ...'
          end if
          UsePlotMessageOptions = .true.
          call exchange_messages
          UsePlotMessageOptions = .false.
          DoExchangeAgain = .true.
       end if

       if(index(plot_type(iFile),'los')>0) then
          IsFound = .true.
          call write_plot_los(iFile)
       end if

       !^CFG IF RAYTRACE BEGIN
       if(index(plot_type(iFile),'lin')>0) then
          IsFound = .true.
          call write_plot_line(iFile)
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
    elseif(ifile>satellite_ .and. ifile<=satellite_+nsatellite) then

       ! Case for satellite files
       if(.not.save_satellite_data)return
       iSat=ifile-satellite_
       call timing_start('save_satellite')
       !
       ! Distinguish between time_accurate and .not. time_accurate:
       !
       if (time_accurate) then
          call set_satellite_flags(iSat)
          call write_logfile(iSat,ifile)! write one line for a single trajectory point
       else
          tSimulationBackup = Time_Simulation    ! Save ...
          Time_Simulation = TimeSatStart_I(iSat)
          if (iProc == 0) call close_satellite_output_files(iSat)
          if (iProc == 0) call open_satellite_output_files(iSat)
          do while (Time_Simulation .le. TimeSatEnd_I(iSat))
             call set_satellite_flags(iSat)
             call write_logfile(iSat,ifile)           ! write for ALL the points of trajectory cut
             Time_Simulation = Time_Simulation + dt_output(iSat+Satellite_)
          end do
          Time_Simulation = tSimulationBackup    ! ... Restore
       end if
       call timing_stop('save_satellite')
    end if

    n_output_last(ifile)=n_step

    if(iProc==0 .and. lVerbose>0 .and. (ifile /= logfile_ .and. &
         (.not. (ifile > satellite_ .and. &
         ifile<=satellite_+maxsatellitefile))))then
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

    implicit none

    integer :: iSat

    do ifile=1,plot_+nplotfile
       call save_file
    end do

    !\
    ! Close files
    !/
    if (save_satellite_data .and. iProc==0) then
       do iSat = 1, nSatellite
          call close_satellite_output_files(iSat)
       end do
    end if

    if (save_logfile.and.iProc==0.and.unit_log>0) close(unit_log)

  end subroutine save_files_final

end subroutine BATS_save_files


