!  Copyright (C) 2002 Regents of the University of Michigan,
!  portions used with permission
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!^CMP FILE IH
!^CMP FILE SC
module CON_couple_ih_sc

  ! This coupler uses the SWMF parallel coupling toolkit.
  ! The SC grid is coupled to a buffer grid in IH. The buffer grid
  ! uses the same coordinate system as SC, so the transformation is
  ! done in the IH wrapper.
  !
  ! The IH grid is coupled to the outer ghost cells of the SC grid directly.
  ! Both SC and IH use AMR grids, the buffer is a simple spherical grid.

  use CON_coupler
  use CON_transfer_data, ONLY: transfer_real_array, transfer_integer

  use SC_wrapper, ONLY:                  &
       SC_get_for_global_buffer,         &
       SC_nVarCouple    => nVarCouple,   &
       SC_iVar_V        => iVar_V,       &
       SC_DoCoupleVar_V => DoCoupleVar_V

  use IH_wrapper, ONLY:                  &
       IH_match_ibc,                     &
       IH_set_buffer_grid_get_info,      &
       IH_save_global_buffer,            &
       IH_nVarCouple    => nVarCouple,   &
       IH_iVar_V        => iVar_V,       &
       IH_DoCoupleVar_V => DoCoupleVar_V

  implicit none
  private ! except
  !
  public:: couple_ih_sc_init
  public:: couple_ih_sc
  public:: couple_sc_ih

  ! revision history:
  ! 7/23/03 Sokolov I.V.<igorsok@umich.edu> - prototype for ih-gm
  ! 7/04/04                                 - version for ih-sc
  ! 7/20/04                                 - version for sc-buffer

  logical       :: IsInitialized=.false., DoMatchIBC = .true.

  ! Size and limits of the 3D spherical buffer grid
  integer, save :: iSize, jSize, kSize
  real, save    :: BufferMinMaxSc_DI(3,2)

  character(len=*), parameter :: NameMod='couple_ih_sc'
contains
  !============================================================================

  subroutine couple_ih_sc_init

    ! Couple SC and IH components via a buffer grid
    ! The subroutines:
    !                CON_couple_sc_ih_init
    !                CON_couple_sc_ih

    logical :: DoTest, DoTestMe

    ! This subroutine should be called from all PE-s
    ! Share buffer grid info (set in IH) with SC.

    character(len=*), parameter:: NameSub = 'couple_ih_sc_init'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)
    if(IsInitialized) RETURN
    IsInitialized = .true.

    if(.not.is_proc(IH_) .and. .not.is_proc(SC_)) RETURN

    if(DoTest) write(*,*) NameSub, ' started'

    ! Determine which state variables should be coupled,
    ! pass this info to SC and IH
    call set_couple_var_info(SC_,IH_)
    IH_nVarCouple    = nVarCouple_CC(SC_, IH_)
    IH_DoCoupleVar_V = DoCoupleVar_VCC(:,SC_, IH_)
    IH_iVar_V        = iVar_VCC(:,SC_, IH_)
    SC_nVarCouple    = nVarCouple_CC(SC_, IH_)
    SC_DoCoupleVar_V = DoCoupleVar_VCC(:,SC_, IH_)
    SC_iVar_V        = iVar_VCC(:,SC_, IH_)

    ! Set buffer grid location and size in IH, and retrieve them for coupler
    if(is_proc(IH_)) then
       call IH_set_buffer_grid_get_info( &
            IH_,iSize, jSize, kSize, BufferMinMaxSc_DI)

       ! Convert units for radial coordinate  before passing to SC
       BufferMinMaxSc_DI(1,:) = BufferMinMaxSc_DI(1,:) &
            *(Grid_C(IH_)%UnitX/Grid_C(SC_)%UnitX)
    end if

    ! Pass buffer size
    call transfer_integer(IH_, SC_, iSize, jSize, kSize, &
         UseSourceRootOnly = .false.)

    ! Pass buffer boundary info
    call transfer_real_array(IH_, SC_, 6, BufferMinMaxSc_DI, &
         UseSourceRootOnly = .false.)

  end subroutine couple_ih_sc_init
  !============================================================================

  subroutine couple_sc_ih(TimeCoupling)

    real, intent(in) :: TimeCoupling     ! simulation time at coupling

    ! Couple between two components:
    !    Solar Corona      (SC)  source
    !    Inner Heliosphere (IH)  target
    !
    ! The SC component sends the state variables to a buffer grid.
    ! IH uses the buffer grid to calculate the inner boundary conditions.

    ! Array to store state vector on all buffer grid points
    real, allocatable :: Buffer_VIII(:,:,:,:)

    logical :: DoTest, DoTestMe
    character(len=*), parameter:: NameSub = 'couple_sc_ih'
    !--------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest,DoTestMe)
    if(DoTest)write(*,*)NameSub,' starting, iProc=', i_proc()

    ! Transfer buffer grid from SC to IH to be used for inner boundary
    allocate(Buffer_VIII(nVarCouple,iSize,0:jSize+1,0:kSize+1))
    if(is_proc(SC_)) call SC_get_for_global_buffer(iSize, jSize, kSize, &
         BufferMinMaxSc_DI, TimeCoupling, SC_, IH_, Buffer_VIII)

    ! Add up Buffer on SC processors and transfer to IH
    call transfer_real_array(SC_, IH_, size(Buffer_VIII), Buffer_VIII, &
         UseSourceSum=.true.)

    if(is_proc(IH_)) call IH_save_global_buffer( &
         nVarCouple, iSize, jSize, kSize, Buffer_VIII)
    deallocate(Buffer_VIII)

    ! Apply initial boundary condition in IH
    if(DoMatchIBC) then
       DoMatchIBC = .false.
       if(is_proc(IH_)) call IH_match_IBC
    end if

    if(DoTest)write(*,*)NameSub,' finished, iProc=',i_proc()

  end subroutine couple_sc_ih
  !============================================================================

  subroutine couple_ih_sc(tSimulation)

    real, intent(in) :: tSimulation

    ! Couple between two components:
    !    Inner Heliosphere (IH) source
    !    Solar Corona      (SC) target
    !
    ! Send state variable from IH to outer cells in SC.

    character(len=*), parameter:: NameSub = 'couple_ih_sc'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub// &
         ' is not yet implemented. Correct #COUPLERTYPE command.')

  end subroutine couple_ih_sc
  !============================================================================

end module CON_couple_ih_sc
!==============================================================================

