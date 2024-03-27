module SwmfGridCompMod

  ! This is the SWMF Gridded Component, which acts as an interface
  ! to the SWMF.

  ! ESMF Framework module
  use ESMF

  use ESMF_SWMF_Mod, ONLY: &
       DoRunSwmf, DoBlockAllSwmf, &
       NameSwmfComp, iProc0SwmfComp, iProcLastSwmfComp, &
       NameFieldEsmf_V, nVarEsmf, &
       Year_, Month_, Day_, Hour_, Minute_, Second_, MilliSec_, &
       add_fields, &
       DoTest, FieldTest_V, CoordCoefTest, dHallPerDtTest

  ! Size of ionosphere grid in SWMF/IE model
  use IE_ModSize, ONLY: nLat => IONO_nTheta, nLon => IONO_nPsi
  ! Conversion to radians
  use ModNumConst, ONLY: cDegToRad

  implicit none

  private

  public:: SetServices

  ! Local variables

  ! Grid related to the SWMF Ridley Ionosphere Model
  ! This is a 2D spherical grid representing the height integrated ionosphere.
  ! RIM is in SM coordinates (aligned with Sun-Earth direction):
  ! +Z points to north magnetic dipole and the Sun is in the +X-Z halfplane.

  ! Domain of SWMF/IE grid (in reality it is Colat based)
  real(ESMF_KIND_R8), parameter:: LonMin =    0.0 ! Min longitude
  real(ESMF_KIND_R8), parameter:: LonMax = +360.0 ! Max longitude
  real(ESMF_KIND_R8), parameter:: LatMin =  -90.0 ! Min latitude
  real(ESMF_KIND_R8), parameter:: LatMax =  +90.0 ! Max latitude

  ! Coordinate arrays
  real(ESMF_KIND_R8), pointer, save:: Lon_I(:), Lat_I(:)

  integer:: MinLon = 0, MaxLon = 0, MinLat = 0, MaxLat = 0
  
