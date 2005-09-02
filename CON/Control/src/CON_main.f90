!^CMP COPYRIGHT UM
!===========================================================!
!           SWMF: Space Weather Modeling Framework          |
!                   University of Michigan                  |
!============================================================
!BOP
!MODULE: CON_main - the main methods to drive the SWMF
!INTERFACE:
module CON_main

  !USES:
  use CON_world
  use CON_comp_param
  use CON_wrapper
  use CON_io, ONLY : SaveRestart, save_restart

  use CON_time
  use CON_variables, ONLY: IsStandAlone, iErrorSwmf, lVerbose, DnTiming
  use CON_session
  use ModMpi
  use ModIoUnit, ONLY: UNITTMP_

  implicit none

  private ! except

  !PUBLIC MEMBER FUNCTIONS:
  public :: initialize         ! initialize SWMF
  public :: run                ! run        SWMF
  public :: finalize           ! finalize   SWMF

  !REVISION HISTORY:
  !
  ! This module is a result of a continuous transformation from the main 
  ! program of BATSRUS (developed at the University of Michigan)
  ! into what it is now. Probably not a single line is left untouched
  ! from the original code, but it originates from there.
  !
  ! The transformations were carried out by O.Volberg and G.Toth.
  !
  ! To make the SWMF compatible with the ESMF, the main program is
  ! transformed into a module contining three subroutines
  ! for initialization, running and finalization.
  !
  !EOP

  character (len=*), parameter :: NameSub = 'CON_main'

  !\
  ! Local variable definitions.
  !/
  integer :: lComp, iComp

  logical :: IsLastSession
  logical :: IsFound

  logical :: DoTest, DoTestMe

