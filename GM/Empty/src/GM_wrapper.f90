!^CFG COPYRIGHT UM
! Wrapper for the empty Global Magnetosphere (GM) component
!==========================================================================
subroutine GM_set_param(CompInfo, TypeAction)

  use CON_comp_info

  implicit none

  character (len=*), parameter :: NameSub='GM_set_param'

  ! Arguments
  type(CompInfoType), intent(inout) :: CompInfo   ! Information for this comp.
  character (len=*), intent(in)     :: TypeAction ! What to do
  !-------------------------------------------------------------------------
  select case(TypeAction)
  case('VERSION')
     call put(CompInfo,&
          Use        =.false., &
          NameVersion='Empty', &
          Version    =0.0)

  case default
     call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  end select

end subroutine GM_set_param

!==============================================================================

subroutine GM_init_session(iSession, TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  integer,  intent(in) :: iSession         ! session number (starting from 1)
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='GM_init_session'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_init_session

!==============================================================================

subroutine GM_finalize(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='GM_finalize'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_finalize

!==============================================================================

subroutine GM_save_restart(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='GM_save_restart'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_save_restart

!==============================================================================

subroutine GM_run(TimeSimulation,TimeSimulationLimit)

  implicit none

  !INPUT/OUTPUT ARGUMENTS:
  real, intent(inout) :: TimeSimulation   ! current time of component

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  character(len=*), parameter :: NameSub='GM_run'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_run

!==============================================================================
subroutine GM_get_for_im(Buffer_IIV,iSize,jSize,nVar,NameVar)
  implicit none

  integer, intent(in) :: iSize,jSize,nVar
  real, intent(out), dimension(iSize,jSize,nVar) :: Buffer_IIV
  character (len=*), intent(in) :: NameVar

  character (len=*), parameter :: NameSub='GM_get_for_im'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
end subroutine GM_get_for_im

!==============================================================================

subroutine GM_get_for_rb_trace(iSize,jSize,NameVar,nVarLine,nPointLine)
  implicit none

  integer, intent(in) :: iSize,jSize
  character (len=*), intent(in) :: NameVar
  integer, intent(out):: nVarLine,nPointLine

  character (len=*), parameter :: NameSub='GM_get_for_rb_trace'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
end subroutine GM_get_for_rb_trace

!==============================================================================

subroutine GM_get_for_rb(Buffer_IIV,iSize,jSize,nVar, &
     BufferLine_VI, nVarLine, nPointLine)

  implicit none

  integer, intent(in) :: iSize,jSize,nVar
  real, intent(out)   :: Buffer_IIV(iSize,jSize,nVar)
  integer, intent(in) :: nVarLine, nPointLine
  real, intent(out)   :: BufferLine_VI(nVarLine, nPointLine)

  character (len=*), parameter :: NameSub='GM_get_for_rb'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
end subroutine GM_get_for_rb

!==============================================================================

subroutine GM_get_for_ie(Buffer_IIV,iSize,jSize,nVar,NameVar)
  implicit none

  integer, intent(in) :: iSize,jSize,nVar
  real, intent(out), dimension(iSize,jSize,nVar) :: Buffer_IIV
  character (len=*), intent(in) :: NameVar

  character (len=*), parameter :: NameSub='GM_get_for_ie'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
end subroutine GM_get_for_ie

!==============================================================================

subroutine GM_put_from_im(Buffer_II,iSizeIn,jSizeIn,NameVar)
  implicit none

  integer, intent(in) :: iSizeIn,jSizeIn
  real, intent(in) :: Buffer_II(iSizeIn,jSizeIn)
  character(len=*), intent(in) :: NameVar

  character(len=*), parameter :: NameSub='GM_put_from_im'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
end subroutine GM_put_from_im

!==============================================================================

subroutine GM_put_from_ie(Buffer_II,iSize,jSize,NameVar)

  implicit none

  character(len=*), parameter :: NameSub='GM_put_from_ie'

  integer, intent(in) :: iSize,jSize
  real, intent(in) :: Buffer_II(iSize,jSize)
  character(len=*), intent(in) :: NameVar

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_put_from_ie

!=============================================================================

! This function is only needed because of IH/BATSRUS/src/write_logfile
real function logvar_ionosphere()
  call CON_stop('logvar_ionosphere: GM_ERROR: empty version cannot be used!')
  logvar_ionosphere = -777.77
end function logvar_ionosphere

!=============================================================================

! This subroutine is only needed because of SC|IH/BATSRUS/src/set_BCs.f90
subroutine calc_inner_bc_velocity
  call CON_stop('calc_inner_bc_velocity: '// &
       'GM_ERROR: empty version cannot be used!')
end subroutine calc_inner_bc_velocity

!==============================================================================

subroutine GM_print_variables(NameSource)

  implicit none

  character(len=*), parameter :: NameSub='GM_print_variables'

  character(len=*), intent(in) :: NameSource

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_print_variables

!==============================================================================

subroutine GM_synchronize_refinement(iProc0,iCommUnion)

  implicit none
  integer,intent(in) :: iProc0,iCommUnion
  character(len=*), parameter :: NameSub='GM_synchronize_refinement'
  
  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_synchronize_refinement

!==============================================================================

subroutine GM_put_from_ih(nPartial,iPutStart,Put,Weight,DoAdd,StateSI_V,&
     nVar)

  ! Derived type arguments, it is easier not to declare them
  character(len=*), parameter :: NameSub='GM_put_from_ih'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_put_from_ih

!==============================================================================

subroutine GM_put_from_ih_buffer( &
     NameCoord, nY, nZ, yMin, yMax, zMin, zMax, Buffer_VII)

  character(len=*), intent(in) :: NameCoord
  integer,          intent(in) :: nY, nZ
  real,             intent(in) :: yMin, yMax, zMin, zMax
  real,             intent(in) :: Buffer_VII(8, nY, nZ)

  character(len=*), parameter :: NameSub='GM_put_from_ih_buffer'
  
  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine GM_put_from_ih_buffer

!==============================================================================

! This subroutine is only needed because of SC|IH/BATSRUS/src/set_outer_BCs.f90
subroutine read_ih_buffer(y, z, State_V)

  real, intent(in) :: y, z
  real, intent(out):: State_V(8)
  character(len=*), parameter :: NameSub='read_ih_buffer'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine read_ih_buffer

!==============================================================================

subroutine GM_put_from_pw(Buffer_VI, nVar, nFieldLine, Name_V)

  implicit none
  character (len=*),parameter :: NameSub='GM_put_from_pw'
  
  integer, intent(in)           :: nVar, nFieldLine
  real, intent(out)             :: Buffer_VI(nVar, nFieldLine)
  character (len=*), intent(in) :: Name_V(nVar)

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  
end subroutine GM_put_from_pw
!==============================================================================

subroutine GM_get_for_pw(nTotalLine,p_I)

  implicit none
  character (len=*),parameter :: NameSub='GM_get_for_pw'
  
  integer, intent(in)           :: nTotalLine
  real, intent(out)             :: p_I(nTotalLine)


  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  
end subroutine GM_get_for_pw

!==============================================================================

! This subroutine is only needed because of SC|IH/BATSRUS/src/set_BCs.f90
subroutine read_pw_buffer(FaceCoords_D,nVar,FaceState_V)

  implicit none
  character (len=*),parameter :: NameSub='read_pw_buffer'

  real, intent(in) :: FaceCoords_D(3)
  integer, intent(in) :: nVar
  real, intent(inout) :: FaceState_V(nVar)

  call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

end subroutine read_pw_buffer
