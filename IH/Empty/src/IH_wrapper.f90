!^CFG COPYRIGHT UM
! Wrapper for an "empty" Inner Heliosphere (IH) component
!==========================================================================
subroutine IH_set_param(CompInfo, TypeAction)

  use CON_comp_info

  implicit none

  character (len=*), parameter :: NameSub='IH_set_param'

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
     call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end select

end subroutine IH_set_param

!==============================================================================

subroutine IH_init_session(iSession, TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  integer,  intent(in) :: iSession         ! session number (starting from 1)
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='IH_init_session'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_init_session

!==============================================================================

subroutine IH_finalize(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='IH_finalize'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_finalize

!==============================================================================

subroutine IH_save_restart(TimeSimulation)

  implicit none

  !INPUT PARAMETERS:
  real,     intent(in) :: TimeSimulation   ! seconds from start time

  character(len=*), parameter :: NameSub='IH_save_restart'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_save_restart

!==============================================================================

subroutine IH_run(TimeSimulation,TimeSimulationLimit)

  implicit none

  !INPUT/OUTPUT ARGUMENTS:
  real, intent(inout) :: TimeSimulation   ! current time of component

  !INPUT ARGUMENTS:
  real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

  character(len=*), parameter :: NameSub='IH_run'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_run

!===============================================================

subroutine IH_synchronize_refinement(iProc0,iCommUnion)

  implicit none
  integer, intent(in) ::iProc0,iCommUnion
  character(len=*), parameter :: NameSub='IH_synchronize_refinement'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_synchronize_refinement

!===============================================================

subroutine IH_get_for_gm(&
     nPartial,iGetStart,Get,W,State_V,nVar,TimeCoupling)

  ! derived type parameters, it is easier not to declare them
  character(len=*), parameter :: NameSub='IH_get_for_gm'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

end subroutine IH_get_for_gm

subroutine IH_get_for_sc(&
     nPartial,iGetStart,Get,W,State_V,nVar,TimeCoupling)
! derived type parameters, it is easier not to declare them
  character(len=*), parameter :: NameSub='IH_get_for_sc'

  call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
end subroutine IH_get_for_sc