contains
  !BOP =======================================================================
  !IROUTINE: initialize - initialize the SWMF
  !INTERFACE:
  subroutine initialize(iComm)
    !INPUT ARGUMENTS:
    integer, intent(in), optional :: iComm ! the MPI communicator for the SWMF

    !DESCRIPTION:
    ! The optional argument MPI communicator argument is present only
    ! when the SWMF is not running in stand alone mode.
    ! This subroutine executes the following major steps shown in 
    ! pseudo F90 code
    ! \begin{itemize}
    ! \item Initialize the framework:                         \begin{verbatim}
    !       call world_init                                   \end{verbatim}
    ! \item Read the layout of the components from LAYOUT.in: \begin{verbatim}
    !       call world_setup                                  \end{verbatim}
    ! \item Obtain version information from and provide MPI information to the
    !       components:                                       \begin{verbatim}
    !       do iComp = 1, nComp
    !           call set_param_comp(iComp,"VERSION")
    !           call set_param_comp(iComp,"MPI")
    !       end do                                            \end{verbatim}
    ! \item Show the registered and unregistered components:  \begin{verbatim}
    !       call show_all_comp                                \end{verbatim}
    ! \end{itemize}
    ! The actual code is somewhat longer, since the main code also
    ! deals with timing, deleting the SWMF.STOP and SWMF.SUCCESS files
    ! at the beginning of the run.
    ! There is also some verbose information printed.
    !EOP
    !-------------------------------------------------------------------------
    !\
    ! Initialize control component (MPI)
    !/
    call world_init(iComm)

    !\
    ! Set IsStandAlone variable: 
    ! if the communicator is externally given, 
    ! the SWMF is not running in stand alone mode.
    !/
    IsStandAlone = .not. present(iComm)

    !\
    ! Delete SWMF.SUCCESS and SWMF.STOP files if found
    !/
    if(is_proc0())then

       inquire(file='SWMF.SUCCESS',EXIST=IsFound)
       if(IsFound)then
          open(UNITTMP_, file = 'SWMF.SUCCESS')
          close(UNITTMP_,STATUS = 'DELETE')
       end if

       inquire(file='SWMF.STOP',EXIST=IsFound)
       if (IsFound) then 
          open(UNITTMP_, file = 'SWMF.STOP')
          close(UNITTMP_, STATUS = 'DELETE')
       endif

    end if

    !\
    ! Read component information from LAYOUT.in
    !/
    call world_setup

    !\
    ! Initialize CPU timing
    !/
    CpuTimeStart = MPI_WTIME()

    !\
    ! Read and store version name and number of registered components
    ! initialize the MPI parameters for the registered components
    !/
    do lComp = 1, n_comp()
       iComp=i_comp(lComp)
       call set_param_comp(iComp,"VERSION")
       if(.not.use_comp(iComp))then
          if(is_proc0())then
             write(*,'(a)')'CON_main SWMF_ERROR registered component '// &
                  NameComp_I(iComp)//' is OFF!'
             write(*,'(a)')&
                  'Compile in a working component or remove it from '//&
                  NameMapFile
          end if
          ! stop in a clean fashion (without abort)
          call world_clean
          iErrorSwmf = 3
          RETURN
       end if

       call set_param_comp(iComp,'MPI')     ! Initialize MPI parameters
       call set_param_comp(iComp,'STDOUT')  ! Set prefix string for STDOUT
    end do

    !\
    ! Show framework and component information
    !/
    if(is_proc0())call show_all_comp

    !\
    ! Check for illegal overlap of components with shared source code
    !/
    call check_overlap_comp
    if(iErrorSwmf /= 0) RETURN

    !\
    ! Initialize CON_time
    !/
    call init_time

  end subroutine initialize

  !BOP ========================================================================
  !IROUTINE: run - run the SWMF in multi-session mode
  !INTERFACE:
  subroutine run
    !DESCRIPTION:
    ! Run the SWMF in multi-session mode. The input parameters can be
    ! modified at the beginning of each session. The number of sessions
    ! is defined by the \#RUN commands in the PARAM.in file.
    !EOP
    !BOC
    SESSIONLOOP: do

       !\
       ! Initialize and execute the session
       !/
       call init_session(IsLastSession)
       if(iErrorSwmf /= 0) RETURN

       call do_session(IsLastSession)

       !\
       ! Check if there is anything else to do
       !/
       if(IsLastSession)then
          EXIT SESSIONLOOP
       else
          if(is_proc0().and.lVerbose>=0) &
               write(*,*)'----- End of Session   ',iSession,' ------'
          iSession=iSession+1
          if (DnTiming > -2) call timing_report
          call timing_reset_all
       end if

    end do SESSIONLOOP
    !EOC

  end subroutine run

  !BOP =======================================================================
  !IROUTINE: finalize - finalize the SWMF run
  !INTERFACE:
  subroutine finalize
    !DESCRIPTION:
    ! This subroutine executes the following major steps shown in 
    ! pseudo F90 code
    !\begin{itemize}
    ! \item Save final restart files if required:             \begin{verbatim}
    !    if(SaveRestart % DoThis) call save_restart           \end{verbatim}
    ! \item Finalize components:                              \begin{verbatim}
    !    do iComp=1,nComp
    !        call finalize_comp(iComp,tSimulation)
    !    end do                                               \end{verbatim}
    ! \item Finish the execution:                             \begin{verbatim}
    !    call world_clean                                     \end{verbatim}
    !\end{itemize}
    ! The actual code is longer: verbose information is printed, timing
    ! report is shown and the SWMF.SUCCESS file is written.
    !EOP ---------------------------------------------------------------------

    if(is_proc0())then
       if(lVerbose>=0)then
          write(*,*)
          write(*,'(a)')'    Finished Numerical Simulation'
          write(*,'(a)')'    -----------------------------'
          if (DoTimeAccurate)   write(*, '(a,e13.5,a,f12.6,a,f12.6,a)') &
               '   Simulated Time T = ',tSimulation, &
               ' (',tSimulation/60.00, &
               ' min, ',tSimulation/3600.00,' hrs)'
       end if
    end if
    if (DnTiming > -2) call timing_report

    if(SaveRestart % DoThis) call save_restart
    do lComp = 1,n_comp()
       iComp = i_comp(lComp)
       call finalize_comp(iComp,tSimulation)
    end do

    if(is_proc0().and.lVerbose>0)then
       write(*,*)
       write(*,'(a)')'    Finished Finalizing SWMF'
       write(*,'(a)')'    ------------------------'
    end if

    call timing_stop('SWMF')

    if(DnTiming > -3)call timing_report_total

    !\
    ! Signal normal completion by writing an empty SWMF.SUCCESS file
    !/
    if(is_proc0())then
       open(UNITTMP_, file = 'SWMF.SUCCESS')
       close(UNITTMP_)
    end if

    !\
    ! Stop running
    !/
    call world_clean

  end subroutine finalize

  !BOP ========================================================================
  !IROUTINE: show_all_comp - show version and layout information
  !INTERFACE:
  subroutine show_all_comp

    !USES:
    use CON_variables,  ONLY: VersionSwmf
    use CON_comp_param, ONLY: lNameVersion
    !DESCRIPTION:
    ! Show the version information and layout for all registered components.
    ! Show the version information for all working but unregistered components.
    ! 
    !REVISION HISTORY:
    ! 08/2003 G.Toth <gtoth@umich.edu> - initial version and impovements
    !EOP

    integer, parameter :: lWidth = 77

    logical                      :: IsOn, IsFound
    character (LEN=lNameVersion) :: NameVersion
    real                         :: Version

    integer :: lComp, iComp, iProc0Comp, nProcComp, iStrideComp
    !--------------------------------------------------------------------------
    ! Get and show framework version

    NameVersion  ='SWMF by Univ. of Michigan'

    write(*,'(a)')'#'//repeat('=',lWidth)//'#'
    write(*,'(2a)') &
         '# ID  Version                                               ',&
         'nproc proc0 stride#'
    write(*,'(a)')'#'//repeat('-',lWidth)//'#'
    write(*,'(a,a,f5.2,3i6,a)')&
         '# CON ',NameVersion//' version',VersionSwmf,n_proc(),0,1,' #'
    write(*,'(a)')'#'//repeat('-',lWidth)//'#'

    ! Show registered components
    do lComp = 1,n_comp()
       iComp = i_comp(lComp)

       call get_comp_info(iComp,&
            NameVersion=NameVersion,Version=Version,&
            iProcZero=iProc0Comp, nProc=nProcComp, iProcStride=iStrideComp)

       write(*,'(a,f5.2,3i6,a)')&
            '# '//NameComp_I(iComp)//'  '//NameVersion//' version',Version,&
            nProcComp,iProc0Comp,iStrideComp,' #'
    end do

    ! Show unregistered but compiled (ON) components
    IsFound = .false.
    do iComp=1,MaxComp
       if(use_comp(iComp)) CYCLE ! registered component
       call get_version_comp(iComp,IsOn,NameVersion,Version)
       if(.not.IsOn) CYCLE       ! empty component
       if(.not.IsFound)then
          write(*,'(a)')'#'//repeat('-',lWidth)//'#'
          IsFound=.true.
       end if
       write(*,'(a,f5.2,a)')&
            '# '//NameComp_I(iComp)//'  '//NameVersion//' version',Version,&
            '    not registered #'
    end do
    write(*,'(a)')'#'//repeat('=',lWidth)//'#'
  end subroutine show_all_comp

  !BOP ========================================================================
  !IROUTINE: check_overlap_comp - check if components with the same source code overlap
  !INTERFACE:
  subroutine check_overlap_comp
    !DESCRIPTION:
    ! One may use the same source code for two non-overlapping components.
    ! For example GM and IH may use the same MHD source code. This is indicated
    ! by their NameVersion being the same. When the version names are the same
    ! no overlap is allowed. This suboutine stops with an appropriate error
    ! message if such an overlap occurs.
    !
    !REVISION HISTORY:
    ! 09/10/03 - G.Toth <gtoth@umich.edu> - initial version and prolog
    !EOP

    integer :: lComp, iComp, lComp2, iComp2, iProc, iProcMin, iError
    character (LEN=lNameVersion) :: NameVersion, Nameversion2

    !--------------------------------------------------------------------------
    do lComp=2,n_comp()
       iComp = i_comp(lComp)
       call get_comp_info(iComp,NameVersion=NameVersion)

       do lComp2 = 1, lComp - 1
          iComp2 = i_comp(lComp2)
          call get_comp_info(iComp2,NameVersion=NameVersion2)

          ! Store processor rank for illegal overlap
          if(NameVersion==NameVersion2 .and. &
               is_proc(iComp) .and. is_proc(iComp2)) then
             iProc = i_proc()
          else
             iProc = n_proc()+1
          end if

          ! Let all processors now if there was
          call MPI_allreduce(iProc,iProcMin,1,MPI_INTEGER,MPI_MIN,&
               i_comm(),iError)

          if( iProcMin <= n_proc() )then
             if(is_proc0())then
                write(*,'(a)')'CON_main SWMF_ERROR: Components '// &
                     NameComp_I(iComp)//' and '//NameComp_I(iComp2)
                write(*,'(a)')'CON_main SWMF_ERROR:'//&
                     ' have the same version '//trim(NameVersion)
                write(*,'(a,i3,a)')'CON_main SWMF_ERROR:'//&
                     ' and both components use processor ',iProcMin,' !'
                write(*,'(a)')'CON_main SWMF_ERROR:'// &
                     ' Remove overlap or use different/renamed versions!'
             end if
             call world_clean
             iErrorSwmf = 4
          end if
       end do
    end do

  end subroutine check_overlap_comp

end module CON_main

!===========================================================================