contains
  !============================================================================
  subroutine SetServices(gcomp, rc)
    type(ESMF_GridComp) :: gcomp
    integer, intent(out):: rc

    call ESMF_GridCompSetEntryPoint(gcomp, ESMF_METHOD_INITIALIZE, &
         userRoutine=my_init, rc=rc)
    call ESMF_GridCompSetEntryPoint(gcomp, ESMF_METHOD_RUN, &
         userRoutine=my_run, rc=rc)
    call ESMF_GridCompSetEntryPoint(gcomp, ESMF_METHOD_FINALIZE, &
         userRoutine=my_final, rc=rc)

  end subroutine SetServices
  !============================================================================
  subroutine my_init(gcomp, importState, exportState, externalclock, rc)

    type(ESMF_GridComp) :: gcomp
    type(ESMF_State) :: importState
    type(ESMF_State) :: exportState
    type(ESMF_Clock) :: externalclock
    integer, intent(out):: rc

    logical          :: IsLastSession ! true if SWMF has a single session
    type(ESMF_VM)    :: Vm
    type(ESMF_Grid)  :: Grid
    integer          :: iComm, iProc
    type(ESMF_Time)  :: StartTime
    integer          :: iStartTime_I(Year_:Millisec_)
    type(ESMF_TimeInterval) :: SimTime, RunDuration
    integer(ESMF_KIND_I4)   :: iSecond, iMilliSec
    real(ESMF_KIND_R8)      :: TimeSim, TimeStop

    !--------------------------------------------------------------------------
    call ESMF_LogWrite("SWMF_GridComp:init routine called", ESMF_LOGMSG_INFO)
    rc = ESMF_FAILURE

    ! RIM grid is node based. Internally it is Colat-Lon grid, but we pretend
    ! here that it is a Lat-Lon grid, so ESMF can use it.
    ! Lon from 0 to 360-dPhi (periodic), Lat from -90 to +90
    Grid = ESMF_GridCreate1PeriDimUfrm(maxIndex=[nLon-1,nLat-1], &
         minCornerCoord=[LonMin, LatMin], &
         maxCornerCoord=[LonMax, LatMax], &
         staggerLocList=[ESMF_STAGGERLOC_CORNER, ESMF_STAGGERLOC_CORNER], &
         name="SWMF grid", rc=rc)
    if(rc /= ESMF_SUCCESS)call	my_error('ESMF_GridCreate1PeriDimUfrm')

    nullify(Lon_I)
    call ESMF_GridGetCoord(Grid, coordDim=1, &
         staggerloc=ESMF_STAGGERLOC_CORNER, farrayPtr=Lon_I, rc=rc)
    if(rc /= ESMF_SUCCESS)call	my_error('ESMF_GridGetCoord 1')
    MinLon = lbound(Lon_I, DIM=1); MaxLon = ubound(Lon_I, DIM=1)
    write(*,'(a,2i4)')'SWMF grid: MinLon, MaxLon=', MinLon, MaxLon
    if(MaxLon > MinLon) write(*,'(a,3f8.2)') &
         'SWMF grid: Lon_I(Min,Min+1,Max)=', Lon_I([MinLon,MinLon+1,MaxLon])
    nullify(Lat_I)
    call ESMF_GridGetCoord(Grid, coordDim=2, &
         staggerloc=ESMF_STAGGERLOC_CORNER, farrayPtr=Lat_I, rc=rc)
    if(rc /= ESMF_SUCCESS)call	my_error('ESMF_GridGetCoord 2')
    MinLat = lbound(Lat_I, DIM=1); MaxLat = ubound(Lat_I, DIM=1)
    write(*,'(a,2i4)')'SWMF grid: MinLat, MaxLat=', MinLat, MaxLat
    if(MaxLat > MinLat) write(*,'(a,3f8.2)') &
         'SWMF grid: Lat_I(1,2,last)=', Lat_I([MinLat,MinLat+1,MaxLat])

    ! Add ESMF fields to the SWMF import state
    call add_fields(Grid, ImportState, IsFromEsmf=.true., rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('add_fields')
    
    ! Obtain the VM for the SWMF gridded component
    call ESMF_GridCompGet(gComp, vm=Vm, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_GridCompGet')

    ! Obtain the MPI communicator for the VM
    call ESMF_VMGet(Vm, mpiCommunicator=iComm, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_VMGet')

    ! Obtain the start time from the clock 
    call ESMF_ClockGet(externalclock, startTime=StartTime, &
         currSimTime=SimTime, runDuration=RunDuration, rc=rc)
    if(rc /= ESMF_SUCCESS) call	my_error('ESMF_ClockGet')

    call ESMF_TimeGet(StartTime,   &
         yy=iStartTime_I(Year_),   &
         mm=iStartTime_I(Month_),  &
         dd=iStartTime_I(Day_),    &
         h =iStartTime_I(Hour_),   &
         m =iStartTime_I(Minute_), &
         s =iStartTime_I(Second_), &
         ms=iStartTime_I(Millisec_), &
         rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_TimeGet')

    ! Obtain the simulation time from the clock
    call ESMF_TimeIntervalGet(SimTime, s=iSecond, ms=iMillisec, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_TimeIntervalGet Sim')
    TimeSim = iSecond + iMillisec/1000.0

    ! Obtain the final simulation time from the clock
    call ESMF_TimeIntervalGet(RunDuration, s=iSecond, ms=iMillisec, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_TimeIntervalGet Run')
    TimeStop = iSecond + iMillisec/1000.0

    ! Initialze the SWMF with this MPI communicator and start time
    call ESMF_LogWrite("SWMF_initialize routine called", ESMF_LOGMSG_INFO)
    call SWMF_initialize(iComm, iStartTime_I, &
         TimeSim, TimeStop, IsLastSession, rc)
    call ESMF_LogWrite("SWMF_initialize routine returned", ESMF_LOGMSG_INFO)
    if(rc /= 0)call my_error('SWMF_initialize')
    
    rc = ESMF_SUCCESS
    call ESMF_LogWrite("SWMF_GridComp:init routine returned", ESMF_LOGMSG_INFO)

  end subroutine my_init
  !============================================================================
  subroutine my_run(gComp, ImportState, ExportState, Clock, rc)

    type(ESMF_GridComp):: gComp
    type(ESMF_State):: ImportState
    type(ESMF_State):: ExportState
    type(ESMF_Clock):: Clock
    integer, intent(out):: rc

    ! Access to the data
    real(ESMF_KIND_R8), pointer     :: Ptr(:,:)
    real(ESMF_KIND_R8), allocatable :: Data_VII(:,:,:)
    integer                         :: iVar

    ! Access to time
    type(ESMF_TimeInterval) :: SimTime, TimeStep
    integer(ESMF_KIND_I4)   :: iSec, iMilliSec

    ! Parameters for the SWMF_run interface
    logical            :: DoStop            ! true if SWMF requests a stop
    real(ESMF_KIND_R8) :: tCurrent, tCouple ! Current and next coupling times
    real(ESMF_KIND_R8) :: tSimSwmf          ! SWMF Simulation time

    ! Misc variables
    type(ESMF_Field):: Field
    character(len=4):: NameField
    type(ESMF_VM):: Vm
    integer:: iProc, i, j
    real(ESMF_KIND_R8):: Exact_V(2)
    !--------------------------------------------------------------------------
    call ESMF_LogWrite("SWMF_GridComp:run routine called", ESMF_LOGMSG_INFO)
    rc = ESMF_FAILURE

    ! Get processor rank
    call ESMF_GridCompGet(gComp, vm=vm, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_GridCompGet')
    call ESMF_VMGet(vm, localPET=iProc, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_VMGet')

    ! Get the current time from the clock
    call ESMF_ClockGet(Clock, CurrSimTime=SimTime, TimeStep=TimeStep, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_ClockGet')
    call ESMF_TimeIntervalGet(SimTime, s=iSec, ms=iMilliSec, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_TimeIntervalGet current')
    tCurrent = iSec + 0.001*iMilliSec

    ! Calculate simulation time for next coupling
    SimTime = SimTime + TimeStep
    call ESMF_TimeIntervalGet(SimTime, s=iSec, ms=iMilliSec, rc=rc)
    if(rc /= ESMF_SUCCESS) call my_error('ESMF_TimeIntervalGet couple')
    tCouple = iSec + 0.001*iMilliSec
    
    if(iProc >= iProc0SwmfComp .and. iProc <= iProcLastSwmfComp)then
       ! Obtain pointer to the data obtained from the ESMF component
       allocate(Data_VII(nVarEsmf,MinLon:MaxLon,MinLat:MaxLat), stat=rc)
       if(rc /= 0) call my_error('allocate(Data_VII)')

       ! Copy fields into an array
       do iVar = 1, nVarEsmf
          nullify(Ptr)
          NameField = NameFieldEsmf_V(iVar)
          call ESMF_StateGet(ImportState, itemName=NameField, &
               field=Field, rc=rc)
          if(rc /= ESMF_SUCCESS) call my_error("ESMF_StateGet")
          call ESMF_FieldGet(Field, farrayPtr=Ptr, rc=rc) 
          if(rc /= ESMF_SUCCESS) call my_error("ESMF_FieldGet")

          Data_VII(iVar,:,:) = Ptr
       end do
       if(DoTest)then
          write(*,*)'SWMF_GridComp shape of Ptr =', shape(Ptr)
          ! Do not check the poles
          do j = MinLat, MaxLat; do i = MinLon, MaxLon
             ! Calculate exact solution
             Exact_V = FieldTest_V
             ! add time dependence for Hall field
             Exact_V(1) = Exact_V(1) + tCurrent*dHallPerDtTest
             ! add spatial dependence
             Exact_V = Exact_V + CoordCoefTest &
                  *sin(Lon_I(i)*cDegToRad)*cos(Lat_I(j)*cDegToRad)
             if(abs(Data_VII(1,i,j) - Exact_V(1)) > 1e-4) &
                  write(*,*) 'ERROR in SWMF_GridComp ', &
                  'at i, j, Lon, Lat, Hall, Exact, Error=', &
                  i, j, Lon_I(i), Lat_I(j), Data_VII(1,i,j), &
                  Exact_V(1), Data_VII(1,i,j) - Exact_V(1)
             if(abs(Data_VII(2,i,j) - Exact_V(2)) > 1e-4) &
                  write(*,*) 'ERROR in SWMF_GridComp ', &
                  'at i, j, Lon, Lat, Pede, Exact, Error=', &
                  i, j, Lon_I(i), Lat_I(j), Data_VII(2,i,j), &
                  Exact_V(2), Data_VII(2,i,j) - Exact_V(2)
          end do; end do
          write(*,*)'SWMF_GridComp value of Data(MidLon,MidLat)=', &
               Data_VII(:,(MinLon+MaxLon)/2,(MinLat+MaxLat)/2)
       end if
       deallocate(Data_VII)
    end if

    ! Send the data to the processors in the SWMF
    ! This should not be necessary. We should have pointers instead.
    !call SWMF_couple('ESMF_IPE', NameSwmfComp, 'SMG', &
    !     nVarEsmf, nLon-1, nLat, 0.0, 360.0, -90.0, 90.0, Data_VII, rc)
    !if(rc /= 0)call my_error('SWMF_couple')

    call ESMF_LogWrite("SWMF_run routine called!", ESMF_LOGMSG_INFO)
    write(*,*)'SWMF_run starts  with tCouple =',tCouple
    if(.not.DoRunSwmf)then
       ! Pretend that SWMF reached the coupling time
       tSimSwmf = tCouple
       rc = 0
    elseif(DoBlockAllSwmf)then
       call SWMF_run('**', tCouple, tSimSwmf, DoStop, rc)
    else
       call SWMF_run(NameSwmfComp, tCouple, tSimSwmf, DoStop, rc)
    end if
    write(*,*)'SWMF_run returns with tSimSwmf=', tSimSwmf
    call ESMF_LogWrite("SWMF_run routine returned!", ESMF_LOGMSG_INFO)
    if(rc /= 0)call my_error('SWMF_run')
    
    call ESMF_LogWrite("SWMF_GridComp:run routine returned", ESMF_LOGMSG_INFO)

    rc = ESMF_SUCCESS

  end subroutine my_run
  !============================================================================
  subroutine my_final(gcomp, importState, exportState, externalclock, rc)

    type(ESMF_GridComp) :: gcomp
    type(ESMF_State) :: importState
    type(ESMF_State) :: exportState
    type(ESMF_Clock) :: externalclock
    integer, intent(out) :: rc

    type(ESMF_VM)    :: vm
    integer          :: iProc
    !--------------------------------------------------------------------------
    call ESMF_LogWrite("SWMF_finalize routine called", ESMF_LOGMSG_INFO)

    call SWMF_finalize(rc)
    call ESMF_LogWrite("SWMF_finalize routine returned", ESMF_LOGMSG_INFO)
    if(rc /= 0)then
       call ESMF_LogWrite("SWMF_finalize FAILED", ESMF_LOGMSG_ERROR)
       call ESMF_VMGet(vm, localPET=iProc)
       if(iProc == 0)write(0, *) "SWMF_finalize FAILED"
       rc = ESMF_FAILURE
    endif
    
  end subroutine my_final
  !============================================================================
  subroutine my_error(String)

    ! Write out error message and stop
    
    character(len=*), intent(in) :: String
    !--------------------------------------------------------------------------
    write(*,*)'ERROR in SwmfGridCompMod: ', String
    
    call ESMF_Finalize

  end subroutine my_error
  !============================================================================
end module SwmfGridCompMod


