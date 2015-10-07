!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!^CMP FILE GM
!^CMP FILE IE

!BOP
!MODULE: CON_couple_gm_ie - couple GM and IE components
!
!DESCRIPTION:
! Couple GM and IE components both ways. 
!
!INTERFACE:
module CON_couple_gm_ie

  !USES:
  use CON_coupler

  use GM_wrapper, ONLY: GM_get_info_for_ie, GM_get_for_ie, GM_put_from_ie
  use IE_wrapper, ONLY: IE_get_for_gm, IE_put_from_gm

  use CON_transfer_data, ONLY: transfer_integer, transfer_real_array, &
       transfer_string_array

  implicit none

  private ! except

  !PUBLIC MEMBER FUNCTIONS:

  public :: couple_gm_ie_init ! initialize both couplings
  public :: couple_gm_ie      ! couple GM to IE
  public :: couple_ie_gm      ! couple IE to GM

  !REVISION HISTORY:
  ! 07/25/2003 G.Toth <gtoth@umich.edu> - initial version as external 
  !                                       subroutines
  ! 08/27/2003 G.Toth - combined into a module
  ! 12/01/2004 G.Toth - the GM->IE coupling is rewritten for Jr(iSize,jSize)
  !EOP

  ! Size of the 2D spherical structured IE grid
  integer, save :: iSize, jSize

  ! Number of variables passed from IE to GM
  integer:: nVarIeGm = 1
  character(len=20), allocatable :: NameVarIeGm_I(:)

contains

  !BOP =======================================================================
  !IROUTINE: couple_gm_ie_init - initialize GM-IE couplings
  !INTERFACE:
  subroutine couple_gm_ie_init


    !DESCRIPTION:
    ! This subroutine should be called from all PE-s.
    ! Transfer initial information about GM to IE coupling.
    !EOP

    logical :: DoTest, DoTestMe
    character(len=*), parameter :: NameSub='couple_gm_ie_init'
    !------------------------------------------------------------------------
    if(.not.is_proc(GM_) .and. .not.is_proc(IE_)) RETURN
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    ! This information is sent at the beginning of every session
    ! because the variables needed by GM can change.

    ! Get number of variables to be passed from GM to IE
    if(is_proc(GM_)) call GM_get_info_for_ie(nVarIeGm)
    
    ! Pass to all IE nodes.
    call transfer_integer(GM_, IE_, nVarIeGm, UseSourceRootOnly=.false.)

    ! Allocate the array holding the variable names.
    if(allocated(NameVarIeGm_I)) deallocate(NameVarIeGm_I)
    allocate(NameVarIeGm_I(nVarIeGm))

    ! Get variables names to be passed
    if(is_proc(GM_)) call GM_get_info_for_ie(nVarIeGm, NameVarIeGm_I)

    ! Send info to all IE nodes
    call transfer_string_array(GM_, IE_, nVarIeGm, NameVarIeGm_I, &
            UseSourceRootOnly=.false.)

    ! Store some information in convenient scalars
    iSize = Grid_C(IE_) % nCoord_D(1)
    jSize = Grid_C(IE_) % nCoord_D(2)

  end subroutine couple_gm_ie_init

  !BOP =======================================================================
  !IROUTINE: couple_ie_gm - couple IE component to GM component
  !INTERFACE:
  subroutine couple_ie_gm(tSimulation)

    !INPUT ARGUMENTS:
    real, intent(in) :: tSimulation     ! simulation time at coupling

    !DESCRIPTION:
    ! Couple between two components:\\
    !    Inner Magnetosphere (IE)  source\\
    !    Global Magnetosphere (GM) target
    !
    ! The IE component sends the electrostatic potential and other
    ! requested variables (Joule heat, conductances ...) to GM.
    !EOP

    ! Buffer for the variables on the 2D IE grid
    real, allocatable :: Buffer_IIV(:,:,:)

    logical :: DoTest, DoTestMe

    ! Name of this interface
    character (len=*), parameter :: NameSub='couple_ie_gm'
    !-------------------------------------------------------------------------
    call CON_set_do_test(NameSub,DoTest,DoTestMe)

    if(DoTest)write(*,*)NameSub,', starting iProc, iProc0Gm, iProc0Ie=', &
         i_proc(), i_proc0(GM_), i_proc0(IE_)

    ! Transfer variables on IE grid
    allocate(Buffer_IIV(iSize,jSize,nVarIeGm))
    if(is_proc(IE_)) call IE_get_for_gm( &
         Buffer_IIV, iSize, jSize, nVarIeGm, NameVarIeGm_I, tSimulation)

    ! The IE grid data is available from the ROOT IE processor ONLY!
    call transfer_real_array(IE_, GM_, iSize*jSize*nVarIeGm, Buffer_IIV)

    if(is_proc(GM_)) &
         call GM_put_from_ie(Buffer_IIV, iSize, jSize, nVarIeGm, NameVarIeGm_I)
    deallocate(Buffer_IIV)

    if(DoTest)write(*,*)NameSub,' finished, iProc=', i_proc()

  end subroutine couple_ie_gm

  !BOP =======================================================================
  !IROUTINE: couple_gm_ie - couple GM to IE
  !INTERFACE:
  subroutine couple_gm_ie(tSimulation)

    !INPUT ARGUMENT:
    real, intent(in) :: tSimulation

    !DESCRIPTION:
    ! Couple between two components:\\
    !    Global Magnetosphere       (GM) source\\
    !    Ionosphere Electrodynamics (IE) target
    !
    ! Send field aligned currents from GM to IE. 
    ! Also send some ray tracing information.
    !EOP

    ! Number of variables to pass
    integer, parameter :: nVar=6

    ! Buffer for the field aligned current on the 2D IE grid
    real, dimension(:,:,:), allocatable :: Buffer_IIV

    logical :: DoTest, DoTestMe
    character (len=*), parameter :: NameSub='couple_gm_ie'
    !-------------------------------------------------------------------------

    call CON_set_do_test(NameSub,DoTest,DoTestMe)

    if(DoTest)write(*,*)NameSub,' starting, iProc, iProc0Gm, iProc0Ie=', &
         i_proc() ,i_proc0(GM_),i_proc0(IE_)

    ! Allocate buffers for the variables both in GM and IE
    allocate(Buffer_IIV(iSize, jSize, nVar))

    ! Calculate field aligned currents on GM
    if(is_proc(GM_)) call GM_get_for_ie(Buffer_IIV, iSize, jSize, nVar)

    ! The result is on the root processor of GM only
    call transfer_real_array(GM_, IE_, iSize*jSize*nVar, Buffer_IIV)

    ! Put variables into IE
    if(is_proc(IE_)) call IE_put_from_gm(Buffer_IIV, iSize, jSize, nVar)

    ! Deallocate buffer to save memory
    deallocate(Buffer_IIV)

    if(DoTest)write(*,*)NameSub,' finished, iProc=', i_proc()

  end subroutine couple_gm_ie

end module CON_couple_gm_ie
