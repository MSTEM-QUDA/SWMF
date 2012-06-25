!^CFG COPYRIGHT UM
!==============================================================================
module ModUserEmpty

  ! This module contains empty user routines.  They should be "used" 
  ! (included) in the srcUser/ModUser*.f90 files for routines that the user 
  ! does not wish to implement.

  implicit none

  private :: stop_user

contains

  !=====================================================================
  subroutine user_set_boundary_cells(iBlock)

    integer,intent(in)::iBlock

    character(len=*), parameter :: NameSub = 'user_set_boundary_cells'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_set_boundary_cells

  !=====================================================================
  subroutine user_set_face_boundary(VarsGhostFace_V)

    use ModAdvance, ONLY: nVar

    real, intent(out):: VarsGhostFace_V(nVar)

    character(len=*), parameter :: NameSub = 'user_set_face_boundary' 
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_set_face_boundary

  !=====================================================================
  subroutine user_set_cell_boundary(iBlock,iSide, TypeBc, IsFound)

    integer,          intent(in)  :: iBlock, iSide
    character(len=20),intent(in)  :: TypeBc
    logical,          intent(out) :: IsFound

    character(len=*), parameter :: NameSub = 'user_set_cell_boundary'
    !-------------------------------------------------------------------
    IsFound = .false.
    call stop_user(NameSub)
  end subroutine user_set_cell_boundary

  !=====================================================================
  subroutine user_initial_perturbation
    use ModMain,ONLY: nBlockMax
    character(len=*), parameter :: NameSub = 'user_initial_perturbation'
    integer::iBlock
    !-------------------------------------------------------------------
    !The routine is called once and should be applied for all blocks, the 
    !do-loop should be present. Another distinction from user_set_ics is that 
    !user_initial_perturbation can be applied after restart, while
    !user_set_ICs cannot.

    do iBlock = 1, nBlockMax
    
       call stop_user(NameSub)
    end do
  end subroutine user_initial_perturbation

  !=====================================================================
  subroutine user_set_ics(iBlock)

    integer, intent(in) :: iBlock

    character(len=*), parameter :: NameSub = 'user_set_ics'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_set_ics

  !=====================================================================
  subroutine user_init_session

    character(len=*), parameter :: NameSub = 'user_init_session'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_init_session

  !=====================================================================
  subroutine user_action(NameAction)

    character(len=*), intent(in):: NameAction

    character(len=*), parameter :: NameSub = 'user_action'
    !-------------------------------------------------------------------
    !select case(NameAction)
    !case('initial condition done')
    !  ...
    !case('write progress')
    !  ...
    !end select

  end subroutine user_action
  !=====================================================================
  subroutine user_specify_refinement(iBlock, iArea, DoRefine)

    integer, intent(in) :: iBlock, iArea
    logical,intent(out) :: DoRefine

    character(len=*), parameter :: NameSub = 'user_specify_refinement'
    !-------------------------------------------------------------------
    
    ! Can ONLY depend om geometric criteias, only called when grid change

    call stop_user(NameSub)
  end subroutine user_specify_refinement

  !=====================================================================
  subroutine user_amr_criteria(iBlock, UserCriteria, TypeCriteria, IsFound)

    integer, intent(in)          :: iBlock
    real, intent(out)            :: UserCriteria
    character(len=*),intent(in) :: TypeCriteria
    logical, intent(inout)       :: IsFound

    character(len=*), parameter :: NameSub = 'user_amr_criteria'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_amr_criteria

  !=====================================================================
  subroutine user_read_inputs

    character(len=*), parameter :: NameSub = 'user_read_inputs'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_read_inputs

  !=====================================================================
  subroutine user_get_log_var(VarValue, TypeVar, Radius)

    real, intent(out)            :: VarValue
    character(len=*), intent(in):: TypeVar
    real, intent(in), optional :: Radius

    character(len=*), parameter :: NameSub = 'user_get_log_var'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_get_log_var

  !====================================================================

  subroutine user_set_plot_var(iBlock, NameVar, IsDimensional, &
       PlotVar_G, PlotVarBody, UsePlotVarBody, &
       NameTecVar, NameTecUnit, NameIdlUnit, IsFound)

    use ModSize, ONLY: nI, nJ, nK

    integer,          intent(in)   :: iBlock
    character(len=*), intent(in)   :: NameVar
    logical,          intent(in)   :: IsDimensional
    real,             intent(out)  :: PlotVar_G(-1:nI+2, -1:nJ+2, -1:nK+2)
    real,             intent(out)  :: PlotVarBody
    logical,          intent(out)  :: UsePlotVarBody
    character(len=*), intent(inout):: NameTecVar
    character(len=*), intent(inout):: NameTecUnit
    character(len=*), intent(inout):: NameIdlUnit
    logical,          intent(out)  :: IsFound

    character(len=*), parameter :: NameSub = 'user_set_plot_var'
    !-------------------------------------------------------------------
    call stop_user(NameSub)

  end subroutine user_set_plot_var

  !====================================================================

  subroutine user_calc_sources(iBlock)

    integer, intent(in) :: iBlock

    character(len=*), parameter :: NameSub = 'user_calc_sources'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_calc_sources

  !=====================================================================

  subroutine user_init_point_implicit

    character(len=*), parameter :: NameSub = 'user_init_point_implicit'
    !-------------------------------------------------------------------
    call stop_user(NameSub)

  end subroutine user_init_point_implicit

  !=====================================================================

  subroutine user_get_b0(x, y, z, B0_D)

    real, intent(in) :: x, y, z
    real, intent(out):: B0_D(3)

    character(len=*), parameter :: NameSub = 'user_get_b0'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_get_b0

  !=====================================================================
  subroutine user_update_states(iStage, iBlock)

    integer,intent(in)::iStage,iBlock

    character(len=*), parameter :: NameSub = 'user_update_states'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_update_states
  
  !=====================================================================
  subroutine user_normalization
    use ModPhysics 
    
    character(len=*), parameter :: NameSub = 'user_normalization'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_normalization

  !=====================================================================
  subroutine user_io_units
    use ModPhysics 
    
    character(len=*), parameter :: NameSub = 'user_io_units'
    !-------------------------------------------------------------------
    call stop_user(NameSub)
  end subroutine user_io_units

  !=====================================================================
  subroutine user_set_resistivity(iBlock, Eta_G)
    ! This subrountine set the eta for every block
    use ModSize

    integer, intent(in) :: iBlock
    real,    intent(out):: Eta_G(-1:nI+2,-1:nJ+2,-1:nK+2) 
    character(len=*), parameter :: NameSub = 'user_set_resistivity'

    !-------------------------------------------------------------------
    call stop_user(NameSub)

  end subroutine user_set_resistivity

  !===========================================================================

  subroutine user_material_properties(State_V, i, j, k, iBlock, iDir, &
       EinternalIn, TeIn, NatomicOut, AverageIonChargeOut, &
       EinternalOut, TeOut, PressureOut, &
       CvOut, GammaOut, HeatCondOut, IonHeatCondOut, TeTiRelaxOut, &
       OpacityPlanckOut_W, OpacityRosselandOut_W, PlanckOut_W)

    ! The State_V vector is in normalized units, all other physical
    ! quantities are in SI.
    !
    ! If the electron energy is used, then EinternalIn, EinternalOut,
    ! PressureOut, CvOut refer to the electron internal energies,
    ! electron pressure, and electron specific heat, respectively.
    ! Otherwise they refer to the total (electron + ion) internal energies,
    ! total (electron + ion) pressure, and the total specific heat.

    use ModAdvance,    ONLY: nWave
    use ModVarIndexes, ONLY: nVar

    real, intent(in) :: State_V(nVar)
    integer, optional, intent(in):: i, j, k, iBlock, iDir  ! cell/face index
    real, optional, intent(in)  :: EinternalIn             ! [J/m^3]
    real, optional, intent(in)  :: TeIn                    ! [K]
    real, optional, intent(out) :: NatomicOut              ! [1/m^3]
    real, optional, intent(out) :: AverageIonChargeOut     ! dimensionless
    real, optional, intent(out) :: EinternalOut            ! [J/m^3]
    real, optional, intent(out) :: TeOut                   ! [K]
    real, optional, intent(out) :: PressureOut             ! [Pa]
    real, optional, intent(out) :: CvOut                   ! [J/(K*m^3)]
    real, optional, intent(out) :: GammaOut                ! dimensionless
    real, optional, intent(out) :: HeatCondOut             ! [J/(m*K*s)]
    real, optional, intent(out) :: IonHeatCondOut          ! [J/(m*K*s)]
    real, optional, intent(out) :: TeTiRelaxOut            ! [1/s]
    real, optional, intent(out) :: &
         OpacityPlanckOut_W(nWave)                         ! [1/m]
    real, optional, intent(out) :: &
         OpacityRosselandOut_W(nWave)                      ! [1/m]

    ! Multi-group specific interface. The variables are respectively:
    !  Group Planckian spectral energy density
    real, optional, intent(out) :: PlanckOut_W(nWave)      ! [J/m^3]

    character(len=*), parameter :: NameSub = 'user_material_properties'
    !------------------------------------------------------------------------
    call stop_user(NameSub)

  end subroutine user_material_properties

  !=====================================================================
  subroutine stop_user(NameSub)
    ! Note that this routine is not a user routine but just a routine
    ! which warns the user if they try to use an unimplemented user routine.

    character(len=*), intent(in) :: NameSub
    !-------------------------------------------------------------------
    call stop_mpi('You are trying to call the empty user routine '//   &
         NameSub//'. Please implement the routine in src/ModUser.f90')
  end subroutine stop_user


end module ModUserEmpty
!==============================================================================
