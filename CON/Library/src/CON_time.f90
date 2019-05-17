!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!
!QUOTE: \clearpage
!
!BOP
!
!QUOTE: \section{CON/Library: Shared by CON and Components}
!
!MODULE: CON_time - time related variables of CON
!
!DESCRIPTION:
! This module contains the time related variables of SWMF such
! as current and maximum time step and simulation time, or maximum
! CPU time allowed, etc.

!INTERFACE:
module CON_time

  !USES:
  use ModKind, ONLY: Real8_
  use ModFreq                 !!, ONLY: FreqType
  use ModTimeConvert          !!, ONLY: time_int_to_real, TimeType
  use CON_comp_param, ONLY: MaxComp

  implicit none

  save

  !PUBLIC MEMBER FUNCTIONS:
  public :: init_time        ! Initialize start time
  public :: get_time         ! Access time related variables

  !PUBLIC DATA MEMBERS:

  ! The session index starting with 1
  integer :: iSession = 1

  ! Is this a time accurate run?
  logical :: DoTimeAccurate=.true.

  ! Number of time steps/iterations from the beginning
  integer :: nStep=0

  ! Number of time steps/iterations since last restart
  integer :: nIteration=0

  ! Maximum number of iterations since last restart
  integer :: MaxIteration=0

  ! How often a component should run
  integer :: DnRun_C(MaxComp) = 1

  ! Initial date/time
  type(TimeType) :: TimeStart

  ! Date/time to finish the simulation
  type(TimeType) :: TimeEnd
  
  ! Is the end time set and to be saved into the final restart file
  logical :: UseEndTime = .false.

  ! Simulation time
  real :: tSimulation = 0.0

  ! Maximum simulation time
  real :: tSimulationMax = 0.0

  ! Maximum CPU time
  real(Real8_) :: CpuTimeStart    ! Initial value returned by MPI_WTIME
  real(Real8_) :: CpuTimeSetup    ! Setup time returned by MPI_WTIME
  real :: CpuTimeMax = -1.0       ! Maximum time allowed for the run

  ! Shall we check for the stop file?
  logical :: DoCheckStopFile = .true.

  ! How often shall we check cpu time and stop file. Default is never.
  type(FreqType):: CheckStop = FreqType(.false., -1, -1.0, 0, 0.0)

  ! Did the code stop due to a stop condition?
  logical :: IsForcedStop = .false.

  ! Name of component checking for the kill file
  character(len=2):: NameCompCheckKill = '!!'

  !REVISION HISTORY:
  ! 01Aug03 Aaron Ridley and G. Toth - initial implementation
  ! 22Aug03 G. Toth - added TypeFreq and is_time_to function
  ! 25Aug03 G. Toth - added adjust_freq subroutine
  ! 23Mar04 G. Toth - split CON_time into ModTime, ModFreq and CON_time
  ! 26Mar04 G. Toth - added get_time access method
  ! 25May04 G. Toth - added DnRun_C for steady state runs and
  !                   removed TimeCurrent variable
  ! 22Jun15 G. Toth - added NameCompCheckKill variable
  !EOP

  character(len=*), parameter, private :: NameMod='CON_time'

contains

  !BOP ========================================================================
  !IROUTINE: init_time - initialize start time
  !INTERFACE:
  subroutine init_time
    !EOP
    character (len=*), parameter :: NameSub = NameMod//'::init_time'

    !BOC
    TimeStart % iYear   = 2000
    TimeStart % iMonth  = 3
    TimeStart % iDay    = 21
    TimeStart % iHour   = 10
    TimeStart % iMinute = 45
    TimeStart % iSecond = 0
    TimeStart % FracSecond = 0.0

    call time_int_to_real(TimeStart)

    TimeEnd % iYear   = 2000
    TimeEnd % iMonth  = 3
    TimeEnd % iDay    = 21
    TimeEnd % iHour   = 10
    TimeEnd % iMinute = 45
    TimeEnd % iSecond = 0
    TimeEnd % FracSecond = 0.0

    call time_int_to_real(TimeEnd)
    !EOC

  end subroutine init_time

  !BOP ========================================================================
  !IROUTINE: get_time - get time related parameters
  !INTERFACE:
  subroutine get_time(&
       DoTimeAccurateOut, tSimulationOut, TimeStartOut, TimeCurrentOut, &
       TimeEndOut, tStartOut, tCurrentOut, nStepOut)

    !OUTPUT ARGUMENTS:
    logical,          optional, intent(out) :: DoTimeAccurateOut
    real,             optional, intent(out) :: tSimulationOut
    type(TimeType),   optional, intent(out) :: TimeStartOut
    type(TimeType),   optional, intent(out) :: TimeCurrentOut
    type(TimeType),   optional, intent(out) :: TimeEndOut
    real(Real8_),     optional, intent(out) :: tStartOut
    real(Real8_),     optional, intent(out) :: tCurrentOut
    integer,          optional, intent(out) :: nStepOut
    !EOP
    !-------------------------------------------------------------------------

    if(present(DoTimeAccurateOut)) DoTimeAccurateOut = DoTimeAccurate
    if(present(tSimulationOut))    tSimulationOut    = tSimulation
    if(present(TimeStartOut))      TimeStartOut      = TimeStart
    if(present(tStartOut))         tStartOut         = TimeStart % Time
    if(present(nStepOut))          nStepOut          = nStep
    if(present(TimeEndOut))        TimeEndOut        = TimeEnd
    if(present(tCurrentOut))       tCurrentOut = TimeStart % Time + tSimulation
    if(present(TimeCurrentOut))then
       TimeCurrentOut % Time = TimeStart % Time + tSimulation
       call time_real_to_int(TimeCurrentOut)
    end if

  end subroutine get_time
  !BOP ========================================================================
  !IROUTINE: save_end_time - save TimeEnd instead of TimeStart and tSimulation
  !INTERFACE:
  subroutine save_end_time

    ! Set TimeStart to TimeEnd and set simulation time to zero
    ! Also set nStep to zero. These will be saved into RESTART.out

    !EOP
    !-------------------------------------------------------------------------

    TimeStart = TimeEnd
    tSimulation = 0
    nStep       = 0

  end subroutine save_end_time

end module CON_time
