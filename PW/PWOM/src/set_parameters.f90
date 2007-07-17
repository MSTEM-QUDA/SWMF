subroutine PW_set_parameters(NameAction)

  use ModIoUnit, ONLY: UnitTmp_, io_unit_new
  use ModPwom
  use ModReadParam
  implicit none

  character (len=100)           :: NameCommand
  character (len=*), intent(in) :: NameAction
  character (len=*), parameter  :: NameSub = 'PW_set_parameters'

  !****************************************************************************
  ! This subroutine gets the inputs for PWOM
  !****************************************************************************

  real:: ddt1, xxx
  integer:: ns
  !---------------------------------------------------------------------------
  
  do
     if(.not.read_line() ) EXIT
     if(.not.read_command(NameCommand)) CYCLE
     select case(NameCommand)
     case('#STOP')
        if(IsStandAlone)then
           call read_var('Tmax',Tmax)
        else
           write(*,*)'PWOM WARNING: #STOP command is ignored in the framework'
        end if
     case('#SAVEPLOT')
        call read_var('DtSavePlot',DtOutput)
        call read_var('SaveFirst',DoSavePlot)
     case('#SAVEPLOTELECTRODYNAMICS')
        call read_var('DoPlotElectrodynamics',DoPlotElectrodynamics)
        call read_var('DtPlotElectrodynamics',DtPlotElectrodynamics)
     case('#SCHEME')
        call read_var('TypeSolver',TypeSolver)
        call read_var('DtVertical',DtVertical)
        call read_var('IsFullyImplicit'   ,IsFullyImplicit)
        if(IsFullyImplicit)then
           IsPointImplicit = .false.
           IsPointImplicitAll = .false.
        else
           call read_var('IsPointImplicit'   ,IsPointImplicit)
           call read_var('IsPointImplicitAll',IsPointImplicitAll)
        end if
     case('#RESTART')
        call read_var('IsRestart',IsRestart)
     case('#MOTION')
        call read_var('DoMoveLine',DoMoveLine)
     case('#FAC')
        call read_var('UseJr',UseJr)
     case('#ROTATION')
        call read_var('UseCentrifugal',UseCentrifugal)
     case('#TIMESTEP')
        call read_var('DtHorizontal',DtHorizontal)
        DtHorizontalOrig = DtHorizontal
     case('#VERTICALGRID')
        call read_var('nPoints',nAlt)
     case('#FIELDLINE')
        call read_var('nTotalLine',nTotalLine)
     case('#LOG')
        call read_var('WriteLog',nLog) ! nLog=-1 write for all lines
                                       ! nLog= 0 write for no lines
                                       ! nLog= 1..nTotalLine, write one line
     case('#TEST')
        call read_var('StringTest',StringTest)
        call read_var('iProcTest', iProcTest)
        call read_var('iLinetest', iLineTest)
     endselect


  enddo
  

end subroutine PW_set_parameters
